#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-03
# Description: This script monitors if a specified service is running and restarts it if it's not.
# Usage: ./service_monitor.sh <service_name> or bash service_monitor.sh <service_name>
# Example: ./service_monitor.sh nginx or bash service_monitor.sh nginx
################################

if [ $# -ne 1 ]; then
    echo "Usage: $0 <service_name>"
    echo "Example: $0 nginx"
    exit 1
fi
service_name=$1
# Check if the service exists
if ! systemctl list-unit-files --type=service | grep -qw "${service_name}.service"; then
    echo "Error: Service '$service_name' does not exist."
    exit 1
fi
# Check if the service is running
if systemctl is-active --quiet "$service_name"; then
    echo "Service '$service_name' is running."
else
    echo "Service '$service_name' is not running. Restarting it now..."
    # Attempt to restart the service
    if sudo systemctl restart "$service_name"; then
        # Check again if the service is running after restart
        if systemctl is-active --quiet "$service_name"; then
            echo "Service '$service_name' has been restarted successfully and is now running."
        else
            echo "Failed to restart service '$service_name'. It is still not running."
        fi
    else
        echo "Failed to restart service '$service_name'."
    fi
fi
# End of script

