#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script calculates the sum of digits of a given number.
# Usage: ./sum_of_digits.sh number
# Example: ./sum_of_digits.sh 12345
###############################

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 number"
    echo "Example: $0 12345"
    exit 1
fi

input_number="$1"

# Validate if the input is a number
if ! [[ "$input_number" =~ ^[0-9]+$ ]]; then
    echo "Error: Input must be a non-negative integer."
    exit 1
fi
sum=0

# Loop through each digit in the input number
for (( i=0; i<${#input_number}; i++ )); do
    digit=${input_number:i:1}
    sum=$((sum + digit))
done
echo "The sum of digits of $input_number is: $sum"
# End of script

