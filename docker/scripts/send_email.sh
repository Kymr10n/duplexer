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

    # Create beautiful HTML email body
    local email_html=$(cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Duplexer - Document Review Required</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            border-bottom: 3px solid #2c3e50;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            color: #2c3e50;
            margin: 0;
            font-size: 28px;
        }
        .header p {
            color: #7f8c8d;
            margin: 10px 0 0 0;
            font-size: 16px;
        }
        .content {
            margin-bottom: 30px;
        }
        .details {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #3498db;
        }
        .details h3 {
            color: #2c3e50;
            margin-top: 0;
            margin-bottom: 15px;
        }
        .details ul {
            margin: 0;
            padding-left: 20px;
        }
        .details li {
            margin-bottom: 8px;
            color: #555;
        }
        .action-buttons {
            text-align: center;
            margin: 40px 0;
        }
        .btn {
            display: inline-block;
            padding: 15px 30px;
            margin: 0 10px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            font-size: 16px;
            transition: all 0.3s ease;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .btn-approve {
            background: linear-gradient(135deg, #27ae60, #2ecc71);
            color: white;
        }
        .btn-approve:hover {
            background: linear-gradient(135deg, #229954, #27ae60);
            transform: translateY(-2px);
            box-shadow: 0 6px 12px rgba(0, 0, 0, 0.2);
        }
        .btn-reject {
            background: linear-gradient(135deg, #e74c3c, #c0392b);
            color: white;
        }
        .btn-reject:hover {
            background: linear-gradient(135deg, #c0392b, #a93226);
            transform: translateY(-2px);
            box-shadow: 0 6px 12px rgba(0, 0, 0, 0.2);
        }
        .btn-status {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            font-size: 14px;
            padding: 10px 20px;
        }
        .btn-status:hover {
            background: linear-gradient(135deg, #2980b9, #1f618d);
            transform: translateY(-1px);
        }
        .footer {
            text-align: center;
            padding-top: 20px;
            border-top: 1px solid #ecf0f1;
            color: #7f8c8d;
            font-size: 14px;
        }
        .token-info {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 5px;
            padding: 15px;
            margin: 20px 0;
            text-align: center;
        }
        .token-info strong {
            color: #856404;
        }
        .warning {
            background: #fdf2e9;
            border-left: 4px solid #e67e22;
            padding: 15px;
            margin: 20px 0;
            border-radius: 0 5px 5px 0;
        }
        .warning p {
            margin: 0;
            color: #d35400;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📄 Document Review Required</h1>
            <p>Duplexer has successfully merged your PDF documents</p>
        </div>

        <div class="content">
            <p>Hello! Your PDF documents have been automatically merged and are ready for review.</p>

            <div class="details">
                <h3>📋 Merge Details</h3>
                <ul>
                    <li><strong>Timestamp:</strong> ${timestamp}</li>
                    <li><strong>Original odd pages:</strong> $(basename "$original_odd")</li>
                    <li><strong>Original even pages:</strong> $(basename "$original_even")</li>
                    <li><strong>Merged document:</strong> $(basename "$merged_pdf")</li>
                </ul>
            </div>

            <p>Please review the attached merged PDF document and choose one of the following actions:</p>

            <div class="action-buttons">
                <a href="${approve_url}" class="btn btn-approve">
                    ✅ APPROVE DOCUMENT
                </a>

                <a href="${reject_url}" class="btn btn-reject">
                    ❌ REJECT DOCUMENT
                </a>
            </div>

            <div style="text-align: center; margin: 20px 0;">
                <a href="${status_url}" class="btn btn-status">
                    📊 Check Status
                </a>
            </div>

            <div class="warning">
                <p><strong>⏰ Important:</strong> If approved, the document will be delivered to your paperless system. If rejected, it will be moved to the rejected folder for review. This request will expire in 24 hours if no response is received.</p>
            </div>

            <div class="token-info">
                <strong>🔑 Reference Token:</strong> ${merge_token}
            </div>
        </div>

        <div class="footer">
            <p>🤖 This is an automated message from the Duplexer Automation System</p>
            <p>📧 Please do not reply to this email</p>
        </div>
    </div>
</body>
</html>
EOF
)

    # Create plain text fallback
    local email_text=$(cat << EOF
📄 DUPLEXER - DOCUMENT REVIEW REQUIRED

Hello! Your PDF documents have been automatically merged and are ready for review.

📋 MERGE DETAILS:
• Timestamp: ${timestamp}
• Original odd pages: $(basename "$original_odd")
• Original even pages: $(basename "$original_even")
• Merged document: $(basename "$merged_pdf")

Please review the attached merged PDF document and click one of the following links:

✅ APPROVE DOCUMENT: ${approve_url}

❌ REJECT DOCUMENT: ${reject_url}

📊 CHECK STATUS: ${status_url}

⏰ IMPORTANT: If approved, the document will be delivered to your paperless system. If rejected, it will be moved to the rejected folder for review. This request will expire in 24 hours if no response is received.

🔑 Reference Token: ${merge_token}

--
🤖 This is an automated message from the Duplexer Automation System
📧 Please do not reply to this email
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

# Add HTML body (most email clients support this)
msg.attach(MIMEText("""${email_html}""", 'html', 'utf-8'))

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