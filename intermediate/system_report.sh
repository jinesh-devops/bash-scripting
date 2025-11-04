#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: This script reports system information including CPU usage, memory usage, and disk usage.
# Usage: ./system_report.sh or bash system_report.sh
# Example: ./system_report.sh or bash system_report.sh
################################
LOG_FILE="/var/log/system_report.csv"
# Get current date and time
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M:%S")
# Get CPU usage percentage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.2f", $2 + $4}')

# Get Memory usage percentage
MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100}' | awk '{printf "%.2f", $1}')
# Get Disk usage percentage for root directory
DISK_USAGE=$(df -P / | awk 'NR==2 {print $5}' | sed 's/%//')
# Check if log file exists, if not create it and add header
if [ ! -f "$LOG_FILE" ]; then
    echo "DATE,TIME,CPU_USAGE(%),MEMORY_USAGE(%),DISK_USAGE(%)" > "$LOG_FILE"
fi
# Append the new system report entry to the CSV file
echo "$DATE,$TIME,$CPU_USAGE,$MEMORY_USAGE,$DISK_USAGE" >> "$LOG_FILE"
echo "System report entry added to CSV successfully."
exit 0
# End of script
