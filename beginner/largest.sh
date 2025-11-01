#!/bin/bash
##############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script checks the largest of three numbers.
# Usage: ./largest.sh num1 num2 num3
# Example: ./largest.sh 10 20 15
# End of script
##############################

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 num1 num2 num3"
    echo "Example: $0 10 20 15"
    exit 1
fi

num1=$1
num2=$2
num3=$3
# Initialize largest variable
largest=$num1
# Compare num1 and num2
if [ "$num2" -gt "$largest" ]; then
    largest=$num2
fi
# Compare largest and num3
if [ "$num3" -gt "$largest" ]; then
    largest=$num3
fi
echo "The largest number among $num1, $num2, and $num3 is: $largest"
# End of script

