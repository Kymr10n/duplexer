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
ODD="${FILES[0]}"
EVEN="${FILES[1]}"

log "INFO" "Selected files for processing:"
log "INFO" "  Odd pages file:  $ODD"
log "INFO" "  Even pages file: $EVEN"

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

log "INFO" "Reversing even pages order"
if ! pdftk "$EVEN" cat end-1 output "$TMP_EVEN_REV"; then
    log "ERROR" "Failed to reverse even pages"
    exit 1
fi

log "INFO" "Merging odd and even pages"
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

log "INFO" "Moving merged file to output directory"
if ! mv "$MERGED" "$FINAL_OUT"; then
    log "ERROR" "Failed to move merged file to output directory"
    rm -f "$TMP_EVEN_REV" "$MERGED"
    exit 1
fi

log "INFO" "Merged file delivered successfully: $FINAL_OUT"

# Clean up temporary files
rm -f "$TMP_EVEN_REV"

# Remove source files only after successful completion
log "INFO" "Removing source PDF files"
rm -f "$ODD" "$EVEN"

log "INFO" "Processing complete for pair $TS"
log "INFO" "Backup files preserved: $BACKUP_ODD, $BACKUP_EVEN"

exit 0
