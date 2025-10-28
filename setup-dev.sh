#!/bin/bash
# Quick setup script for development environment

set -euo pipefail

echo "Setting up Duplexer development environment..."

# Create test directories
echo "Creating test directories..."
mkdir -p test-inbox test-outbox test-logs test-backup

# Set permissions
chmod 755 test-*

# Create sample configuration
if [[ ! -f docker/config/duplexer.conf ]]; then
    echo "Creating default configuration..."
    cp docker/config/duplexer.conf docker/config/duplexer.local.conf
    echo "Edit docker/config/duplexer.local.conf for local settings"
fi

# Build development image
echo "Building development Docker image..."
docker build -t duplexer:dev ./docker

echo "Development environment ready!"
echo ""
echo "To start development:"
echo "  docker-compose -f docker-compose.dev.yml up -d"
echo ""
echo "To test with sample files:"
echo "  cp your-odd-pages.pdf test-inbox/"
echo "  cp your-even-pages.pdf test-inbox/"
echo ""
echo "To view logs:"
echo "  docker logs -f duplexer-dev"
echo "  # or"
echo "  tail -f test-logs/duplexer.log"