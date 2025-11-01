#!/bin/bash
################################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: Generate Multiplication Table for a Given Number
# Usage: ./multiplication_table.sh <number> or bash multiplication_table.sh <number>
# Example: ./multiplication_table.sh 5 or bash multiplication_table.sh 5
################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <number>"
    echo "Example: $0 5"
    exit 1
fi  

number=$1
# Check if the input is a valid number
if ! [[ "$number" =~ ^-?[0-9]+$ ]]; then
    echo "Error: Input is not a valid number."
    exit 1
fi  

echo "Multiplication Table for $number:"
for i in {1..10}; do
    result=$((number * i))
    echo "$number x $i = $result"
done
# End of script 
