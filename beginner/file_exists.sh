#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script checks if a file exists
# Usage: ./file_exists.sh <filename> or bash file_exists.sh <filename>
# Example: ./file_exists.sh myfile.txt or bash file_exists.sh myfile.txt
################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 myfile.txt"
    exit 1
fi
filename=$1
# Check if the file exists
if [ -e "$filename" ]; then
    echo "File '$filename' exists."
else
    echo "File '$filename' does not exist."
fi
# End of script

