#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: This script checks the health of a given URL by sending an HTTP request and evaluating the response status code.
# Usage: ./url_health_check.sh <URL> or bash url_health_check.sh <URL>
# Example: ./url_health_check.sh https://www.example.com or bash url_health_check.sh https://www.example.com
################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <URL>"
    echo "Example: $0 https://www.example.com"
    exit 1
fi
URL=$1
LOG_FILE="/var/log/url_health.log"
# Create log file if it does not exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi
# Get current date and time
CURRENT_DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# Send HTTP request and get status code
STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
# Determine health status based on status code
if [ "$STATUS_CODE" -eq 200 ]; then
    RESULT="HEALTHY"
    EXIT_CODE=0
else
    RESULT="NOT HEALTHY"
    EXIT_CODE=1
fi
# Log the result
echo "$CURRENT_DATE_TIME $URL $STATUS_CODE $RESULT" >> "$LOG_FILE"
# Print the result to the console
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "URL is healthy."
else
    echo "URL is not healthy."
fi
exit $EXIT_CODE
# End of script
