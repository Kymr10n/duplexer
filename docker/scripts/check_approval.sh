#!/bin/bash
# Email approval checker for Duplexer
# This script monitors for approval/rejection responses

set -euo pipefail

PENDING_DIR="/logs/pending"
REJECTED_DIR="/logs/rejected"
OUTBOX="${OUTBOX:-/paperless-consume}"
LOGFILE="${LOGFILE:-/logs/duplexer.log}"

# Source email functions
source /app/send_email.sh

# Logging function
log() {
    local level="${1:-INFO}"
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [approval] $*"
    echo "$msg" | tee -a "$LOGFILE"
}

# Create directories
mkdir -p "$PENDING_DIR" "$REJECTED_DIR"

# Function to check for manual approval files
# Users can create files like: /logs/pending/APPROVE_token or /logs/pending/REJECT_token
check_manual_approval() {
    local token="$1"
    local pending_file="$PENDING_DIR/${token}.pending"

    if [[ ! -f "$pending_file" ]]; then
        return 1
    fi

    # Check for approval/rejection files
    if [[ -f "$PENDING_DIR/APPROVE_${token}" ]]; then
        log "INFO" "✅ Manual approval detected for token: $token"
        process_approval "$token" "approved"
        rm -f "$PENDING_DIR/APPROVE_${token}"
        return 0
    elif [[ -f "$PENDING_DIR/REJECT_${token}" ]]; then
        log "INFO" "❌ Manual rejection detected for token: $token"
        process_approval "$token" "rejected"
        rm -f "$PENDING_DIR/REJECT_${token}"
        return 0
    fi

    return 1
}

# Function to process approval/rejection
process_approval() {
    local token="$1"
    local action="$2"  # "approved" or "rejected"

    local pending_file="$PENDING_DIR/${token}.pending"

    if [[ ! -f "$pending_file" ]]; then
        log "ERROR" "Pending file not found for token: $token"
        return 1
    fi

    # Read pending file details
    local merged_pdf_path
    local original_odd
    local original_even

    merged_pdf_path=$(grep "^MERGED_PDF=" "$pending_file" | cut -d'=' -f2)
    original_odd=$(grep "^ORIGINAL_ODD=" "$pending_file" | cut -d'=' -f2)
    original_even=$(grep "^ORIGINAL_EVEN=" "$pending_file" | cut -d'=' -f2)

    if [[ "$action" == "approved" ]]; then
        log "INFO" "Processing approval for $token"

        # Move merged PDF to paperless consume folder
        if [[ -f "$merged_pdf_path" ]]; then
            log "INFO" "Moving approved document to paperless consume folder"
            mv "$merged_pdf_path" "$OUTBOX/"
            log "INFO" "✅ APPROVED: Document delivered to paperless: $(basename "$merged_pdf_path")"
            log "INFO" "Document is now available in paperless-ngx for processing"
        else
            log "ERROR" "Merged PDF not found: $merged_pdf_path"
        fi

        # Send confirmation email
        # send_confirmation_email "approved" "$token" "$merged_pdf_path"

    elif [[ "$action" == "rejected" ]]; then
        log "INFO" "Processing rejection for $token"

        # Move merged PDF to rejected folder
        if [[ -f "$merged_pdf_path" ]]; then
            log "INFO" "Moving rejected document to rejected folder"
            mv "$merged_pdf_path" "$REJECTED_DIR/"
            log "INFO" "❌ REJECTED: Document moved to rejected folder: $(basename "$merged_pdf_path")"
            log "INFO" "Rejected document available at: $REJECTED_DIR/$(basename "$merged_pdf_path")"
        else
            log "ERROR" "Merged PDF not found: $merged_pdf_path"
        fi

        # Send confirmation email
        # send_confirmation_email "rejected" "$token" "$merged_pdf_path"
    fi

    # Clean up pending file
    rm -f "$pending_file"
    log "INFO" "Approval process completed for token: $token"
}

# Function to check for expired requests
check_expired_requests() {
    local max_age_hours=24
    local max_age_seconds=$((max_age_hours * 3600))

    for pending_file in "$PENDING_DIR"/*.pending; do
        [[ -f "$pending_file" ]] || continue

        local file_age
        file_age=$(stat -c %Y "$pending_file" 2>/dev/null || echo 0)
        local current_time
        current_time=$(date +%s)
        local age_seconds=$((current_time - file_age))

        if [[ $age_seconds -gt $max_age_seconds ]]; then
            local token
            token=$(basename "$pending_file" .pending)
            log "WARN" "Request expired for token: $token (age: ${age_seconds}s)"
            process_approval "$token" "rejected"
        fi
    done
}

# Main loop - if running as daemon
if [[ "${1:-}" == "daemon" ]]; then
    log "INFO" "Starting approval checker daemon"

    while true; do
        # Check all pending requests
        for pending_file in "$PENDING_DIR"/*.pending; do
            [[ -f "$pending_file" ]] || continue

            token=$(basename "$pending_file" .pending)

            # Check for manual approval first
            if check_manual_approval "$token"; then
                continue
            fi
        done

        # Check for expired requests
        check_expired_requests

        # Sleep for 30 seconds before next check
        sleep 30
    done
else
    # Single check mode
    if [[ -n "${1:-}" ]]; then
        check_manual_approval "$1"
    else
        log "ERROR" "Token required for single check mode"
        exit 1
    fi
fi