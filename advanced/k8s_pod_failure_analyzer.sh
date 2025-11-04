#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: Kubernetes Pod Failure Analyzer - analyzes pod failure events and generates a report.
# Usage: ./k8s_pod_failure_analyzer.sh <namespace> <critical_threshold_count> [--send-email]
# Example: ./k8s_pod_failure_analyzer.sh default 5
###############################
set -o pipefail
# args
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <namespace> <critical_threshold_count> [--send-email]"
    echo "Example: $0 default 5"
    exit 1
fi
NAMESPACE=$1
CRITICAL_THRESHOLD=$2
SEND_EMAIL_FLAG=$3
# dependencies
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl not found. Install and retry."
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
# validate critical_threshold
if ! [[ "$CRITICAL_THRESHOLD" =~ ^[0-9]+$ ]] || [ "$CRITICAL_THRESHOLD" -lt 0 ]; then
    echo "Error: critical_threshold_count must be a positive integer."
    exit 1
fi
# files & logging
LOG_FILE="/var/log/k8s_pod_health.log"
CSV_FILE="/var/log/k8s_pod_issues_$(date +%F).csv"
touch "$LOG_FILE" 2>/dev/null || { echo "Error: Cannot write to $LOG_FILE (permission)."; exit 6; }
# create CSV header only once
if [ ! -f "$CSV_FILE" ] || [ ! -s "$CSV_FILE" ]; then
    echo "Date,Namespace,Pod,IssueType,Reason,Container,AlertTriggered" > "$CSV_FILE"
fi
# get namespaces to scan
if [ "$NAMESPACE" == "all" ]; then
    NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
else
    NAMESPACES=$NAMESPACE
fi
# initialize issue count
issue_count=0
current_date=$(date +%F)
# analyze pods in each namespace
for ns in $NAMESPACES; do
    pods=$(kubectl get pods -n "$ns" --field-selector=status.phase!=Running -o json)
    pod_count=$(echo "$pods" | jq '.items | length')
    if [ "$pod_count" -eq 0 ]; then
        continue
    fi
    for i in $(seq 0 $((pod_count - 1))); do
        pod_name=$(echo "$pods" | jq -r ".items[$i].metadata.name")
        container_count=$(echo "$pods" | jq ".items[$i].spec.containers | length")
        for j in $(seq 0 $((container_count - 1))); do
            container_name=$(echo "$pods" | jq -r ".items[$i].spec.containers[$j].name")
            # check for failure reasons
            reasons=$(kubectl get pod "$pod_name" -n "$ns" -o json | jq -r ".status.containerStatuses[$j].state.waiting.reason, .status.containerStatuses[$j].state.terminated.reason" | grep -E "CrashLoopBackOff|ImagePullBackOff|ErrImagePull|OOMKilled" | grep -v null)
            for reason in $reasons; do
                issue_type="PodFailure"
                echo "$current_date,$ns,$pod_name,$issue_type,$reason,$container_name,YES" >> "$CSV_FILE"
                issue_count=$((issue_count + 1))
            done
        done
        # check for PendingTooLong
        pod_phase=$(echo "$pods" | jq -r ".items[$i].status.phase")
        if [ "$pod_phase" == "Pending" ]; then
            start_time=$(kubectl get pod "$pod_name" -n "$ns" -o jsonpath='{.status.startTime}')
            start_epoch=$(date -d "$start_time" +%s)
            current_epoch=$(date +%s)
            pending_duration=$((current_epoch - start_epoch))
            if [ "$pending_duration" -gt 300 ]; then
                reason="PendingTooLong"
                issue_type="PodPending"
                echo "$current_date,$ns,$pod_name,$issue_type,$reason,N/A,YES" >> "$CSV_FILE"
                issue_count=$((issue_count + 1))
            fi
        fi
    done
done
# check for NodeNotReady
nodes=$(kubectl get nodes -o json)
node_count=$(echo "$nodes" | jq '.items | length')
for i in $(seq 0 $((node_count - 1))); do
    node_name=$(echo "$nodes" | jq -r ".items[$i].metadata.name")
    conditions=$(echo "$nodes" | jq -r ".items[$i].status.conditions[] | select(.type==\"Ready\") | .status")
    if [ "$conditions" != "True" ]; then
        reason="NodeNotReady"
        issue_type="NodeIssue"
        echo "$current_date,N/A,N/A,$issue_type,$reason,N/A,YES" >> "$CSV_FILE"
        issue_count=$((issue_count + 1))
    fi
done
# determine alert status
if [ "$issue_count" -gt "$CRITICAL_THRESHOLD" ]; then
    status="ALERT"
    color_code="\e[31m" # Red
else
    status="OK"
    color_code="\e[32m" # Green
fi
# print summary
echo -e "${color_code}K8s Pod Failure Analysis Report for Namespace: $NAMESPACE
Date: $current_date
Total Issues Detected: $issue_count
Threshold: $CRITICAL_THRESHOLD
Status: $status\e[0m"
# log to file
echo "$(date +'%Y-%m-%d %H:%M:%S') - Namespace: $NAMESPACE, Total Issues: $issue_count, Threshold: $CRITICAL_THRESHOLD, Status: $status" >> "$LOG_FILE"
# placeholder for email notification
if [ "$SEND_EMAIL_FLAG" == "--send-email" ]; then
    echo "Email notification feature is not implemented yet."
fi  
exit 0
# End of script

