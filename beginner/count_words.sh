#!/bin/bash
##############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script counts the number of words in a given string.
# Usage: ./count_words.sh "string"
# Example: ./count_words.sh "Hello World from Shell Scripting"
# End of script
##############################

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 \"string\""
    echo "Example: $0 \"Hello World from Shell Scripting\""
    exit 1
fi

input_string="$1"
# Count the number of words using wc -w
word_count=$(echo "$input_string" | wc -w)
echo "The number of words in the given string is: $word_count"
# End of script

