#!/bin/bash 
#############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script checks if a given number is prime.
# usage: ./prime_number.sh <number>
# Example: ./prime_number.sh 7
#############################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <number>"
    echo "Example: $0 7"
    exit 1
fi
number=$1
if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: Input must be a positive integer."
    exit 1
fi
if [ "$number" -le 1 ]; then
    echo "$number is not a prime number."
    exit 0
fi
is_prime=1
for (( i=2; i*i<=number; i++ )); do
    if [ $((number % i)) -eq 0 ]; then
        is_prime=0
        break
    fi
done
if [ $is_prime -eq 1 ]; then
    echo "$number is a prime number."
else    
    echo "$number is not a prime number."
fi
# End of script 

