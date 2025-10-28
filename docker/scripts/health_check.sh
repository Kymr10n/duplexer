#!/bin/bash
# Health check script for Duplexer container

set -euo pipefail

# Configuration
INBOX="${INBOX:-/duplex-inbox}"
OUTBOX="${OUTBOX:-/paperless-consume}"
LOGFILE="${LOGFILE:-/logs/duplexer.log}"
MAX_LOG_AGE=3600  # 1 hour

# Check if main process is running
if ! pgrep -f "watch.sh" >/dev/null; then
    echo "ERROR: watch.sh process not running"
    exit 1
fi

# Check if directories are accessible
for dir in "$INBOX" "$OUTBOX" "$(dirname "$LOGFILE")"; do
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory not accessible: $dir"
        exit 1
    fi
    
    if [[ ! -w "$dir" ]]; then
        echo "ERROR: Directory not writable: $dir"
        exit 1
    fi
done

# Check if log file is being updated (process is active)
if [[ -f "$LOGFILE" ]]; then
    log_modified=$(stat -c %Y "$LOGFILE" 2>/dev/null || echo 0)
    current_time=$(date +%s)
    log_age=$(( current_time - log_modified ))
    if [[ $log_age -gt $MAX_LOG_AGE ]]; then
        echo "WARNING: Log file not updated in $log_age seconds"
        exit 1
    fi
fi

# Check available disk space (minimum 100MB)
available_space=$(df /tmp | tail -1 | awk '{print $4}')
if [[ $available_space -lt 102400 ]]; then
    echo "ERROR: Insufficient disk space: ${available_space}KB available"
    exit 1
fi

# Test PDF tools availability
if ! command -v pdftk >/dev/null; then
    echo "ERROR: pdftk not available"
    exit 1
fi

if ! command -v inotifywait >/dev/null; then
    echo "ERROR: inotifywait not available"
    exit 1
fi

echo "OK: Duplexer health check passed"
exit 0