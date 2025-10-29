#!/bin/bash
# Email utility for Duplexer approval workflow

set -euo pipefail

# Email configuration from environment variables
SMTP_HOST="${SMTP_HOST:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
SMTP_FROM="${SMTP_FROM:-}"
APPROVAL_EMAIL="${APPROVAL_EMAIL:-}"

# Function to check if email is configured
is_email_configured() {
    [[ -n "$SMTP_HOST" && -n "$SMTP_USER" && -n "$SMTP_PASSWORD" && -n "$APPROVAL_EMAIL" ]]
}

# Function to send email with attachment
send_approval_email() {
    local merged_pdf="$1"
    local original_odd="$2"
    local original_even="$3"
    local merge_token="$4"
    local timestamp="$5"

    if ! is_email_configured; then
        echo "Email not configured, skipping email approval"
        return 1
    fi

    local subject="Duplexer: Please review merged document (${timestamp})"
    local external_webhook="${WEBHOOK_EXTERNAL_URL:-https://duplexer.endpoint.servebeer.com}"
    local approve_url="${external_webhook}/approve?token=${merge_token}"
    local reject_url="${external_webhook}/reject?token=${merge_token}"
    local status_url="${external_webhook}/status?token=${merge_token}"

    # Create email body
    local email_body=$(cat << EOF
Duplexer has successfully merged your PDF documents.

Merge Details:
- Timestamp: ${timestamp}
- Original odd pages: $(basename "$original_odd")
- Original even pages: $(basename "$original_even")
- Merged document: $(basename "$merged_pdf")

Please review the attached merged PDF and click one of the links below:

✅ APPROVE: ${approve_url}
❌ REJECT:  ${reject_url}

📊 Check Status: ${status_url}

If approved, the document will be delivered to your paperless system.
If rejected, it will be moved to the rejected folder for review.

This request will expire in 24 hours if no response is received.

Token: ${merge_token}

--
Duplexer Automation System
EOF
)

    # Send email using Python (more reliable than sendmail/msmtp)
    python3 << PYTHON_SCRIPT
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
import os

# Email configuration
smtp_host = "${SMTP_HOST}"
smtp_port = int("${SMTP_PORT}")
smtp_user = "${SMTP_USER}"
smtp_password = "${SMTP_PASSWORD}"
from_email = "${SMTP_FROM}"
to_email = "${APPROVAL_EMAIL}"

# Create message
msg = MIMEMultipart()
msg['From'] = from_email
msg['To'] = to_email
msg['Subject'] = "${subject}"

# Add body
msg.attach(MIMEText("""${email_body}""", 'plain'))

# Add PDF attachment
try:
    with open("${merged_pdf}", "rb") as f:
        attach = MIMEApplication(f.read(), _subtype="pdf")
        attach.add_header('Content-Disposition', 'attachment', filename=os.path.basename("${merged_pdf}"))
        msg.attach(attach)
except Exception as e:
    print(f"Warning: Could not attach PDF: {e}")

# Send email
try:
    context = ssl.create_default_context()

    # Try SMTP with TLS
    if smtp_port == 587:
        server = smtplib.SMTP(smtp_host, smtp_port)
        server.starttls(context=context)
    # Try SMTP with SSL
    elif smtp_port == 465:
        server = smtplib.SMTP_SSL(smtp_host, smtp_port, context=context)
    else:
        server = smtplib.SMTP(smtp_host, smtp_port)

    server.login(smtp_user, smtp_password)
    server.send_message(msg)
    server.quit()
    print("Approval email sent successfully")

except Exception as e:
    print(f"Failed to send email: {e}")
    exit(1)

PYTHON_SCRIPT
}

# Function to send confirmation email
send_confirmation_email() {
    local action="$1"  # "approved" or "rejected"
    local merge_token="$2"
    local merged_pdf="$3"

    if ! is_email_configured; then
        return 0
    fi

    local subject="Duplexer: Merge ${action} (${merge_token})"
    local email_body

    if [[ "$action" == "approved" ]]; then
        email_body="Your document merge has been approved and delivered to paperless.

Document: $(basename "$merged_pdf")
Token: ${merge_token}
Status: ✅ Approved and delivered

The merged PDF is now available in your paperless document management system.

--
Duplexer Automation System"
    else
        email_body="Your document merge has been rejected as requested.

Document: $(basename "$merged_pdf")
Token: ${merge_token}
Status: ❌ Rejected

The merged PDF has been moved to the rejected folder for your review.
You can find it at: /logs/rejected/

--
Duplexer Automation System"
    fi

    # Send confirmation email
    python3 << PYTHON_SCRIPT
import smtplib
import ssl
from email.mime.text import MIMEText

# Email configuration
smtp_host = "${SMTP_HOST}"
smtp_port = int("${SMTP_PORT}")
smtp_user = "${SMTP_USER}"
smtp_password = "${SMTP_PASSWORD}"
from_email = "${SMTP_FROM}"
to_email = "${APPROVAL_EMAIL}"

# Create message
msg = MIMEText("""${email_body}""", 'plain')
msg['From'] = from_email
msg['To'] = to_email
msg['Subject'] = "${subject}"

# Send email
try:
    context = ssl.create_default_context()

    if smtp_port == 587:
        server = smtplib.SMTP(smtp_host, smtp_port)
        server.starttls(context=context)
    elif smtp_port == 465:
        server = smtplib.SMTP_SSL(smtp_host, smtp_port, context=context)
    else:
        server = smtplib.SMTP(smtp_host, smtp_port)

    server.login(smtp_user, smtp_password)
    server.send_message(msg)
    server.quit()
    print("Confirmation email sent")

except Exception as e:
    print(f"Warning: Could not send confirmation email: {e}")

PYTHON_SCRIPT
}

# Export functions for use in other scripts
export -f is_email_configured
export -f send_approval_email
export -f send_confirmation_email