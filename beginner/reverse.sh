#!/bin/bash
##############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script provides the reverse of a given number.
# Usage: ./reverse_number.sh number
# Example: ./reverse_number.sh 12345
# End of script
##############################

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 number"
    echo "Example: $0 12345"
    exit 1
fi
input_number="$1"
# Reverse the input number using 'rev' command
reversed_number=$(echo "$input_number" | rev)
echo "The reverse of $input_number is: $reversed_number"
# End of script

