#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: This script checks the SSL certificate expiration date of a given domain and alerts if it is about to expire.
# Usage: ./check_ssl.sh <domain> <days_before_expiry> or bash check_ssl.sh <domain> <days_before_expiry>
# Example: ./check_ssl.sh example.com 30
################################

if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <days_before_expiry>"
    echo "Example: $0 example.com 30"
    exit 1
fi

if ! command -v openssl &>/dev/null; then
    echo "Error: openssl is not installed. Please install openssl and retry."
    exit 3
fi

log_file="/var/log/ssl_expiry_check.log"
touch "$log_file" 2>/dev/null || {
    echo "Error: Cannot write to $log_file. Run as root or change log path."
    exit 4
}

domain=$1
days_before_expiry=$2

# Validate days_before_expiry is a positive integer
if ! [[ "$days_before_expiry" =~ ^[0-9]+$ ]] || [ "$days_before_expiry" -lt 0 ]; then
    echo "Error: days_before_expiry must be a positive integer."
    exit 1
fi

# Fetch SSL certificate expiry date
expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)

if [ -z "$expiry_date" ]; then
    echo "Error: Could not retrieve SSL certificate for domain '$domain'."
    exit 2
fi

# Convert expiry date to seconds since epoch
expiry_epoch=$(date -d "$expiry_date" +%s)
current_epoch=$(date +%s)

# Calculate remaining days
remaining_days=$(( (expiry_epoch - current_epoch) / 86400 ))

# Determine status and print message
if [ "$remaining_days" -lt "$days_before_expiry" ]; then
    status="WARNING"
    color_code="\e[31m" # Red
    exit_code=1
else
    status="OK"
    color_code="\e[32m" # Green
    exit_code=0
fi

# Print result
echo -e "${color_code}SSL Expiry Check for domain: $domain, Expiry Date: $expiry_date, Days remaining: $remaining_days, Status: $status\e[0m"

# Log result
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$timestamp] domain=$domain expiry_date=$expiry_date remaining_days=$remaining_days status=$status" >> "$log_file"

exit $exit_code
# End of script
