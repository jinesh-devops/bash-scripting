#!/bin/bash
#############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: Count Number of Lines in a File
# Usage: ./count_lines.sh <filename> or bash count_lines.sh <filename>
# Example: ./count_lines.sh myfile.txt or bash count_lines.sh myfile.txt
#############################
if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 myfile.txt"
    exit 1
fi
filename=$1
# Check if the file exists
if [ ! -f "$filename" ]; then
    echo "File not found!"
    exit 1
fi
# Count the number of lines in the file
line_count=$(wc -l < "$filename")
# Print the result
echo "The number of lines in the file '$filename' is: $line_count"
# End of script
