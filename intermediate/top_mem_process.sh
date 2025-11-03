#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-03
# Description: This script monitors the top memory-consuming processes.
# Usage: ./top_mem_process.sh <number_of_processes> or bash top_mem_process.sh <number_of_processes>
# Example: ./top_mem_process.sh 5 or bash top_mem_process.sh 5
################################

# If no argument passed default = 5
if [ $# -eq 0 ]; then
    N=5
else
    N=$1
fi

# Validate N is a positive integer
if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of processes must be a positive integer."
    exit 1
fi

echo "Top $N memory-consuming processes:"
printf "%-8s %-6s %s\n" "PID" "MEM%" "COMMAND"

# Get top N processes sorted by memory usage
ps aux --sort=-%mem | awk -v n="$N" 'NR>1 && NR<=n+1 {printf "%-8s %-6s %s\n", $2, $4, $11}'
# End of script

