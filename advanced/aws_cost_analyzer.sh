#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: AWS Cost Analyzer - daily service cost report + spike detection
# Usage: ./aws_cost_analyzer.sh <aws_profile> <aws_region> <number_of_days> [--send-email]
# Example: ./aws_cost_analyzer.sh default us-east-1 7
###############################

set -o pipefail

# args
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 <aws_profile> <aws_region> <number_of_days> [--send-email]"
    exit 1
fi

AWS_PROFILE=$1
AWS_REGION=$2
DAYS=$3
SEND_EMAIL_FLAG=$4

# dependencies
if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI not found. Install and retry."
    exit 3
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq not found. Install and retry."
    exit 4
fi
if ! command -v bc >/dev/null 2>&1; then
    echo "Error: bc not found. Install and retry."
    exit 5
fi

# verify profile works
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    echo "Error: AWS profile '$AWS_PROFILE' not configured or invalid."
    exit 6
fi

# validate days
if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [ "$DAYS" -le 0 ]; then
    echo "Error: number_of_days must be a positive integer."
    exit 1
fi

# files & logging (using /var/log as requested)
LOG_FILE="/var/log/aws_cost_analyzer.log"
CSV_FILE="/var/log/aws_cost_report.csv"

touch "$LOG_FILE" 2>/dev/null || { echo "Error: Cannot write to $LOG_FILE (permission)."; exit 7; }
# create CSV header only once (full header including AverageCost and SpikeDetected)
if [ ! -f "$CSV_FILE" ] || [ ! -s "$CSV_FILE" ]; then
    echo "Date,Service,Cost,AverageCost,SpikeDetected" > "$CSV_FILE"
fi

# date range (UTC)
END_DATE=$(date -u +"%Y-%m-%d")
START_DATE=$(date -u -d "$DAYS days ago" +"%Y-%m-%d")

# services list (include AmazonVPC to capture NAT/VPC costs)
services=("AmazonEC2" "AmazonEBS" "AmazonS3" "AmazonRDS" "AmazonElasticLoadBalancing" "AmazonEKS" "AmazonVPC" "AWSLambda")

total_cost=0.00

# fetch costs per service (sum across the period)
for service in "${services[@]}"; do
    # prepare filter JSON (quote carefully)
    filter_json='{"Dimensions":{"Key":"SERVICE","Values":["'"$service"'"]}}'
    aws_out=$(aws ce get-cost-and-usage \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --time-period Start="$START_DATE",End="$END_DATE" \
        --granularity DAILY \
        --metrics "UnblendedCost" \
        --filter "$filter_json" 2>/dev/null)

    # extract amounts and sum (sum of daily amounts across the period)
    cost=$(echo "$aws_out" | jq -r '.ResultsByTime[].Total.UnblendedCost.Amount' 2>/dev/null | awk '{sum += $1} END {printf "%.2f", sum}')
    if [ -z "$cost" ] || [ "$cost" == "null" ]; then
        cost="0.00"
    fi

    # accumulate total (floating)
    total_cost=$(awk -v a="$total_cost" -v b="$cost" 'BEGIN {printf "%.2f", a + b}')
    # append service row (AverageCost & SpikeDetected placeholders left empty)
    echo "$(date -u +"%Y-%m-%d"),$service,$cost,," >> "$CSV_FILE"
done

# append total row (placeholders for avg/spike will be filled below after average calc)
echo "$(date -u +"%Y-%m-%d"),Total,$total_cost,," >> "$CSV_FILE"

# compute average of Total rows over previous <DAYS> days excluding today
# We consider Total rows with date in [CUTOFF_DATE, yesterday]
CUTOFF_DATE=$(date -u -d "$DAYS days ago" +"%Y-%m-%d")
TODAY=$(date -u +"%Y-%m-%d")

avg_sum=0.00
avg_count=0

# iterate CSV and sum previous TOTAL rows
while IFS=, read -r rdate rservice rcost ravg rspike; do
    if [ "$rservice" = "Total" ] && [ "$rdate" != "$TODAY" ]; then
        # include rows that are within the last DAYS days window (>= CUTOFF_DATE)
        if [[ "$rdate" > "$CUTOFF_DATE" || "$rdate" == "$CUTOFF_DATE" ]]; then
            if [[ "$rcost" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                avg_sum=$(awk -v s="$avg_sum" -v v="$rcost" 'BEGIN {printf "%.2f", s + v}')
                avg_count=$((avg_count + 1))
            fi
        fi
    fi
done < "$CSV_FILE"

if [ "$avg_count" -gt 0 ]; then
    average_cost=$(awk -v s="$avg_sum" -v c="$avg_count" 'BEGIN {printf "%.2f", s / c}')
else
    average_cost="0.00"
fi

# spike detection threshold from env (default 30%)
SPIKE_THRESHOLD=${SPIKE_THRESHOLD:-30}

if awk "BEGIN{exit !($average_cost > 0)}"; then
    threshold_cost=$(awk -v avg="$average_cost" -v th="$SPIKE_THRESHOLD" 'BEGIN {printf "%.2f", avg * (1 + th/100)}')
    is_spike=$(awk -v tot="$total_cost" -v tc="$threshold_cost" 'BEGIN{print (tot > tc) ? 1 : 0}')
else
    is_spike=0
    threshold_cost="0.00"
fi

# mark spike result string & log if spike
if [ "$is_spike" -eq 1 ]; then
    SPIKE_ALERT="YES"
    echo -e "\e[31mSPIKE ALERT: Today's cost \$$total_cost exceeds average cost \$$average_cost by more than ${SPIKE_THRESHOLD}% (threshold \$$threshold_cost)\e[0m"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] SPIKE ALERT: Today's cost \$$total_cost avg=\$$average_cost threshold=\$$threshold_cost" >> "$LOG_FILE"
else
    SPIKE_ALERT="NO"
fi

# Update the Total row for today to include AverageCost and SpikeDetected
TMP_FILE="$(mktemp)"
awk -F, -v today="$TODAY" -v avg="$average_cost" -v spike="$SPIKE_ALERT" 'BEGIN{OFS=","}
{
    # pad fields to 5 columns if fewer
    while (NF < 5) $NF = $NF
    if ($1 == today && $2 == "Total") {
        print $1,$2,$3,avg,spike
    } else {
        # ensure we always print 5 columns (some rows were appended with empty fields)
        if (NF < 5) {
            for (i = NF+1; i <= 5; i++) $i = ""
        }
        print $1,$2,$3,$4,$5
    }
}
' "$CSV_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CSV_FILE"

# Print summary to console (colors enabled)
echo -e "\e[32mAWS Cost Analysis Report\e[0m"
echo -e "Profile: \e[34m$AWS_PROFILE\e[0m"
echo -e "Region: \e[34m$AWS_REGION\e[0m"
echo -e "Period: \e[34m$START_DATE to $END_DATE\e[0m"
echo -e "Total Cost: \e[32m\$$total_cost\e[0m"
if [ "$SPIKE_ALERT" = "YES" ]; then
    echo -e "\e[31mSpike detected: YES (avg \$$average_cost)\e[0m"
else
    echo -e "\e[32mSpike detected: NO (avg \$$average_cost)\e[0m"
fi

# log summary
echo "[$(date +"%Y-%m-%d %H:%M:%S")] profile=$AWS_PROFILE region=$AWS_REGION start_date=$START_DATE end_date=$END_DATE total_cost=$total_cost avg_cost=$average_cost spike=$SPIKE_ALERT" >> "$LOG_FILE"

# optional email placeholder
if [ "$SEND_EMAIL_FLAG" = "--send-email" ]; then
    echo "Email sending functionality is not implemented yet."
fi

exit 0

