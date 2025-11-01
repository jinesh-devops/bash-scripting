#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script prints the Fibonacci series up to a given number.
# Usage: ./fibonacci.sh number
# Example: ./fibonacci.sh 10
###############################

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 number"
    echo "Example: $0 10"
    exit 1
fi
input_number="$1"
# Validate if the input is a non-negative integer
if ! [[ "$input_number" =~ ^[0-9]+$ ]]; then
    echo "Error: Input must be a non-negative integer."
    exit 1
fi
a=0 #stores current fibonacci number
b=1 #stores next fibonacci number
#fn temporary variable to calculate next
echo "Fibonacci series up to $input_number:"
while [ $a -le $input_number ]; do
    echo -n "$a "
    fn=$((a + b))
    a=$b
    b=$fn
done
# End of script

