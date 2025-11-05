#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-05
# Description: Nginx Attack Analyzer - analyzes Nginx logs for potential attacks
# Usage: ./nginx_attack_analyzer.sh <nginx_log_file> <Threshold_for_request_count_per_ip> [--send-email]
# Example: ./nginx_attack_analyzer.sh /var/log/nginx/access.log 200 --send-email
###############################

set -o pipefail
# args
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <nginx_log_file> <Threshold_for_request_count_per_ip> [--send-email]"
    exit 1
fi
NGINX_LOG_FILE=$1
REQUEST_THRESHOLD=$2
SEND_EMAIL_FLAG=$3
# dependencies
for cmd in awk grep tail sort head; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Error: $cmd not found. Install and retry."
        exit 3
    fi
done
# validate log file
if [ ! -f "$NGINX_LOG_FILE" ] || [ ! -r "$NGINX_LOG_FILE" ]; then
    echo "Error: Nginx log file '$NGINX_LOG_FILE' not found or not readable."
    exit 4
fi
# validate threshold
if ! [[ "$REQUEST_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$REQUEST_THRESHOLD" -le 0 ]; then
    echo "Error: Threshold for request count per IP must be a positive integer."
    exit 1
fi
# files & logging
REPORT_DIR="/var/log/nginx_attack_analyzer/reports/"
mkdir -p "$REPORT_DIR" || { echo "Error: Cannot create report directory $REPORT_DIR."; exit 5; }
TIMESTAMP=$(date +"%Y%m%d")
CSV_FILE="$REPORT_DIR/nginx_attack_report_$TIMESTAMP.csv"
# create CSV header
if [ ! -f "$CSV_FILE" ] || [ ! -s "$CSV_FILE" ]; then
    echo "timestamp,ip,total_requests,4xx_count,5xx_count,user_agent,flagged_reason,sample_url" > "$CSV_FILE"
fi
# analyze log (reading only last 10,000 lines)
TAIL_LINES=10000
SUSPICIOUS_IPS=0
TAIL_CMD="tail -n $TAIL_LINES $NGINX_LOG_FILE"
$TAIL_CMD | awk -v req_thresh="$REQUEST_THRESHOLD" '
{
    ip=$1;
    status=$9;
    user_agent="";
    for(i=12;i<=NF;i++) user_agent=user_agent $i " ";
    url=$7;
    requests[ip]++;
    if(status ~ /^4/) errors_4xx[ip]++;
    if(status ~ /^5/) errors_5xx[ip]++;
    sample_url[ip]=url;
    user_agents[ip]=user_agent;
}
END {
    for(ip in requests) {
        flagged_reason="";
        if(requests[ip] > req_thresh) flagged_reason="High Request Spike";
        if(errors_4xx[ip] > 50) flagged_reason=flagged_reason ", Too many 4xx";
        if(errors_5xx[ip] > 10) flagged_reason=flagged_reason ", Too many 5xx";
        if (user_agents[ip] ~ /curl|python|wget|go-http-client|java|bot|spider|scanner/) {
            flagged_reason = (flagged_reason == "" ? "Suspicious UserAgent" : flagged_reason ", Suspicious UserAgent")
        }
        if (sample_url[ip] ~ /wp-admin|wp-login|phpmyadmin|setup\.php|xmlrpc\.php|\.env|\/login|\/admin/) {
            flagged_reason = (flagged_reason == "" ? "Sensitive Path Probe" : flagged_reason ", Sensitive Path Probe")
        }
        if(flagged_reason != "") {
            timestamp=strftime("%Y-%m-%d %H:%M:%S");
            print timestamp "," ip "," requests[ip] "," (errors_4xx[ip]+0) "," (errors_5xx[ip]+0) "," "\"" gensub(/"/, "", "g", user_agents[ip]) "\""
             "," "\"" flagged_reason "\"" "," sample_url[ip];
        }
    }
}
' >> "$CSV_FILE"
# count suspicious IPs
SUSPICIOUS_IPS=$(wc -l < "$CSV_FILE")
SUSPICIOUS_IPS=$((SUSPICIOUS_IPS - 1)) # subtract header line
# console output
echo "Suspicious IPs Found: $SUSPICIOUS_IPS"
echo "Report saved: $CSV_FILE"  
# end of script




