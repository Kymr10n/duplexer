#!/bin/bash
set -euo pipefail

# Configuration
INBOX="${INBOX:-/duplex-inbox}"
OUTBOX="${OUTBOX:-/paperless-consume}"
LOGFILE="${LOGFILE:-/logs/duplexer.log}"
BACKUP_DIR="${BACKUP_DIR:-/logs/backup}"
MAX_WAIT_TIME="${MAX_WAIT_TIME:-300}" # 5 minutes max wait for second file

# Logging function
log() {
    local level="${1:-INFO}"
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg" | tee -a "$LOGFILE"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_num=$1
    log "ERROR" "Script failed at line $line_num with exit code $exit_code"
    # Clean up temp files on error
    rm -f /tmp/*_$(date +"%Y%m%d")*.pdf 2>/dev/null || true
    exit $exit_code
}

# Set up error trap
trap 'handle_error $LINENO' ERR

# Create necessary directories
mkdir -p "$BACKUP_DIR"

# PDF validation function
validate_pdf() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log "ERROR" "File does not exist: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log "ERROR" "File is not readable: $file"
        return 1
    fi

    # Check if file is actually a PDF
    if ! file "$file" | grep -q "PDF"; then
        log "ERROR" "File is not a valid PDF: $file"
        return 1
    fi

    # Test PDF with pdftk
    if ! pdftk "$file" dump_data >/dev/null 2>&1; then
        log "ERROR" "PDF appears corrupted or encrypted: $file"
        return 1
    fi

    log "INFO" "PDF validation passed: $file"
    return 0
}
# Get list of PDF files and validate count
mapfile -t FILES < <(find "$INBOX" -maxdepth 1 -name "*.pdf" -type f | sort || true)
COUNT=${#FILES[@]}

log "INFO" "Found $COUNT PDF files in inbox"

if [ "$COUNT" -eq 0 ]; then
    log "DEBUG" "No PDF files found, exiting"
    exit 0
fi

if [ "$COUNT" -eq 1 ]; then
    log "INFO" "Only single file found, waiting for second file: ${FILES[0]}"
    exit 0
fi

if [ "$COUNT" -gt 2 ]; then
    log "WARN" "More than 2 files found ($COUNT). Processing first two files only."
    log "WARN" "Extra files: ${FILES[@]:2}"
fi

# Select files to process
# Sort files by name to ensure consistent ordering
FILES=($(printf '%s\n' "${FILES[@]}" | sort))

# Detect which file contains odd vs even pages based on filename patterns
if [[ "${FILES[0]}" =~ odd && "${FILES[1]}" =~ even ]]; then
    ODD="${FILES[0]}"
    EVEN="${FILES[1]}"
    log "INFO" "Detected by filename pattern - odd: ${FILES[0]}, even: ${FILES[1]}"
elif [[ "${FILES[0]}" =~ even && "${FILES[1]}" =~ odd ]]; then
    ODD="${FILES[1]}"
    EVEN="${FILES[0]}"
    log "INFO" "Detected by filename pattern - odd: ${FILES[1]}, even: ${FILES[0]}"
else
    # If no pattern match, use alphabetical order but log a warning
    ODD="${FILES[0]}"
    EVEN="${FILES[1]}"
    log "WARN" "No filename pattern detected, using alphabetical order"
    log "WARN" "Assuming: odd=${FILES[0]}, even=${FILES[1]}"
    log "WARN" "For best results, use filenames containing 'odd' and 'even'"
fi

log "INFO" "Selected files for processing:"
log "INFO" "  Odd pages file:   $ODD"
log "INFO" "  Even pages file:  $EVEN"

# Validate both PDF files
if ! validate_pdf "$ODD"; then
    log "ERROR" "Odd pages file validation failed, moving to backup"
    mv "$ODD" "$BACKUP_DIR/" || true
    exit 1
fi

if ! validate_pdf "$EVEN"; then
    log "ERROR" "Even pages file validation failed, moving to backup"
    mv "$EVEN" "$BACKUP_DIR/" || true
    exit 1
fi
# Generate unique timestamp and file paths
TS=$(date +"%Y%m%d_%H%M%S")
TMP_EVEN_REV="/tmp/even_rev_$TS.pdf"
MERGED="/tmp/merged_$TS.pdf"
FINAL_OUT="$OUTBOX/duplex_$TS.pdf"

log "INFO" "Processing pair with timestamp: $TS"
log "INFO" "Target output: $FINAL_OUT"

# Create backup copies before processing
BACKUP_ODD="$BACKUP_DIR/odd_$(basename "$ODD" .pdf)_$TS.pdf"
BACKUP_EVEN="$BACKUP_DIR/even_$(basename "$EVEN" .pdf)_$TS.pdf"

log "INFO" "Creating backup copies"
cp "$ODD" "$BACKUP_ODD" || {
    log "ERROR" "Failed to create backup of odd file"
    exit 1
}
cp "$EVEN" "$BACKUP_EVEN" || {
    log "ERROR" "Failed to create backup of even file"
    exit 1
}

# Check available disk space
AVAILABLE_SPACE=$(df /tmp | tail -1 | awk '{print $4}')
REQUIRED_SPACE=$(( $(stat -f --format="%s" "$ODD") + $(stat -f --format="%s" "$EVEN") ))

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    log "ERROR" "Insufficient disk space. Available: $AVAILABLE_SPACE, Required: $REQUIRED_SPACE"
    exit 1
fi

log "INFO" "Reversing even pages order (duplex scanning correction)"
log "DEBUG" "Original even pages file: $EVEN"
if ! pdftk "$EVEN" cat end-1 output "$TMP_EVEN_REV"; then
    log "ERROR" "Failed to reverse even pages"
    exit 1
fi
log "DEBUG" "Reversed even pages file: $TMP_EVEN_REV"

log "INFO" "Merging odd and even pages in correct order"
log "DEBUG" "Merge command: pdftk A=\"$ODD\" B=\"$TMP_EVEN_REV\" shuffle A B output \"$MERGED\""
# For duplex printing: Odd pages are 1,3,5,... Even pages (after reversal) should be 2,4,6,...
# We want final order: 1,2,3,4,5,6,... so we shuffle A1 B1 A2 B2 A3 B3...
if ! pdftk A="$ODD" B="$TMP_EVEN_REV" shuffle A B output "$MERGED"; then
    log "ERROR" "Failed to merge PDF files"
    rm -f "$TMP_EVEN_REV"
    exit 1
fi

# Validate merged output
if ! validate_pdf "$MERGED"; then
    log "ERROR" "Merged PDF validation failed"
    rm -f "$TMP_EVEN_REV" "$MERGED"
    exit 1
fi

# Source email functions
if [[ -f "/app/send_email.sh" ]]; then
    source /app/send_email.sh
fi

# Check if email approval is enabled
if [[ -n "${APPROVAL_EMAIL:-}" ]] && command -v python3 >/dev/null && is_email_configured 2>/dev/null; then
    log "INFO" "Email approval enabled - holding merged file for approval"

    # Create pending directory
    PENDING_DIR="/logs/pending"
    mkdir -p "$PENDING_DIR"

    # Generate unique token for this merge
    MERGE_TOKEN="merge_${TS}_$(date +%s | tail -c 6)"

    # Move merged file to pending location instead of final output
    PENDING_PDF="$PENDING_DIR/$(basename "$FINAL_OUT")"
    if ! mv "$MERGED" "$PENDING_PDF"; then
        log "ERROR" "Failed to move merged file to pending directory"
        rm -f "$TMP_EVEN_REV" "$MERGED"
        exit 1
    fi

    # Create pending file with metadata
    cat > "$PENDING_DIR/${MERGE_TOKEN}.pending" << EOF
MERGE_TOKEN=$MERGE_TOKEN
TIMESTAMP=$TS
MERGED_PDF=$PENDING_PDF
ORIGINAL_ODD=$BACKUP_ODD
ORIGINAL_EVEN=$BACKUP_EVEN
FINAL_OUTPUT=$FINAL_OUT
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    log "INFO" "Sending approval email with merged PDF attached"
    if send_approval_email "$PENDING_PDF" "$BACKUP_ODD" "$BACKUP_EVEN" "$MERGE_TOKEN" "$TS"; then
        log "INFO" "Approval email sent successfully for token: $MERGE_TOKEN"
        log "INFO" "Merged file awaiting approval: $PENDING_PDF"
        log "INFO" "To manually approve: touch $PENDING_DIR/APPROVE_$MERGE_TOKEN"
        log "INFO" "To manually reject: touch $PENDING_DIR/REJECT_$MERGE_TOKEN"
    else
        log "ERROR" "Failed to send approval email - proceeding without approval"
        # Fallback: move to final output if email fails
        if ! mv "$PENDING_PDF" "$FINAL_OUT"; then
            log "ERROR" "Failed to move file to final output after email failure"
            exit 1
        fi
        log "INFO" "Merged file delivered without approval: $FINAL_OUT"
    fi

else
    log "INFO" "Email approval disabled - delivering merged file directly"

    # Original behavior: move directly to output
    if ! mv "$MERGED" "$FINAL_OUT"; then
        log "ERROR" "Failed to move merged file to output directory"
        rm -f "$TMP_EVEN_REV" "$MERGED"
        exit 1
    fi

    log "INFO" "Merged file delivered successfully: $FINAL_OUT"
fi

# Clean up temporary files
rm -f "$TMP_EVEN_REV"

# Remove source files only after successful completion
log "INFO" "Removing source PDF files"
rm -f "$ODD" "$EVEN"

log "INFO" "Processing complete for pair $TS"
log "INFO" "Backup files preserved: $BACKUP_ODD, $BACKUP_EVEN"

exit 0
