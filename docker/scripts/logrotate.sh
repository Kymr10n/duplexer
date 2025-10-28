#!/bin/bash
# Log rotation script for Duplexer

set -euo pipefail

LOGFILE="${LOGFILE:-/logs/duplexer.log}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-104857600}"  # 100MB in bytes
LOG_MAX_FILES="${LOG_MAX_FILES:-5}"

# Check if log file exists and needs rotation
if [[ ! -f "$LOGFILE" ]]; then
    exit 0
fi

# Get current log file size
current_size=$(stat -f --format="%s" "$LOGFILE" 2>/dev/null || stat -c %s "$LOGFILE")

# Check if rotation is needed
if [[ $current_size -lt $LOG_MAX_SIZE ]]; then
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [logrotate] Rotating log file (size: ${current_size} bytes)"

# Rotate existing log files
for ((i=LOG_MAX_FILES-1; i>=1; i--)); do
    if [[ -f "${LOGFILE}.${i}" ]]; then
        mv "${LOGFILE}.${i}" "${LOGFILE}.$((i+1))"
    fi
done

# Move current log to .1
mv "$LOGFILE" "${LOGFILE}.1"

# Create new log file
touch "$LOGFILE"
chmod 644 "$LOGFILE"

# Remove old log files beyond max count
for ((i=LOG_MAX_FILES+1; i<=20; i++)); do
    if [[ -f "${LOGFILE}.${i}" ]]; then
        rm -f "${LOGFILE}.${i}"
    fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [logrotate] Log rotation completed" >> "$LOGFILE"