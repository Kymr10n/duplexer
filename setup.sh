#!/bin/bash
# Setup script for Duplexer project

set -euo pipefail

echo "🚀 Duplexer Project Setup"
echo "=========================="

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    echo "📝 Creating .env configuration file..."

    # Copy template
    cp .env.template .env

    echo ""
    echo "⚠️  IMPORTANT: Please edit .env file with your NAS configuration!"
    echo ""
    echo "Required settings to customize:"
    echo "  • NAS_HOST=your_username@your_nas_hostname"
    echo "  • DOCKER_CONTEXT=your_docker_context_name"
    echo "  • Paths (if different from defaults)"
    echo ""
    echo "Example:"
    echo "  NAS_HOST=admin@mynas.local"
    echo "  DOCKER_CONTEXT=mynas"
    echo ""

    # Prompt user to edit
    read -p "Would you like to edit .env file now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    fi

else
    echo "✅ .env file already exists"
fi

# Load the environment
if [[ -f ".env" ]]; then
    source .env
    echo "✅ Loaded configuration from .env"
fi

echo ""
echo "🔍 Checking prerequisites..."

# Check Docker
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker found"
else
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check Docker context
if [[ -n "${DOCKER_CONTEXT:-}" ]]; then
    if docker context ls | grep -q "$DOCKER_CONTEXT"; then
        echo "✅ Docker context '$DOCKER_CONTEXT' found"
    else
        echo "⚠️  Docker context '$DOCKER_CONTEXT' not found"
        echo "   Please create it with: docker context create $DOCKER_CONTEXT --docker host=ssh://${NAS_HOST:-user@nas}"
    fi
fi

# Check SSH connectivity
if [[ -n "${NAS_HOST:-}" ]]; then
    echo "🔌 Testing SSH connection to ${NAS_HOST}..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$NAS_HOST" "echo 'SSH OK'" 2>/dev/null; then
        echo "✅ SSH connection successful"
    else
        echo "⚠️  SSH connection failed. Please check:"
        echo "   • SSH key authentication is set up"
        echo "   • NAS_HOST is correct: $NAS_HOST"
        echo "   • Network connectivity"
    fi
fi

# Check make
if command -v make >/dev/null 2>&1; then
    echo "✅ Make found"
else
    echo "❌ Make not found. Please install build-essential or similar."
fi

# Check if NAS directories exist
if [[ -n "${NAS_HOST:-}" && -n "${NAS_DUPLEXER_PATH:-}" ]]; then
    echo "📁 Checking NAS directories..."
    if ssh "$NAS_HOST" "test -d '$NAS_DUPLEXER_PATH'" 2>/dev/null; then
        echo "✅ Duplexer directory exists: $NAS_DUPLEXER_PATH"
    else
        echo "⚠️  Duplexer directory not found: $NAS_DUPLEXER_PATH"
        echo "   Creating directory structure..."
        ssh "$NAS_HOST" "mkdir -p $NAS_DUPLEXER_PATH/{inbox,logs,backup}" 2>/dev/null || echo "   Failed to create directories"
    fi
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Review and customize .env file if needed"
echo "2. Test deployment: make build-remote && make up"
echo "3. Run tests: cd test && ./run_e2e_test.sh"
echo "4. Use VS Code tasks for easy management"
echo ""
echo "📖 See VSCODE_REFERENCE.md for VS Code integration details"
echo ""
echo "🎉 Setup complete! You're ready to use Duplexer."
