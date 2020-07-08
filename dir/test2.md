
## AWS ElasticSearch KNN Tests


```python
from elasticsearch import Elasticsearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import boto3
```


```python
# host = '' # For example, my-test-domain.us-east-1.es.amazonaws.com
# region = '' # e.g. us-west-1

#host = "search-alion-test2-4sb55az5ow7h7koojlem6w7ria.us-east-1.es.amazonaws.com/"
#host = "https://vpc-aliontest2-qjamtzemjlnb2hkttspsj67x3i.us-east-1.es.amazonaws.com"
#host = "https://vpc-aliontest2-qjamtzemjlnb2hkttspsj67x3i.us-east-1.es.amazonaws.com/"
#host = "https://search-aliontest3-suqzkmvjgko3qpaykksy6iz6ci.us-east-1.es.amazonaws.com"
#host = "https://search-aliontest4-jz4uagf2mg56r6xj5wp7kqlmpq.us-east-1.es.amazonaws.com"


"""
notes to future setup

host is the vpc endpoint of the ES domain minus the 'https://' and '/' at the start and end


"""


host = "search-aliontest1-vvw7pstcvgijdcmwjl65n2dxpa.us-east-1.es.amazonaws.com"
region = "us-east-1"
```


```python
service = "es"
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

```


```python
### Check can connect to host

#response = client.describe_elasticsearch_domain(
#    DomainName='string'
#)


# host = "search-alion-test-6yrydpasjr7pyfktt3odnhpbxy.us-east-1.es.amazonaws.com"
# host = "https://alion-test.us-east-1.es.amazonaws.com"


print(host)
es = Elasticsearch(
    hosts = [{'host': host, 'port': 443}],
#     http_auth = awsauth,
    use_ssl = True,
    verify_certs = True,
    connection_class = RequestsHttpConnection
)

print(es.info())
```

    search-aliontest1-vvw7pstcvgijdcmwjl65n2dxpa.us-east-1.es.amazonaws.com
    {'name': 'd84ac9305698b88b417cf6867afb5622', 'cluster_name': '003440510767:aliontest1', 'cluster_uuid': '8EmQDY1RTceu05N9ujjtSA', 'version': {'number': '7.4.2', 'build_flavor': 'oss', 'build_type': 'tar', 'build_hash': 'unknown', 'build_date': '2020-05-05T04:47:06.936807Z', 'build_snapshot': False, 'lucene_version': '8.2.0', 'minimum_wire_compatibility_version': '6.8.0', 'minimum_index_compatibility_version': '6.0.0-beta1'}, 'tagline': 'You Know, for Search'}



```python
### create knn index as type doc

index_name = "knn"
created = False
# index settings
settings = {
        "settings": {
            "number_of_shards": 1,
            "number_of_replicas": 0
        },
        "mappings": {
                "properties": {
                    "my_vector": {
                        "type": "knn_vector",
                        "dimension": 768
                    },
                    "keywords": {
                        "type": "keyword"
                    }
                }
            
        }
    }
try:
    if not es.indices.exists(index_name):
        es.indices.create(index=index_name, body=settings)
        print('Created Index')
    else:
        print("index exists")
except Exception as ex:
    print(str(ex))
    
```

    Created Index



```python
### search the new index to check is created


es.search(index='knn',body=None)


```




    {'took': 1,
     'timed_out': False,
     '_shards': {'total': 1, 'successful': 1, 'skipped': 0, 'failed': 0},
     'hits': {'total': {'value': 0, 'relation': 'eq'},
      'max_score': None,
      'hits': []}}




```python
### add 2 test keywords

import numpy as np

index_name = "knn"
index_property = "keywords"

index_name = "knn"
vector_name = "my_vector"
keyword_name = "testkeyword"

embedding= np.random.rand(768).tolist()


r = es.bulk(
    body=[
    { "index": {"_index":index_name, "_id": 2 }},
    { vector_name: embedding, "price":1,keyword_name: ["test1","test2"]}
    ])

print(r)


# doc ex for bulk
"""
es.bulk(
    body=[
        {"index": {"_index": "test", "_id": "1"}},
        {"field1": "value1"},
        {"delete": {"_index": "test", "_id": "2"}},
        {"create": {"_index": "test", "_id": "3"}},
        {"field1": "value3"},
        {"update": {"_id": "1", "_index": "test"}},
        {"knn_vector": {"keyword": "test"}},
    ],
)
"""

```

    {'took': 24, 'errors': False, 'items': [{'index': {'_index': 'knn', '_type': '_doc', '_id': '2', '_version': 1, 'result': 'created', '_shards': {'total': 1, 'successful': 1, 'failed': 0}, '_seq_no': 0, '_primary_term': 1, 'status': 201}}]}





    '\nes.bulk(\n    body=[\n        {"index": {"_index": "test", "_id": "1"}},\n        {"field1": "value1"},\n        {"delete": {"_index": "test", "_id": "2"}},\n        {"create": {"_index": "test", "_id": "3"}},\n        {"field1": "value3"},\n        {"update": {"_id": "1", "_index": "test"}},\n        {"knn_vector": {"keyword": "test"}},\n    ],\n)\n'



### Bulk Upload


```python
# num_passage = int(1e7) # 10 million
num_passage_per_batch = 20#int(1e2)
num_batch = 100 # half number of batches cause Im on spotty internet
print("Total passages in bulk: {}".format(num_passage_per_batch*num_batch))

# INDEX_NAME = "knn-test"
```

    Total passages in bulk: 2000



```python
import json
import time
import numpy as np
import requests
from tqdm import tqdm

# for testing
import random

# bulk_file = ''

index_name = "knn"
vector_name = "my_vector"
vector_dimension = 768
keyword_name = "keywords"

index_part =     { "index": {"_index":index_name, "_id": 1 }}


keyword_options = ["test","boston","harbor","tour","boat","atlantic","sea","seal","whale","ocean"]

id = 20030000+12700000
time_sp = time.time()
for _iter in range(num_batch):
    print("Current iter num: {}".format(_iter+1))

    bulk_body = []
    
    for _ in tqdm(range(num_passage_per_batch)):
        
        # add index step to body
        index_part  = { "index": {"_index":index_name, "_id": id }}
        bulk_body.append(index_part)

        # value part to be added to body
        value_part = dict()
        
        # add knn vector step to value
        value_part[vector_name] = embedding
        
        # add keyword (1-3) part to value
        # random add keywords for testing
        # keywords is always an array [] of keyword objects even if length 1
        keywords = []
        num_keywords = random.randint(1,3)
        for n in range(num_keywords):
            keywords.append(random.choice(keyword_options))
            
        value_part[keyword_name] = keywords
        # add value to body
        bulk_body.append(value_part)

        # increment/generate values
        embedding= np.random.rand(vector_dimension).tolist()
        id += 1
    
    # the body is now 2 elements, the index point, then a value to add to it
    # { "index": {"_index":index_name, "_id": 2 }},
    # { vector_name: embedding, "price":1,keyword_name: "test2"}
    
    
    es.bulk(bulk_body)#,index=index_name)
    avg_batch_time = round((time.time() - time_sp) / (1 + _iter),4)
    print("Average batch time for batch {} is {}".format(1+_iter,avg_batch_time))

```

    100%|██████████| 20/20 [00:00<00:00, 12803.13it/s]

    Current iter num: 1


    
    100%|██████████| 20/20 [00:00<00:00, 7730.01it/s]

    Average batch time for batch 1 is 1.3299
    Current iter num: 2


    
    100%|██████████| 20/20 [00:00<00:00, 8018.17it/s]

    Average batch time for batch 2 is 1.188
    Current iter num: 3


    
    100%|██████████| 20/20 [00:00<00:00, 11748.75it/s]

    Average batch time for batch 3 is 1.206
    Current iter num: 4


    
    100%|██████████| 20/20 [00:00<00:00, 10542.43it/s]

    Average batch time for batch 4 is 1.2026
    Current iter num: 5


    
    100%|██████████| 20/20 [00:00<00:00, 27971.35it/s]

    Average batch time for batch 5 is 1.2022
    Current iter num: 6


    
    100%|██████████| 20/20 [00:00<00:00, 6300.12it/s]

    Average batch time for batch 6 is 1.2417
    Current iter num: 7


    
    100%|██████████| 20/20 [00:00<00:00, 12692.70it/s]
    100%|██████████| 20/20 [00:00<00:00, 15423.07it/s]

    Average batch time for batch 7 is 1.2138
    Current iter num: 8
    Average batch time for batch 8 is 1.0852
    Current iter num: 9


    
    100%|██████████| 20/20 [00:00<00:00, 9094.33it/s]


    Average batch time for batch 9 is 0.9861
    Current iter num: 10


    100%|██████████| 20/20 [00:00<00:00, 19288.59it/s]

    Average batch time for batch 10 is 0.9327
    Current iter num: 11


    
    100%|██████████| 20/20 [00:00<00:00, 22844.79it/s]

    Average batch time for batch 11 is 0.8802
    Current iter num: 12


    
    100%|██████████| 20/20 [00:00<00:00, 5333.21it/s]

    Average batch time for batch 12 is 0.8321
    Current iter num: 13


    
    100%|██████████| 20/20 [00:00<00:00, 10375.52it/s]

    Average batch time for batch 13 is 0.7875
    Current iter num: 14


    
    100%|██████████| 20/20 [00:00<00:00, 11883.56it/s]

    Average batch time for batch 14 is 0.7611
    Current iter num: 15


    
    100%|██████████| 20/20 [00:00<00:00, 10441.38it/s]

    Average batch time for batch 15 is 0.742
    Current iter num: 16


    
    100%|██████████| 20/20 [00:00<00:00, 4333.41it/s]

    Average batch time for batch 16 is 0.7396
    Current iter num: 17


    
    100%|██████████| 20/20 [00:00<00:00, 6654.46it/s]

    Average batch time for batch 17 is 0.7383
    Current iter num: 18


    
    100%|██████████| 20/20 [00:00<00:00, 5173.04it/s]

    Average batch time for batch 18 is 0.724
    Current iter num: 19


    
    100%|██████████| 20/20 [00:00<00:00, 5975.64it/s]

    Average batch time for batch 19 is 0.7365
    Current iter num: 20


    
    100%|██████████| 20/20 [00:00<00:00, 12291.00it/s]

    Average batch time for batch 20 is 0.7477
    Current iter num: 21


    
    100%|██████████| 20/20 [00:00<00:00, 10412.87it/s]

    Average batch time for batch 21 is 0.7806
    Current iter num: 22


    
    100%|██████████| 20/20 [00:00<00:00, 5342.04it/s]

    Average batch time for batch 22 is 0.7636
    Current iter num: 23


    
    100%|██████████| 20/20 [00:00<00:00, 7798.28it/s]

    Average batch time for batch 23 is 0.7622
    Current iter num: 24


    
    100%|██████████| 20/20 [00:00<00:00, 6421.16it/s]

    Average batch time for batch 24 is 0.7506
    Current iter num: 25


    
    100%|██████████| 20/20 [00:00<00:00, 6293.03it/s]

    Average batch time for batch 25 is 0.7455
    Current iter num: 26


    
    100%|██████████| 20/20 [00:00<00:00, 7351.33it/s]

    Average batch time for batch 26 is 0.753
    Current iter num: 27


    
    100%|██████████| 20/20 [00:00<00:00, 6598.45it/s]

    Average batch time for batch 27 is 0.7605
    Current iter num: 28


    
    100%|██████████| 20/20 [00:00<00:00, 8448.59it/s]

    Average batch time for batch 28 is 0.7677
    Current iter num: 29


    
    100%|██████████| 20/20 [00:00<00:00, 6075.62it/s]

    Average batch time for batch 29 is 0.7743
    Current iter num: 30


    
    100%|██████████| 20/20 [00:00<00:00, 7727.87it/s]

    Average batch time for batch 30 is 0.8044
    Current iter num: 31


    
    100%|██████████| 20/20 [00:00<00:00, 7202.38it/s]

    Average batch time for batch 31 is 0.7947
    Current iter num: 32


    
    100%|██████████| 20/20 [00:00<00:00, 5826.23it/s]

    Average batch time for batch 32 is 0.7822
    Current iter num: 33


    
    100%|██████████| 20/20 [00:00<00:00, 7755.74it/s]

    Average batch time for batch 33 is 0.7738
    Current iter num: 34


    
    100%|██████████| 20/20 [00:00<00:00, 7042.74it/s]

    Average batch time for batch 34 is 0.7679
    Current iter num: 35


    
    100%|██████████| 20/20 [00:00<00:00, 8561.55it/s]

    Average batch time for batch 35 is 0.7631
    Current iter num: 36


    
    100%|██████████| 20/20 [00:00<00:00, 4364.52it/s]

    Average batch time for batch 36 is 0.782
    Current iter num: 37


    
    100%|██████████| 20/20 [00:00<00:00, 5849.39it/s]

    Average batch time for batch 37 is 0.7868
    Current iter num: 38


    
    100%|██████████| 20/20 [00:00<00:00, 5681.41it/s]

    Average batch time for batch 38 is 0.785
    Current iter num: 39


    
    100%|██████████| 20/20 [00:00<00:00, 12035.31it/s]

    Average batch time for batch 39 is 0.7895
    Current iter num: 40


    
    100%|██████████| 20/20 [00:00<00:00, 5093.88it/s]

    Average batch time for batch 40 is 0.7878
    Current iter num: 41


    
    100%|██████████| 20/20 [00:00<00:00, 7691.74it/s]

    Average batch time for batch 41 is 0.7919
    Current iter num: 42


    
    100%|██████████| 20/20 [00:00<00:00, 7531.52it/s]

    Average batch time for batch 42 is 0.7794
    Current iter num: 43


    
    100%|██████████| 20/20 [00:00<00:00, 6183.55it/s]

    Average batch time for batch 43 is 0.7727
    Current iter num: 44


    
    100%|██████████| 20/20 [00:00<00:00, 7779.48it/s]

    Average batch time for batch 44 is 0.7676
    Current iter num: 45


    
    100%|██████████| 20/20 [00:00<00:00, 25093.05it/s]

    Average batch time for batch 45 is 0.7602
    Current iter num: 46


    
    100%|██████████| 20/20 [00:00<00:00, 7587.38it/s]

    Average batch time for batch 46 is 0.7547
    Current iter num: 47


    
    100%|██████████| 20/20 [00:00<00:00, 7685.39it/s]

    Average batch time for batch 47 is 0.7587
    Current iter num: 48


    
    100%|██████████| 20/20 [00:00<00:00, 15947.92it/s]

    Average batch time for batch 48 is 0.7627
    Current iter num: 49


    
    100%|██████████| 20/20 [00:00<00:00, 10804.49it/s]

    Average batch time for batch 49 is 0.7716
    Current iter num: 50


    
    100%|██████████| 20/20 [00:00<00:00, 27086.24it/s]

    Average batch time for batch 50 is 0.7706
    Current iter num: 51


    
    100%|██████████| 20/20 [00:00<00:00, 35439.83it/s]

    Average batch time for batch 51 is 0.779
    Current iter num: 52


    
    100%|██████████| 20/20 [00:00<00:00, 11430.18it/s]
    100%|██████████| 20/20 [00:00<00:00, 9900.40it/s]

    Average batch time for batch 52 is 0.7795
    Current iter num: 53
    Average batch time for batch 53 is 0.7684
    Current iter num: 54


    
    100%|██████████| 20/20 [00:00<00:00, 6141.00it/s]

    Average batch time for batch 54 is 0.762
    Current iter num: 55


    
    100%|██████████| 20/20 [00:00<00:00, 7819.36it/s]

    Average batch time for batch 55 is 0.7521
    Current iter num: 56


    
    100%|██████████| 20/20 [00:00<00:00, 6461.72it/s]

    Average batch time for batch 56 is 0.7502
    Current iter num: 57


    
    100%|██████████| 20/20 [00:00<00:00, 14210.75it/s]

    Average batch time for batch 57 is 0.7427
    Current iter num: 58


    
    100%|██████████| 20/20 [00:00<00:00, 6243.38it/s]

    Average batch time for batch 58 is 0.7558
    Current iter num: 59


    
    100%|██████████| 20/20 [00:00<00:00, 4597.00it/s]

    Average batch time for batch 59 is 0.7588
    Current iter num: 60


    
    100%|██████████| 20/20 [00:00<00:00, 6042.79it/s]

    Average batch time for batch 60 is 0.7661
    Current iter num: 61


    
    100%|██████████| 20/20 [00:00<00:00, 5375.25it/s]

    Average batch time for batch 61 is 0.7773
    Current iter num: 62


    
    100%|██████████| 20/20 [00:00<00:00, 6563.34it/s]

    Average batch time for batch 62 is 0.7801
    Current iter num: 63


    
    100%|██████████| 20/20 [00:00<00:00, 7786.70it/s]

    Average batch time for batch 63 is 0.7728
    Current iter num: 64


    
    100%|██████████| 20/20 [00:00<00:00, 13195.86it/s]

    Average batch time for batch 64 is 0.7692
    Current iter num: 65


    
    100%|██████████| 20/20 [00:00<00:00, 17832.93it/s]

    Average batch time for batch 65 is 0.7626
    Current iter num: 66


    
    100%|██████████| 20/20 [00:00<00:00, 21061.03it/s]

    Average batch time for batch 66 is 0.7595
    Current iter num: 67


    
    100%|██████████| 20/20 [00:00<00:00, 13774.40it/s]

    Average batch time for batch 67 is 0.7532
    Current iter num: 68


    
    100%|██████████| 20/20 [00:00<00:00, 20570.40it/s]

    Average batch time for batch 68 is 0.7563
    Current iter num: 69


    
    100%|██████████| 20/20 [00:00<00:00, 5983.32it/s]

    Average batch time for batch 69 is 0.7697
    Current iter num: 70


    
    100%|██████████| 20/20 [00:00<00:00, 10307.95it/s]

    Average batch time for batch 70 is 0.7798
    Current iter num: 71


    
    100%|██████████| 20/20 [00:00<00:00, 7332.70it/s]

    Average batch time for batch 71 is 0.7818
    Current iter num: 72


    
    100%|██████████| 20/20 [00:00<00:00, 6930.44it/s]

    Average batch time for batch 72 is 0.781
    Current iter num: 73


    
    100%|██████████| 20/20 [00:00<00:00, 8413.85it/s]

    Average batch time for batch 73 is 0.776
    Current iter num: 74


    
    100%|██████████| 20/20 [00:00<00:00, 7019.17it/s]

    Average batch time for batch 74 is 0.7696
    Current iter num: 75


    
    100%|██████████| 20/20 [00:00<00:00, 5097.29it/s]

    Average batch time for batch 75 is 0.7644
    Current iter num: 76


    
    100%|██████████| 20/20 [00:00<00:00, 6939.62it/s]

    Average batch time for batch 76 is 0.7587
    Current iter num: 77


    
    100%|██████████| 20/20 [00:00<00:00, 7752.87it/s]

    Average batch time for batch 77 is 0.7558
    Current iter num: 78


    
    100%|██████████| 20/20 [00:00<00:00, 8018.17it/s]

    Average batch time for batch 78 is 0.7517
    Current iter num: 79


    
    100%|██████████| 20/20 [00:00<00:00, 10107.97it/s]

    Average batch time for batch 79 is 0.7513
    Current iter num: 80


    
    100%|██████████| 20/20 [00:00<00:00, 4965.73it/s]

    Average batch time for batch 80 is 0.7509
    Current iter num: 81


    
    100%|██████████| 20/20 [00:00<00:00, 7547.11it/s]

    Average batch time for batch 81 is 0.7505
    Current iter num: 82


    
    100%|██████████| 20/20 [00:00<00:00, 9422.23it/s]

    Average batch time for batch 82 is 0.7501
    Current iter num: 83


    
    100%|██████████| 20/20 [00:00<00:00, 5606.23it/s]

    Average batch time for batch 83 is 0.7498
    Current iter num: 84


    
    100%|██████████| 20/20 [00:00<00:00, 6879.29it/s]

    Average batch time for batch 84 is 0.7542
    Current iter num: 85


    
    100%|██████████| 20/20 [00:00<00:00, 7288.10it/s]

    Average batch time for batch 85 is 0.7519
    Current iter num: 86


    
    100%|██████████| 20/20 [00:00<00:00, 5834.34it/s]

    Average batch time for batch 86 is 0.7508
    Current iter num: 87


    
    100%|██████████| 20/20 [00:00<00:00, 7174.04it/s]

    Average batch time for batch 87 is 0.7448
    Current iter num: 88


    
    100%|██████████| 20/20 [00:00<00:00, 6398.63it/s]

    Average batch time for batch 88 is 0.7412
    Current iter num: 89


    
    100%|██████████| 20/20 [00:00<00:00, 9246.70it/s]

    Average batch time for batch 89 is 0.7387
    Current iter num: 90


    
    100%|██████████| 20/20 [00:00<00:00, 12183.89it/s]

    Average batch time for batch 90 is 0.7346
    Current iter num: 91


    
    100%|██████████| 20/20 [00:00<00:00, 27980.68it/s]

    Average batch time for batch 91 is 0.7305
    Current iter num: 92


    
    100%|██████████| 20/20 [00:00<00:00, 5969.69it/s]

    Average batch time for batch 92 is 0.7306
    Current iter num: 93


    
    100%|██████████| 20/20 [00:00<00:00, 12050.87it/s]

    Average batch time for batch 93 is 0.733
    Current iter num: 94


    
    100%|██████████| 20/20 [00:00<00:00, 7766.51it/s]

    Average batch time for batch 94 is 0.7371
    Current iter num: 95


    
    100%|██████████| 20/20 [00:00<00:00, 6954.57it/s]

    Average batch time for batch 95 is 0.7378
    Current iter num: 96


    
    100%|██████████| 20/20 [00:00<00:00, 21045.18it/s]

    Average batch time for batch 96 is 0.7426
    Current iter num: 97


    
    100%|██████████| 20/20 [00:00<00:00, 7847.15it/s]

    Average batch time for batch 97 is 0.7448
    Current iter num: 98


    
    100%|██████████| 20/20 [00:00<00:00, 6049.77it/s]

    Average batch time for batch 98 is 0.7414
    Current iter num: 99


    
    100%|██████████| 20/20 [00:00<00:00, 5587.19it/s]

    Average batch time for batch 99 is 0.7372
    Current iter num: 100


    


    Average batch time for batch 100 is 0.7332


#### Query based on fuzzy match keyword





```python
### search the to see results are uploaded


max_results = 1000
search_query = "bosto"

query =  {
    "size": max_results,
    "query": {
        "fuzzy" : {
            "keywords" : search_query
        }
    }
}
# `fuzzy` can be changed to `match` for exact match search

r = es.search(index='knn',body=query)
# r is result json

hits = r["hits"]["hits"]

# print all keywords found
for hit in hits:
    keywords = hit["_source"]["keywords"]
    # hit[_source][my_vector] is the vector with those keywords
    print(keywords)

print(len(hits))

```

    ['boat', 'boston', 'harbor']
    ['boston', 'atlantic']
    ['boston']
    ['harbor', 'boston']
    ['boston']
    ['boston', 'test']
    ['boston', 'boston']
    ['seal', 'boston']
    ['seal', 'boston', 'sea']
    ['atlantic', 'boston', 'tour']
    ['boston', 'boston']
    ['sea', 'boston', 'harbor']
    ['boston', 'atlantic', 'test']
    ['boston', 'ocean']
    ['boston', 'ocean', 'tour']
    ['boston', 'test']
    ['boston']
    ['boat', 'boston', 'test']
    ['seal', 'whale', 'boston']
    ['boston', 'boat']
    ['sea', 'boston', 'boat']
    ['tour', 'boston']
    ['boston', 'sea']
    ['boston']
    ['ocean', 'atlantic', 'boston']
    ['boston']
    ['seal', 'ocean', 'boston']
    ['boston', 'boat']
    ['boston']
    ['boston', 'seal']
    ['seal', 'harbor', 'boston']
    ['boston', 'sea', 'harbor']
    ['sea', 'boston', 'harbor']
    ['boston', 'sea', 'atlantic']
    ['boat', 'boat', 'boston']
    ['harbor', 'boston', 'tour']
    ['boston', 'harbor', 'seal']
    ['whale', 'boston', 'harbor']
    ['ocean', 'boston', 'boston']
    ['boston', 'boston']
    ['boston']
    ['boston', 'harbor', 'whale']
    ['tour', 'boston', 'harbor']
    ['sea', 'whale', 'boston']
    ['seal', 'boston']
    ['harbor', 'boston']
    ['seal', 'boston']
    ['tour', 'harbor', 'boston']
    ['sea', 'boston']
    ['boston', 'ocean']
    ['boston', 'tour', 'boat']
    ['boston', 'boston']
    ['boston', 'tour', 'boston']
    ['boat', 'ocean', 'boston']
    ['atlantic', 'boston', 'tour']
    ['test', 'seal', 'boston']
    ['ocean', 'boston']
    ['harbor', 'ocean', 'boston']
    ['boston']
    ['boston', 'whale']
    ['atlantic', 'boston']
    ['seal', 'boston']
    ['boston']
    ['test', 'ocean', 'boston']
    ['boston', 'whale', 'whale']
    ['boston', 'test']
    ['seal', 'boston']
    ['test', 'harbor', 'boston']
    ['boston', 'whale', 'boston']
    ['boat', 'boat', 'boston']
    ['ocean', 'boston', 'boat']
    ['harbor', 'boston', 'ocean']
    ['boston', 'whale']
    ['test', 'boston', 'whale']
    ['whale', 'boat', 'boston']
    ['boston', 'boston', 'test']
    ['boston', 'ocean', 'atlantic']
    ['boston', 'boat', 'harbor']
    ['ocean', 'boston', 'sea']
    ['test', 'boston']
    ['ocean', 'boat', 'boston']
    ['boston', 'boston']
    ['harbor', 'boston', 'test']
    ['harbor', 'boston', 'ocean']
    ['boston']
    ['boston', 'atlantic', 'seal']
    ['tour', 'boston', 'sea']
    ['boston']
    ['seal', 'boston']
    ['boston', 'seal', 'atlantic']
    ['boston', 'boston', 'whale']
    ['boat', 'boston']
    ['boston', 'whale']
    ['boston']
    ['boston']
    ['boat', 'atlantic', 'boston']
    ['ocean', 'harbor', 'boston']
    ['boston']
    ['harbor', 'sea', 'boston']
    ['test', 'boston']
    ['boston', 'seal']
    ['boston', 'whale', 'test']
    ['boston', 'tour']
    ['test', 'boston']
    ['boston']
    ['boston']
    ['seal', 'seal', 'boston']
    ['boston', 'test', 'boston']
    ['seal', 'whale', 'boston']
    ['boston']
    ['seal', 'boston', 'boston']
    ['boston', 'ocean', 'tour']
    ['harbor', 'boston', 'tour']
    ['boston', 'boston']
    ['boston']
    ['boston', 'atlantic']
    ['harbor', 'boston']
    ['tour', 'boston']
    ['seal', 'boston']
    ['ocean', 'whale', 'boston']
    ['test', 'boston', 'atlantic']
    ['harbor', 'boston']
    ['boston']
    ['boston']
    ['ocean', 'boston']
    ['test', 'atlantic', 'boston']
    ['sea', 'boston', 'test']
    ['tour', 'boston']
    ['boston', 'tour', 'whale']
    ['boston', 'harbor', 'boat']
    ['harbor', 'boston', 'boston']
    ['boston']
    ['sea', 'boston']
    ['whale', 'boston', 'boat']
    ['boston', 'sea', 'boat']
    ['boston']
    ['boston']
    ['boston', 'whale', 'sea']
    ['harbor', 'harbor', 'boston']
    ['whale', 'boston']
    ['test', 'boston', 'whale']
    ['tour', 'seal', 'boston']
    ['harbor', 'boston', 'boston']
    ['harbor', 'boston', 'sea']
    ['boston', 'boston']
    ['atlantic', 'boston']
    ['boston', 'sea', 'harbor']
    ['boston']
    ['boston', 'boat']
    ['sea', 'whale', 'boston']
    ['boston', 'seal', 'whale']
    ['boston', 'tour', 'harbor']
    ['atlantic', 'atlantic', 'boston']
    ['boston', 'boston']
    ['boston', 'tour', 'atlantic']
    ['whale', 'harbor', 'boston']
    ['seal', 'boston', 'tour']
    ['boston', 'test']
    ['atlantic', 'harbor', 'boston']
    ['boston', 'sea']
    ['boston', 'sea', 'boston']
    ['ocean', 'boston', 'harbor']
    ['harbor', 'sea', 'boston']
    ['boston', 'whale']
    ['boston', 'seal', 'tour']
    ['atlantic', 'boston']
    ['ocean', 'whale', 'boston']
    ['ocean', 'boston', 'ocean']
    ['whale', 'boat', 'boston']
    ['boston', 'boston']
    ['boston']
    ['test', 'boston', 'atlantic']
    ['boston', 'boat']
    ['atlantic', 'boston', 'test']
    ['harbor', 'test', 'boston']
    ['tour', 'boston', 'harbor']
    ['boston', 'tour']
    ['boston', 'tour', 'test']
    ['ocean', 'boston', 'ocean']
    ['tour', 'boston', 'boston']
    ['boston', 'boston']
    ['ocean', 'boston']
    ['atlantic', 'boston', 'sea']
    ['boston', 'ocean', 'test']
    ['boat', 'test', 'boston']
    ['boston', 'seal', 'tour']
    ['test', 'sea', 'boston']
    ['boston']
    ['boat', 'atlantic', 'boston']
    ['boston']
    ['boat', 'boston', 'atlantic']
    ['harbor', 'boston', 'harbor']
    ['tour', 'boston', 'harbor']
    ['boston', 'sea', 'sea']
    ['boston']
    ['boston', 'boston']
    ['atlantic', 'boston', 'test']
    ['boat', 'boston', 'ocean']
    ['ocean', 'harbor', 'boston']
    ['boston', 'ocean', 'boston']
    ['atlantic', 'boston']
    ['atlantic', 'boat', 'boston']
    ['test', 'whale', 'boston']
    ['boston', 'tour']
    ['boston']
    ['sea', 'boston']
    ['sea', 'seal', 'boston']
    ['tour', 'boston']
    ['boston', 'boat']
    ['boston']
    ['boston']
    ['tour', 'harbor', 'boston']
    ['test', 'boston']
    ['boston']
    ['boston', 'atlantic']
    ['test', 'boston', 'seal']
    ['boston', 'ocean', 'sea']
    ['tour', 'boston', 'tour']
    ['test', 'boston', 'atlantic']
    ['atlantic', 'boston', 'tour']
    ['ocean', 'boston', 'sea']
    ['test', 'boston', 'harbor']
    ['whale', 'boston', 'seal']
    ['boston', 'boat', 'test']
    ['boston', 'tour']
    ['boston', 'sea', 'ocean']
    ['sea', 'boston']
    ['ocean', 'boston']
    ['atlantic', 'boston', 'test']
    ['boston']
    ['tour', 'sea', 'boston']
    ['boston', 'boston']
    ['atlantic', 'boston']
    ['atlantic', 'tour', 'boston']
    ['whale', 'boston']
    ['tour', 'tour', 'boston']
    ['boston']
    ['whale', 'harbor', 'boston']
    ['atlantic', 'boston']
    ['boston']
    ['test', 'boston']
    ['boston']
    ['boston', 'test', 'harbor']
    ['boston', 'ocean', 'boston']
    ['boston']
    ['boston', 'atlantic']
    ['whale', 'atlantic', 'boston']
    ['boston', 'boston']
    ['ocean', 'boston', 'harbor']
    ['boston', 'tour']
    ['boat', 'boston', 'seal']
    ['harbor', 'sea', 'boston']
    ['boston']
    ['boston', 'harbor']
    ['harbor', 'test', 'boston']
    ['boston', 'whale', 'test']
    ['boston', 'seal']
    ['boston', 'tour']
    ['test', 'test', 'boston']
    ['boston']
    ['boston', 'tour', 'boston']
    ['whale', 'boston']
    ['boston']
    ['whale', 'tour', 'boston']
    ['test', 'boston', 'sea']
    ['boat', 'boston', 'sea']
    ['boston', 'tour', 'boat']
    ['ocean', 'boston', 'sea']
    ['boston', 'test', 'test']
    ['sea', 'boston', 'tour']
    ['boston', 'boston', 'harbor']
    ['test', 'boston', 'boat']
    ['whale', 'boston']
    ['boston', 'whale', 'test']
    ['seal', 'boston']
    ['atlantic', 'boston']
    ['boat', 'boston']
    ['boston', 'tour', 'ocean']
    ['seal', 'boston']
    ['boston']
    ['seal', 'boston', 'seal']
    ['boston', 'seal']
    ['boston', 'boat']
    ['ocean', 'boston', 'sea']
    ['seal', 'boston']
    ['sea', 'boston']
    ['boston']
    ['boston', 'ocean', 'boston']
    ['boston', 'test', 'test']
    ['boston', 'tour', 'boat']
    ['boston', 'seal']
    ['boston', 'ocean']
    ['boston', 'tour', 'test']
    ['boston', 'boston']
    ['harbor', 'seal', 'boston']
    ['whale', 'boston']
    ['sea', 'boston']
    ['atlantic', 'boston']
    ['boston']
    ['boston', 'whale']
    ['boston']
    ['boston', 'seal']
    ['atlantic', 'whale', 'boston']
    ['boston', 'seal']
    ['boston', 'tour', 'harbor']
    ['tour', 'boston', 'atlantic']
    ['boston']
    ['sea', 'boston', 'test']
    ['boston', 'ocean', 'harbor']
    ['tour', 'boston', 'boston']
    ['boston']
    ['boat', 'ocean', 'boston']
    ['boston', 'sea']
    ['seal', 'tour', 'boston']
    ['boston', 'harbor', 'sea']
    ['tour', 'boston']
    ['whale', 'boston']
    ['boston', 'boston', 'sea']
    ['boston', 'harbor', 'boat']
    ['boston', 'harbor']
    ['test', 'boston', 'boston']
    ['boston', 'test', 'test']
    ['boston', 'atlantic', 'seal']
    ['boston', 'boat']
    ['boston', 'atlantic']
    ['ocean', 'boat', 'boston']
    ['boston', 'boat', 'sea']
    ['boston', 'harbor']
    ['boston', 'boston']
    ['boston', 'tour']
    ['boston', 'sea', 'atlantic']
    ['boston', 'atlantic']
    ['boston', 'boston', 'tour']
    ['atlantic', 'atlantic', 'boston']
    ['boston', 'test']
    ['atlantic', 'harbor', 'boston']
    ['boston', 'ocean']
    ['boston', 'seal', 'whale']
    ['whale', 'boston', 'sea']
    ['boston']
    ['harbor', 'boston']
    ['boston']
    ['sea', 'ocean', 'boston']
    ['boston', 'whale', 'boston']
    ['harbor', 'boston']
    ['boston', 'boat', 'boston']
    ['boston', 'boston']
    ['ocean', 'boston']
    ['boat', 'harbor', 'boston']
    ['boston']
    ['boston', 'seal']
    ['sea', 'boston']
    ['whale', 'seal', 'boston']
    ['harbor', 'boston', 'harbor']
    ['boston']
    ['harbor', 'boston']
    ['tour', 'boston']
    ['boston', 'harbor']
    ['whale', 'boston']
    ['ocean', 'boston', 'atlantic']
    ['sea', 'boston', 'ocean']
    ['tour', 'boston']
    ['whale', 'boston', 'sea']
    ['tour', 'atlantic', 'boston']
    ['boston']
    ['boston']
    ['harbor', 'boston']
    ['boston']
    ['boston', 'test']
    369


#### Query based on query embedding


```python
import numpy as np

NUM_OUTPUT = 1000
QUERY_EMBEDDING = np.random.rand(1024).tolist()

es_query = {
  "size": NUM_OUTPUT,
  "query": {
    "knn": {
      "my_vector1": {
        "vector": QUERY_EMBEDDING,
        "k": NUM_OUTPUT
      }
    }
  }
}





es_query = {
  "size": NUM_OUTPUT,
  "query": {
    "knn": {
      "my_vector1": {
        "vector": QUERY_EMBEDDING,
        "k": NUM_OUTPUT
      }
    }
  }
}
```


```python
import requests

#host = "https://search-alion-test3-cbeplr3jqsbbwzbqbeuryjstu4.us-east-1.es.amazonaws.com/"

endpoint = "knn/_search"

url = "https://"+host+"/" + endpoint
print(url)
```

    https://search-aliontest1-vvw7pstcvgijdcmwjl65n2dxpa.us-east-1.es.amazonaws.com/knn/_search



```python
r = requests.get(url, json=es_query)

print(r.text)
```

    {"took":1,"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":0,"relation":"eq"},"max_score":null,"hits":[]}}



```python
r.status_code
```




    200




```python
import ast 
import json

# result = ast.literal_eval(r.text)
result = json.loads(r.text)
```


```python
result.keys()
```




    dict_keys(['took', 'timed_out', '_shards', 'hits'])




```python
result['hits'].keys()
```




    dict_keys(['total', 'max_score', 'hits'])




```python
# result_id['_id']
```


```python
len(result['hits']['hits'])
```




    0




```python
from sklearn.metrics.pairwise import cosine_similarity

for _idx in range(10):
    result_id = result['hits']['hits'][_idx]['_id']
    result_embedding = result['hits']['hits'][_idx]['_source']['my_vector1']
    result_score = result['hits']['hits'][_idx]['_score']
    print("AWS ES score for id {} is {}\n".format(result_id,result_score))
    
    cos_score = cosine_similarity([QUERY_EMBEDDING, result_embedding])
    print("Sklearn cosine score for id {} is {}\n".format(result_id,round(cos_score[0][1],4)))
# result['hits']['hits'][1]
```


    ---------------------------------------------------------------------------

    ModuleNotFoundError                       Traceback (most recent call last)

    <ipython-input-148-123dfb77a77b> in <module>
    ----> 1 from sklearn.metrics.pairwise import cosine_similarity
          2 
          3 for _idx in range(10):
          4     result_id = result['hits']['hits'][_idx]['_id']
          5     result_embedding = result['hits']['hits'][_idx]['_source']['my_vector1']


    ModuleNotFoundError: No module named 'sklearn'



```python
result['hits']['hits'][_idx]
```
