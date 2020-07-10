#!/bin/bash

#ARGS=$(egrep -n "add_argument" **.py)
ARGS=$(egrep -n "add_argument" **.py |\
                sed 's/,//g' |\
                 sed "s/'//g" |\
                  sed 's/"//g' )


python - << EOF

bash_args = """$ARGS"""

args = bash_args.split("\n")

print(args)

for arg_line in args:    
    file = arg_line[:arg_line.find(":")]
    
    line = arg_line[arg_line.find(":")+1:]
    line = line[:line.find(":")]

    arg = arg_line[arg_line.find("(")+1:]
    arg = arg[:arg.find(' ')]

    # all args
    print(file)
    print(line)
    print(arg)

    # test if arg is past tense

    # if not, then its fine
    


EOF


