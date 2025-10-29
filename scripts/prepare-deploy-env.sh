#!/bin/bash

# Deployment helper script for Duplexer
# Handles special character encoding for Docker Compose environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment variables
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Error: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Create a deployment environment file with encoded values
DEPLOY_ENV="$PROJECT_ROOT/deploy/.env"

echo "# Auto-generated deployment environment file" > "$DEPLOY_ENV"
echo "# Generated on $(date)" >> "$DEPLOY_ENV"
echo "" >> "$DEPLOY_ENV"

# Copy all variables from main .env except SMTP_PASSWORD
grep -v "^SMTP_PASSWORD=" "$PROJECT_ROOT/.env" | grep -v "^#" | grep -v "^$" >> "$DEPLOY_ENV"

# Always encode SMTP_PASSWORD to base64 for safe Docker environment handling
echo "# SMTP_PASSWORD encoded to base64 for Docker environment compatibility" >> "$DEPLOY_ENV"
# Strip quotes from password before encoding
SMTP_PASSWORD_CLEAN=$(echo "$SMTP_PASSWORD" | sed 's/^"//;s/"$//')
SMTP_PASSWORD_B64=$(echo -n "$SMTP_PASSWORD_CLEAN" | base64)
echo "SMTP_PASSWORD=$SMTP_PASSWORD_B64" >> "$DEPLOY_ENV"

echo ""
echo "✅ Generated deployment environment file: $DEPLOY_ENV"
echo "� SMTP_PASSWORD encoded to base64 for safe Docker handling"