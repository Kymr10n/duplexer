#!/bin/bash
# Prerequisites checker for Duplexer
# Validates development environment and remote NAS setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
SCRIPT_DIR="$(dirname "$0")"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$WORKSPACE_DIR/.env" ]]; then
    source "$WORKSPACE_DIR/.env"
fi

# Configuration
REMOTE_HOST="${NAS_HOST:-username@your-nas-hostname}"
DOCKER_CTX="${DOCKER_CONTEXT:-your-nas-context}"

# Counters
LOCAL_PASSED=0
LOCAL_TOTAL=0
REMOTE_PASSED=0
REMOTE_TOTAL=0

# Helper functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_section() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
}

check_local() {
    local cmd="$1"
    local description="$2"
    local required="${3:-true}"

    LOCAL_TOTAL=$((LOCAL_TOTAL + 1))

    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}$description${NC}"
        LOCAL_PASSED=$((LOCAL_PASSED + 1))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            echo -e "❌ ${RED}$description${NC}"
        else
            echo -e "⚠️  ${YELLOW}$description (optional)${NC}"
            LOCAL_PASSED=$((LOCAL_PASSED + 1))
        fi
        return 1
    fi
}

check_file() {
    local file="$1"
    local description="$2"

    LOCAL_TOTAL=$((LOCAL_TOTAL + 1))

    if [[ -f "$file" ]]; then
        echo -e "✅ ${GREEN}$description${NC}"
        LOCAL_PASSED=$((LOCAL_PASSED + 1))
        return 0
    else
        echo -e "❌ ${RED}$description${NC}"
        return 1
    fi
}

check_remote() {
    local cmd="$1"
    local description="$2"
    local required="${3:-true}"

    REMOTE_TOTAL=$((REMOTE_TOTAL + 1))

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "command -v $cmd" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}$description${NC}"
        REMOTE_PASSED=$((REMOTE_PASSED + 1))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            echo -e "❌ ${RED}$description${NC}"
        else
            echo -e "⚠️  ${YELLOW}$description (optional)${NC}"
            REMOTE_PASSED=$((REMOTE_PASSED + 1))
        fi
        return 1
    fi
}

check_remote_path() {
    local path="$1"
    local description="$2"

    REMOTE_TOTAL=$((REMOTE_TOTAL + 1))

    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "test -d '$path'" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}$description${NC}"
        REMOTE_PASSED=$((REMOTE_PASSED + 1))
        return 0
    else
        echo -e "❌ ${RED}$description${NC}"
        return 1
    fi
}

# Main execution
print_header "DUPLEXER PREREQUISITES CHECKER"

echo "Checking development environment and deployment targets..."
echo "Remote host: $REMOTE_HOST"
echo "Docker context: $DOCKER_CTX"
echo ""

# ===========================================
# LOCAL ENVIRONMENT CHECKS
# ===========================================

print_section "Local Development Environment"

echo "Core Development Tools:"
check_local "git" "Git version control"
check_local "make" "Make build system"
check_local "bash" "Bash shell"
check_local "ssh" "SSH client"

echo ""
echo "Docker & Container Tools:"
check_local "docker" "Docker CLI"

# Check Docker context
LOCAL_TOTAL=$((LOCAL_TOTAL + 1))
if docker context ls 2>/dev/null | grep -q "$DOCKER_CTX"; then
    echo -e "✅ ${GREEN}Docker context '$DOCKER_CTX' exists${NC}"
    LOCAL_PASSED=$((LOCAL_PASSED + 1))
else
    echo -e "❌ ${RED}Docker context '$DOCKER_CTX' not found${NC}"
fi

echo ""
echo "PDF Processing Tools (for testing):"
check_local "ps2pdf" "Ghostscript (ps2pdf)" false
check_local "pdflatex" "LaTeX (pdflatex)" false

echo ""
echo "Project Files:"
check_file "$WORKSPACE_DIR/.env" "Environment configuration (.env)"
check_file "$WORKSPACE_DIR/Makefile" "Makefile"
check_file "$WORKSPACE_DIR/docker/Dockerfile" "Dockerfile"

# ===========================================
# SSH CONNECTIVITY
# ===========================================

print_section "SSH Connectivity"

LOCAL_TOTAL=$((LOCAL_TOTAL + 1))
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_HOST" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}SSH connection to $REMOTE_HOST${NC}"
    LOCAL_PASSED=$((LOCAL_PASSED + 1))
    SSH_WORKS=true
else
    echo -e "❌ ${RED}SSH connection to $REMOTE_HOST${NC}"
    SSH_WORKS=false
fi

if [[ "$SSH_WORKS" == "false" ]]; then
    echo -e "${YELLOW}Skipping remote checks due to SSH connectivity issues${NC}"
else
    # ===========================================
    # REMOTE NAS CHECKS
    # ===========================================

    print_section "Remote NAS Environment"

    echo "Core System Tools:"
    check_remote "docker" "Docker on NAS"
    check_remote "bash" "Bash shell on NAS"

    echo ""
    echo "System Utilities:"
    check_remote "inotifywait" "inotify-tools for file watching" false

    echo ""
    echo "Required Directories:"
    check_remote_path "${INBOX_PATH:-/volume1/services/duplexer/inbox}" "Inbox directory"
    check_remote_path "${CONSUME_PATH:-/volume1/services/paperless/consume}" "Paperless consume directory"
    check_remote_path "${LOGS_PATH:-/volume1/services/duplexer/logs}" "Logs directory"

    echo ""
    echo "Docker Container Tools (if container is running):"
    REMOTE_TOTAL=$((REMOTE_TOTAL + 1))
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "docker exec duplexer pdftk --version" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}pdftk available in container${NC}"
        REMOTE_PASSED=$((REMOTE_PASSED + 1))
    else
        echo -e "ℹ️  ${YELLOW}pdftk check skipped (container not running or not accessible)${NC}"
        REMOTE_PASSED=$((REMOTE_PASSED + 1))
    fi

    REMOTE_TOTAL=$((REMOTE_TOTAL + 1))
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "docker exec duplexer qpdf --version" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}qpdf available in container${NC}"
        REMOTE_PASSED=$((REMOTE_PASSED + 1))
    else
        echo -e "ℹ️  ${YELLOW}qpdf check skipped (container not running or not accessible)${NC}"
        REMOTE_PASSED=$((REMOTE_PASSED + 1))
    fi

    echo ""
    echo "Note: PDF processing tools should ONLY be in the Docker container, never installed on the host system."
fi

# ===========================================
# SUMMARY
# ===========================================

print_section "Summary"

echo -e "Local Environment: ${LOCAL_PASSED}/${LOCAL_TOTAL} checks passed"
if [[ "$SSH_WORKS" == "true" ]]; then
    echo -e "Remote Environment: ${REMOTE_PASSED}/${REMOTE_TOTAL} checks passed"
    TOTAL_PASSED=$((LOCAL_PASSED + REMOTE_PASSED))
    TOTAL_CHECKS=$((LOCAL_TOTAL + REMOTE_TOTAL))
else
    TOTAL_PASSED=$LOCAL_PASSED
    TOTAL_CHECKS=$LOCAL_TOTAL
fi

echo ""
if [[ $TOTAL_PASSED -eq $TOTAL_CHECKS ]]; then
    echo -e "🎉 ${GREEN}All checks passed! Environment is ready.${NC}"
    exit 0
else
    echo -e "⚠️  ${YELLOW}$((TOTAL_CHECKS - TOTAL_PASSED)) check(s) failed.${NC}"
    echo -e "${YELLOW}Please review the failed checks above and install missing tools.${NC}"
    exit 1
fi