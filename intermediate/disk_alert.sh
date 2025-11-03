#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-03 
# Description: This script monitors disk usage and sends an alert if it exceeds a specified threshold.
# Usage: ./disk_alert.sh path/to/directory <threshold_percentage> or bash disk_alert.sh path/to/directory <threshold_percentage
# Example: ./disk_alert.sh /home 80 or bash disk_alert.sh /home 80
################################

if [ $# -ne 2 ]; then
    echo "Usage: $0 <directory> <threshold_percentage>"
    echo "Example: $0 /path/to/directory 80"
    exit 1
fi
directory=$1
threshold=$2
# Check if the directory exists
if [ ! -d "$directory" ]; then
    echo "Error: Directory '$directory' does not exist."
    exit 1
fi
# Validate threshold is a number between 0 and 100
if ! [[ "$threshold" =~ ^[0-9]+$ ]] || [ "$threshold" -lt 0 ] || [ "$threshold" -gt 100 ]; then
    echo "Error: Threshold must be a number between 0 and 100."
    exit 1
fi

# Get the current disk usage percentage of the directory
usage=$(df -P "$directory" | awk 'NR==2 {print $5}' | sed 's/%//')
# Compare usage with threshold and print appropriate message
if [ "$usage" -ge "$threshold" ]; then
    echo "ALERT: Disk usage for '$directory' is at ${usage}%, which exceeds the threshold of ${threshold}%."
else
    echo "Disk usage for '$directory' is at ${usage}%. Usage is normal."
fi
# End of script

