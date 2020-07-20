#!/bin/bash

#ARGS=$(egrep -n "add_argument" **.py)
ARGS=$(egrep -Hn "add_argument" **.py |\
                sed 's/,//g' |\
                 sed "s/'//g" |\
                  sed 's/"//g' )


python3 - << EOF



from pyinflect import getAllInflections, getInflection


# verb form tags
present_tense_forms = ["VBP", "VBZ", "VBG"]
past_tense_forms = ["VBD", "VBN"]


def get_tenses(word, forms):
    is_present = False
    is_past = False

    for form in forms:
        # if the word has present tense forms; check that one of them is the input word
        if form in present_tense_forms:
            for word_form in forms[form]:
                if word_form == word:
                    is_present = True

        # if the word has past tense forms, check if input is one of them
        if form in past_tense_forms:
            for word_form in forms[form]:
                if word_form == word:
                    is_past = True
    return is_past, is_present

args_to_change = []


bash_args = """$ARGS"""

args = bash_args.split("\n")

#print(args)

for arg_line in args:    
    file = arg_line[:arg_line.find(":")]
    
    line = arg_line[arg_line.find(":")+1:]
    line = line[:line.find(":")]

    arg = arg_line[arg_line.find("(")+1:]
    arg = arg[:arg.find(' ')]

    # all args
    #print(file)
    #print(line)
    #print(arg)

    arg = arg.strip()

    word = arg.lower()

    forms = getAllInflections(word)

    is_past, is_present = get_tenses(word, forms)

    # if neither and the word ends in ed
    if (not is_past) and (not is_present) and ("ed" in word[-2:]):
        new_word = word[:-2]
        new_forms = getAllInflections(new_word)
        is_past, is_present = get_tenses(word, new_forms)

    #print("word", word)
    #print("present", is_present)
    #print("past", is_past)

    needs_change = (not is_present and is_past)
    #print("needs change", needs_change)
    if needs_change:
      args_to_change.append({"file":file,"line":line,"arg":arg})


if len(args_to_change) > 0:
  print(args_to_change)
  exit(1)


EOF


