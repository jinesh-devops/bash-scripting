#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: This script analyzes log files for error patterns and summarizes the findings.
# Usage: ./log_error_analyzer.sh path/to/logfile or bash log_error_analyzer.sh path/to/logfile
# Example: ./log_error_analyzer.sh /var/log/syslog or bash log_error_analyzer.sh /var/log/syslog
################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path/to/logfile>"
    echo "Example: $0 /var/log/syslog"
    exit 1
fi
logfile=$1
# Check if the log file exists
if [ ! -f "$logfile" ]; then
    echo "Error: Log file '$logfile' does not exist."
    exit 2
fi
# Count occurrences of each pattern (case-insensitive)
error_count=$(grep -i -c "ERROR" "$logfile")
warning_count=$(grep -i -c "WARNING" "$logfile")
info_count=$(grep -i -c "INFO" "$logfile")
# Get current timestamp
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
# Prepare the output string
output="$timestamp ERROR=$error_count WARNING=$warning_count INFO=$info_count"
# Print to terminal
echo "$output"
# Append to summary log file
echo "$output" >> /var/log/log_summary.log
# End of script 
