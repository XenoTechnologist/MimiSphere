#!/bin/bash

set -euo pipefail

# Generate log lines
Log(){
    echo "[$DATE_LOG] $1" >> "$LOG_FILE"
}

Backup(){
    Log "Starting Backup of /etc/..."

    # Capture errors/warnings
    tar_error=$(tar -czf "$BACKUP_PATH" -C / etc 2>&1 1>/dev/null)
    tar_exit=$? # exit status of previous command

    if [ -n "$tar_error" ]; then
        Log "WARNING: $tar_error"
    fi

    if [ $tar_exit -ge 2 ]; then
        Log "ERROR: Backup failed - Exit code $tar_exit"
        exit 1
    else
        Log "Backup Complete: $BACKUP_NAME"
    fi
}

########
# MAIN #
########

# Set Environment Variables
BACKUP_DIR="/usr/backups"
LOG_DIR="/usr/server-scripts/logs"
LOG_FILE="$LOG_DIR/backup.log"
DATE_FULL="$(date '+%Y%m%d%H%M%S')"
DATE_LOG="$(date '+%m/%d/%Y %H:%M:%S')"
BACKUP_NAME="BKUP_${DATE_FULL}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Ensure directories exist in the correct state
install -d -m 2770 -o root -g adm "$BACKUP_DIR"
install -d -m 2770 -o root -g adm "$LOG_DIR"

Backup