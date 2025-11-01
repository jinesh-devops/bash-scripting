#!/bin/bash
###############################
# Author : Cheedella Jinesh
# Date : 2025-11-01
# Description : This script checks if a file is readable
# Usage : ./file_readable.sh <filename> or bash file_readable.sh <filename
# Example : ./file_readable.sh myfile.txt or bash file_readable.sh myfile.txt
################################
if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 myfile.txt"
    exit 1
fi
filename=$1
# Check if the file exists
if [ ! -e "$filename" ]; then
    echo "File '$filename' does not exist."
    exit 1
fi  

# Check if the file is readable
if [ -r "$filename" ]; then
    echo "File '$filename' is readable."
else
    echo "File '$filename' is not readable."    
fi
# End of script

