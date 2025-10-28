#!/bin/bash
# Quick test script for VS Code integration

set -euo pipefail

echo "🧪 Duplexer Quick Test Script"
echo "============================="

cd "$(dirname "$0")/../test"

# Function to show progress
show_progress() {
    local step=$1
    local total=$2
    local description=$3
    echo "[$step/$total] $description"
}

# Step 1: Generate test PDFs if they don't exist
show_progress 1 3 "Checking/generating test PDFs..."
if [[ ! -f "pdfs/test_odd_pages.pdf" || ! -f "pdfs/test_even_pages.pdf" ]]; then
    ./create_test_pdfs.sh
else
    echo "✅ Test PDFs already exist"
fi

# Step 2: Run end-to-end test
show_progress 2 3 "Running end-to-end test suite..."
./run_e2e_test.sh

# Step 3: Show results
show_progress 3 3 "Test completed!"

echo ""
echo "📋 Test artifacts created:"
echo "   • Test PDFs: test/pdfs/"
echo "   • Test report: test/test_report_*.txt"
echo ""
