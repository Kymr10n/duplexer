#!/bin/bash
# Environment validation script

set -euo pipefail

echo "🔍 Duplexer Environment Validation"
echo "=================================="

# Load environment
if [[ -f ".env" ]]; then
    source .env
    echo "✅ Loaded .env file"
else
    echo "❌ No .env file found. Run ./setup.sh first."
    exit 1
fi

echo ""
echo "📋 Current Configuration:"
echo "------------------------"
echo "NAS_HOST: ${NAS_HOST:-not set}"
echo "DOCKER_CONTEXT: ${DOCKER_CONTEXT:-not set}"
echo "INBOX_PATH: ${INBOX_PATH:-not set}"
echo "CONSUME_PATH: ${CONSUME_PATH:-not set}"
echo "LOGS_PATH: ${LOGS_PATH:-not set}"

echo ""
echo "🧪 Testing Configuration:"
echo "-------------------------"

# Test SSH connection
if [[ -n "${NAS_HOST:-}" ]]; then
    echo -n "SSH connection to $NAS_HOST: "
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$NAS_HOST" "echo 'OK'" 2>/dev/null; then
        echo "✅ Success"
    else
        echo "❌ Failed"
    fi
else
    echo "⚠️  NAS_HOST not configured"
fi

# Test Docker context
if [[ -n "${DOCKER_CONTEXT:-}" ]]; then
    echo -n "Docker context '$DOCKER_CONTEXT': "
    if docker --context "$DOCKER_CONTEXT" info >/dev/null 2>&1; then
        echo "✅ Available"
    else
        echo "❌ Not available"
    fi
else
    echo "⚠️  DOCKER_CONTEXT not configured"
fi

# Test NAS directories
if [[ -n "${NAS_HOST:-}" && -n "${INBOX_PATH:-}" ]]; then
    echo -n "Inbox directory ($INBOX_PATH): "
    if ssh "$NAS_HOST" "test -d '$INBOX_PATH'" 2>/dev/null; then
        echo "✅ Exists"
    else
        echo "❌ Not found"
    fi

    echo -n "Consume directory ($CONSUME_PATH): "
    if ssh "$NAS_HOST" "test -d '$CONSUME_PATH'" 2>/dev/null; then
        echo "✅ Exists"
    else
        echo "❌ Not found"
    fi

    echo -n "Logs directory ($LOGS_PATH): "
    if ssh "$NAS_HOST" "test -d '$LOGS_PATH'" 2>/dev/null; then
        echo "✅ Exists"
    else
        echo "❌ Not found"
    fi
fi

echo ""
echo "🚀 Ready to deploy? Run: make build-remote && make up"
