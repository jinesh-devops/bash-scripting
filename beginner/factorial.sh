#!/bin/bash
#############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script calculates the factorial of a given number.
# usage: ./factorial.sh <number>
# Example: ./factorial.sh 5
#############################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <number>"
    echo "Example: $0 5"
    exit 1
fi
number=$1
factorial=1
for (( i=1; i<=number; i++ )); do
    factorial=$((factorial * i))
done
echo "The factorial of $number is $factorial"
# End of script

