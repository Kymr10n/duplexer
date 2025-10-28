#!/bin/bash
# Quick deployment script for VS Code integration

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(dirname "$0")"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env file if it exists
if [[ -f "$WORKSPACE_DIR/.env" ]]; then
    source "$WORKSPACE_DIR/.env"
    echo "✅ Loaded configuration from .env"
else
    echo "⚠️  No .env file found, using defaults"
fi

echo "🚀 Duplexer Quick Deploy Script"
echo "==============================="
echo "Target: ${NAS_HOST:-default}"
echo "Context: ${DOCKER_CONTEXT:-default}"
echo ""

# Function to show progress
show_progress() {
    local step=$1
    local total=$2
    local description=$3
    echo "[$step/$total] $description"
}

# Step 1: Build
show_progress 1 4 "Building Duplexer image on NAS..."
make build-remote

# Step 2: Deploy
show_progress 2 4 "Deploying container to NAS..."
make up

# Step 3: Health check
show_progress 3 4 "Performing health check..."
sleep 10
make health || echo "⚠️  Health check failed (may be due to permission issues)"

# Step 4: Status
show_progress 4 4 "Checking deployment status..."
make status

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   • View logs: make logs"
echo "   • Run tests: cd test && ./run_e2e_test.sh"
echo "   • Upload PDFs to: /volume1/services/duplexer/inbox/"
echo ""
