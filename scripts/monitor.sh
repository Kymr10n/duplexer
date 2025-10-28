#!/bin/bash
# Monitor script for real-time Duplexer monitoring

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(dirname "$0")"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env file if it exists
if [[ -f "$WORKSPACE_DIR/.env" ]]; then
    source "$WORKSPACE_DIR/.env"
fi

# Set defaults
NAS_HOST="${NAS_HOST:-ugadmin@***REMOVED***}"
INBOX_PATH="${INBOX_PATH:-/volume1/services/duplexer/inbox}"
LOGS_PATH="${LOGS_PATH:-/volume1/services/duplexer/logs}"

echo "📊 Duplexer Monitor Dashboard"
echo "============================"
echo "Target: $NAS_HOST"
echo "Press Ctrl+C to exit"
echo ""

# Function to get status
get_status() {
    local status_output
    status_output=$(make status 2>&1 || echo "ERROR: Could not get status")
    echo "$status_output"
}

# Function to get health
get_health() {
    local health_output
    health_output=$(make health 2>&1 || echo "❌ Health check failed")
    echo "$health_output"
}

# Main monitoring loop
while true; do
    clear
    echo "📊 Duplexer Monitor Dashboard - $(date)"
    echo "============================"

    echo ""
    echo "🐳 Container Status:"
    echo "-------------------"
    get_status

    echo ""
    echo "💚 Health Check:"
    echo "----------------"
    get_health

    echo ""
    echo "📁 Inbox Status:"
    echo "---------------"
    ssh "$NAS_HOST" "ls -la $INBOX_PATH 2>/dev/null || echo 'Cannot access inbox'"

    echo ""
    echo "📄 Recent Log Entries:"
    echo "---------------------"
    ssh "$NAS_HOST" "tail -5 $LOGS_PATH/duplexer.log 2>/dev/null || echo 'No logs available'"

    echo ""
    echo "Press Ctrl+C to exit, or wait 30 seconds for refresh..."
    sleep 30
done
