#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-01
# Description: This script checks disk usage of a specified directory
# Usage: ./disk_usage.sh <directory> or bash disk_usage.sh <directory>
# Example: ./disk_usage.sh /path/to/directory or bash disk_usage.sh /path/to/directory
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
# Get the disk usage of the specified directory
disk_usage=$(du -sh "$directory" 2>/dev/null | cut -f1)
# Print the result
echo "Disk usage of directory '$directory': $disk_usage"
# End of script 
