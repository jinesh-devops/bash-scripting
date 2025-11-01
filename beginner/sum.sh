#!/bin/bash
##############################
# Author: Cheedella Jinesh
# Date: 2025-11-01  
# Description: Sum of Numbers from 1 to N
# Usage: ./sum.sh <N> or bash sum.sh <N>
# Example: ./sum.sh 10 or bash sum.sh 10
##############################

# Check if the user provided an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <N>"
    exit 1
fi

N=$1
# Initialize sum variable
sum=0
# Loop from 1 to N and calculate the sum
for (( i=1; i<=N; i++ )); do
    sum=$((sum + i))
done

# Print the result
echo "The sum of numbers from 1 to $N is: $sum"
# End of script
