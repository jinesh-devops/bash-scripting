#!/bin/bash
###############################
# Author: Cheedella Jinesh
# Date: 2025-11-04
# Description: This script creates a backup of a specified directory.
# Usage: ./directory_backup.sh path/to/directory or bash directory_backup.sh path/to/directory
# Example: ./directory_backup.sh /home/user/documents or bash directory_backup.sh /home/user/documents
################################
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_to_backup>"
    echo "Example: $0 /path/to/directory"
    exit 1
fi
directory_to_backup=$1
# Check if the directory exists
if [ ! -d "$directory_to_backup" ]; then
    echo "Error: Directory '$directory_to_backup' does not exist."
    exit 1
fi
# Create /var/backups if it does not exist
backup_dir="/var/backups"
if [ ! -d "$backup_dir" ]; then
    mkdir -p "$backup_dir"
fi
# Generate backup file name
dirname=$(basename "$directory_to_backup")
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_filename="backup_${dirname}_${timestamp}.tar.gz"
backup_filepath="${backup_dir}/${backup_filename}"
# Create the backup using tar with gzip compression
tar -czf "$backup_filepath" -C "$(dirname "$directory_to_backup")" "$dirname"
# Check if the tar command was successful
if [ $? -eq 0 ]; then
    echo "Backup successful! Backup file created at: $backup_filepath"
else
    echo "Error: Backup failed."
    exit 1
fi
# End of script 

