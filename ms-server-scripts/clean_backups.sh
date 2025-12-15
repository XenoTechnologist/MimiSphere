#!/bin/bash

set -euo pipefail

Log()
{
    echo "[$DATE_LOG] $1" >> "$LOG_FILE"
    ##TODO: Create a logging script to call if we make more server scripts
}

Clean()
{
    # Initialize an empty array to store backup paths
    backups=()

    # Find and count all backup files
    backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.tar.gz" -type f | wc -l)

    # If there are less than 5 backups, cancel the execution
    if [ $backup_count -le $RETAIN_COUNT ]; then
        Log "INFO: $backup_count backups found. Operation canceled"
    fi

    # Only keep the last 5 backups
    delete_count=$((backup_count - RETAIN_COUNT))
    Log "INFO: $backup_count backups found. Removing $delete_count oldest backups:"

    # Add files to the arry and sort them newest to oldest
    for backup in $(ls $BACKUP_DIR/BKUP_*.tar.gz | sort -V -r); do
        backups+=("$backup")
    done

    # Create a new array for backups to delete [5] to [n]
    delete_backups=("${backups[@]:$RETAIN_COUNT}")

    # Loop through array and delete oldest backups
    for backup in "${delete_backups[@]}"; do
        rm -f "$backup"
        Log "Deleted $backup"
    done
}

########
# MAIN #
########

# Set environment variables
BACKUP_DIR="/usr/backups"
DATE_LOG="$(date '+%m/%d/%Y %H:%M:%S')"
LOG_DIR="/usr/server-scripts/logs"
LOG_FILE="${LOG_DIR}/clean_backups.log"
RETAIN_COUNT=5

# Ensure directories exist in the correct state
install -d -m 2770 -o root -g adm "$LOG_DIR"

# Cancel operation if /usr/backups does not exist
if [ ! -d "$BACKUP_DIR" ]; then
    Log "WARNING: $BACKUP_DIR does not exist. Canceling operation."
    exit 0
fi

Clean