#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script counts the number of files in a directory
# Usage: ./count_files.sh <directory> or bash count_files.sh <directory>
# Example: ./count_files.sh /path/to/directory or bash count_files.sh /path/to/directory
################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    echo "Example: $0 /path/to/directory"
    exit 1
fi
directory=$1
# Check if the directory exists
if [ ! -d "$directory" ]; then
    echo "Error: Directory '$directory' does not exist."
    exit 1
fi
# Count the number of files in the directory
file_count=$(find "$directory" -maxdepth 1 -type f | wc -l)
# Print the result
echo "The number of files in the directory '$directory' is: $file_count"
# End of script 
