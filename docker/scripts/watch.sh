#!/bin/bash
set -euo pipefail

# Load configuration
CONFIG_FILE="/app/config/duplexer.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Set defaults if not configured
INBOX="${INBOX:-/duplex-inbox}"
LOGFILE="${LOGFILE:-/logs/duplexer.log}"
FILE_PATTERN="${FILE_PATTERN:-*.pdf}"
PROCESS_DELAY="${PROCESS_DELAY:-2}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-60}"

# Logging function
log() { 
    local level="${1:-INFO}"
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [watch] $*"
    echo "$msg" | tee -a "$LOGFILE"
}

# Health check function
health_check() {
    log "DEBUG" "Health check - monitoring $INBOX for $FILE_PATTERN"
    
    # Check if directories exist and are accessible
    if [[ ! -d "$INBOX" ]]; then
        log "ERROR" "Inbox directory does not exist: $INBOX"
        return 1
    fi
    
    if [[ ! -r "$INBOX" ]]; then
        log "ERROR" "Inbox directory is not readable: $INBOX"
        return 1
    fi
    
    # Check disk space
    local available_space=$(df "$INBOX" | tail -1 | awk '{print $4}')
    if [[ "$available_space" -lt 10240 ]]; then  # Less than 10MB
        log "WARN" "Low disk space in inbox: ${available_space}KB available"
    fi
    
    return 0
}

# Startup
log "INFO" "Duplexer watcher starting up"
log "INFO" "Configuration:"
log "INFO" "  Inbox: $INBOX"
log "INFO" "  Pattern: $FILE_PATTERN" 
log "INFO" "  Process delay: ${PROCESS_DELAY}s"
log "INFO" "  Health check interval: ${HEALTH_CHECK_INTERVAL}s"

# Initial health check
if ! health_check; then
    log "ERROR" "Initial health check failed, exiting"
    exit 1
fi

log "INFO" "Duplexer watcher started successfully"

# Set up periodic health checks
last_health_check=0

while true; do
    # Periodic health check
    current_time=$(date +%s)
    if (( current_time - last_health_check >= HEALTH_CHECK_INTERVAL )); then
        health_check || log "WARN" "Health check failed"
        last_health_check=$current_time
    fi
    
    # Wait for file system events
    if inotifywait -e close_write,move,create "$INBOX" >/dev/null 2>&1; then
        log "INFO" "File system event detected"
        
        # Small delay to ensure file write is complete
        sleep "$PROCESS_DELAY"
        
        # Trigger processing
        log "INFO" "Triggering merge process"
        if /app/merge_once.sh; then
            log "INFO" "Merge process completed successfully"
        else
            log "ERROR" "Merge process failed with exit code $?"
        fi
    else
        log "DEBUG" "inotifywait exited, restarting monitor"
        sleep 1
    fi
done
