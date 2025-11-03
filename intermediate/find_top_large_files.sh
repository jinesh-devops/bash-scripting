#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-03
# Description: This script finds the top N largest files in a specified directory.
# Usage: ./find_top_large_files.sh <directory> <N> or bash find_top_large_files.sh <directory> <N>
# Example: ./find_top_large_files.sh /path/to/directory 5 or bash find_top_large_files.sh /path/to/directory 5
################################

if [ $# -ne 2 ]; then
    echo "Usage: $0 <directory> <N>"
    echo "Example: $0 /path/to/directory 5"
    exit 1
fi
directory=$1
N=$2
# Check if the directory exists
if [ ! -d "$directory" ]; then
    echo "Error: Directory '$directory' does not exist."
    exit 1
fi
# Validate N is a positive integer
if ! [[ "$N" =~ ^[0-9]+$ ]] || [ "$N" -le 0 ]; then
    echo "Error: N must be a positive integer."
    exit 1
fi
# Find and display the top N largest files in the directory
echo "Top $N largest files in directory '$directory':"
du -ah "$directory" | sort -rh | head -n "$N"
# End of script 

