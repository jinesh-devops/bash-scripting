#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: This script shows users who have been inactive for a specified number of days.
# Usage: ./inactive_users.sh <number_of_days> or bash inactive_users.sh <number_of_days>
# Example: ./inactive_users.sh 30 or bash inactive_users.sh 30
################################
if [ $# -ne 1 ]; then
    echo "Usage: $0 <number_of_days>"
    echo "Example: $0 30"
    exit 1
fi
DAYS=$1
# Validate DAYS is a positive integer
if ! [[ "$DAYS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of days must be a positive integer."
    exit 1
fi
LOG_FILE="/var/log/inactive_users.log"
# Get current date for logging
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")
# Find inactive users
INACTIVE_USERS=$(awk -v days="$DAYS" -v current_date="$(date +%s)" -F: '($3 > 1000) {
    last_login = $0
    "lastlog -u " $1 | getline log_info
    split(log_info, arr)
    if (arr[4] == "Never") {
        inactive_days = days + 1
    } else {
        cmd = "date -d \"" arr[4] " " arr[5] " " arr[6] "\" +%s"
        cmd | getline last_login_time
        inactive_days = (current_date - last_login_time) / 86400
    }
    if (inactive_days >= days) {
        print $1
    }
}' /etc/passwd)
# Initialize count
COUNT=0
# Prepare output
OUTPUT=""
if [ -n "$INACTIVE_USERS" ]; then
    OUTPUT+="Inactive users for the last $DAYS days:\n"
    while IFS= read -r user; do
        OUTPUT+="$user\n"
        COUNT=$((COUNT + 1))
    done <<< "$INACTIVE_USERS"
else
    OUTPUT="No inactive users found in last $DAYS days\n"
fi
OUTPUT+="Total inactive users: $COUNT\n"
# Print to console
echo -e "$OUTPUT"
# Log to file
{
    echo "[$CURRENT_DATE] Inactive users for the last $DAYS days:"
    if [ -n "$INACTIVE_USERS" ]; then
        while IFS= read -r user; do
            echo "$user"
        done <<< "$INACTIVE_USERS"
    else
        echo "No inactive users found in last $DAYS days"
    fi
    echo "Total inactive users: $COUNT"
} >> "$LOG_FILE"
# End of script 

