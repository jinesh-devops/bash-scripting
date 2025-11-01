#!/bin/bash
##############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script checks if a given string is a palindrome.
# Usage: ./palindrome.sh "string"
# Example: ./palindrome.sh "madam"
# End of script
##############################
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 \"string\""
    echo "Example: $0 \"madam\""
    exit 1
fi

input_string="$1"
# Remove spaces and convert to lowercase
cleaned_string=$(echo "$input_string" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
# Reverse the cleaned string
reversed_string=$(echo "$cleaned_string" | rev) 
# Check if the cleaned string is equal to the reversed string
if [ "$cleaned_string" == "$reversed_string" ]; then
    echo "\"$input_string\" is a palindrome."
else
    echo "\"$input_string\" is not a palindrome."
fi
# End of script
