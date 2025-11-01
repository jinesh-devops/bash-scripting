#!/bin/bash
##############################
# Author: Cheedella Jinesh
# Date: 2025-11-01  
# Description: Check if a number is even or odd.
# Usage: ./even_odd.sh <N> or bash even_odd.sh <N>
# Example: ./even_odd.sh 5 or bash even_odd.sh 5
##############################

# Check if the user provided an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <N>"
    echo "Example: $0 5"
    exit 1
fi

number=$1

if (( number % 2 == 0 )); then
    echo "The number $number is EVEN."
else
    echo "The number $number is ODD."
fi

# End of script
