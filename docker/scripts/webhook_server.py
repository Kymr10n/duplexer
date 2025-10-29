#!/usr/bin/env python3
"""
Simple webhook server for Duplexer email approval workflow
Handles approval/rejection requests and provides status responses
"""

import os
import sys
import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import logging

# Configuration
WEBHOOK_PORT = int(os.environ.get('WEBHOOK_PORT', '8083'))
PENDING_DIR = '/logs/pending'
LOGFILE = os.environ.get('LOGFILE', '/logs/duplexer.log')

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] [webhook] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Also log to duplexer log file
file_handler = logging.FileHandler(LOGFILE)
file_handler.setFormatter(logging.Formatter('[%(asctime)s] [%(levelname)s] [webhook] %(message)s', '%Y-%m-%d %H:%M:%S'))
logging.getLogger().addHandler(file_handler)

class WebhookHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Override to use our logger
        logging.info(format % args)

    def do_GET(self):
        """Handle GET requests for approval/rejection"""
        try:
            parsed_url = urlparse(self.path)
            query_params = parse_qs(parsed_url.query)

            if parsed_url.path == '/approve':
                self.handle_approval(query_params, 'approved')
            elif parsed_url.path == '/reject':
                self.handle_approval(query_params, 'rejected')
            elif parsed_url.path == '/status':
                self.handle_status(query_params)
            elif parsed_url.path == '/health':
                self.handle_health()
            else:
                self.send_error(404, "Endpoint not found")

        except Exception as e:
            logging.error(f"Error handling request: {e}")
            self.send_error(500, f"Internal server error: {e}")

    def do_POST(self):
        """Handle POST requests (for email webhooks)"""
        try:
            if self.path == '/email-webhook':
                self.handle_email_webhook()
            else:
                self.send_error(404, "Endpoint not found")
        except Exception as e:
            logging.error(f"Error handling POST request: {e}")
            self.send_error(500, f"Internal server error: {e}")

    def handle_approval(self, query_params, action):
        """Handle approval/rejection via GET parameters"""
        if 'token' not in query_params:
            self.send_error(400, "Missing token parameter")
            return

        token = query_params['token'][0]
        logging.info(f"Received {action} request for token: {token}")

        # Create approval/rejection file
        if action == 'approved':
            approval_file = f"{PENDING_DIR}/APPROVE_{token}"
        else:
            approval_file = f"{PENDING_DIR}/REJECT_{token}"

        try:
            os.makedirs(PENDING_DIR, exist_ok=True)
            with open(approval_file, 'w') as f:
                f.write(f"{action} at {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

            logging.info(f"Created {action} file: {approval_file}")

            # Send success response
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()

            response_html = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Duplexer - {action.title()}</title>
                <style>
                    body {{ font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }}
                    .success {{ color: #28a745; }}
                    .rejected {{ color: #dc3545; }}
                </style>
            </head>
            <body>
                <h1 class="{'success' if action == 'approved' else 'rejected'}">
                    Document {action.title()}!
                </h1>
                <p>Token: {token}</p>
                <p>Your document merge has been {action}.</p>
                {'<p>The document will be delivered to paperless shortly.</p>' if action == 'approved' else '<p>The document has been moved to the rejected folder.</p>'}
            </body>
            </html>
            """
            self.wfile.write(response_html.encode())

        except Exception as e:
            logging.error(f"Failed to create {action} file: {e}")
            self.send_error(500, f"Failed to process {action}")

    def handle_status(self, query_params):
        """Handle status requests"""
        if 'token' not in query_params:
            self.send_error(400, "Missing token parameter")
            return

        token = query_params['token'][0]
        pending_file = f"{PENDING_DIR}/{token}.pending"
        approve_file = f"{PENDING_DIR}/APPROVE_{token}"
        reject_file = f"{PENDING_DIR}/REJECT_{token}"

        status = "unknown"
        if os.path.exists(approve_file):
            status = "approved"
        elif os.path.exists(reject_file):
            status = "rejected"
        elif os.path.exists(pending_file):
            status = "pending"

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

        response = {
            "token": token,
            "status": status,
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S')
        }
        self.wfile.write(json.dumps(response).encode())

    def handle_health(self):
        """Health check endpoint"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

        response = {
            "status": "healthy",
            "service": "duplexer-webhook",
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S')
        }
        self.wfile.write(json.dumps(response).encode())

    def handle_email_webhook(self):
        """Handle incoming email webhook (future enhancement)"""
        # This could be used to process email replies automatically
        # For now, just acknowledge receipt
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()

        response = {"status": "received"}
        self.wfile.write(json.dumps(response).encode())

def main():
    """Start the webhook server"""
    logging.info(f"Starting Duplexer webhook server on port {WEBHOOK_PORT}")

    # Ensure pending directory exists
    os.makedirs(PENDING_DIR, exist_ok=True)

    server = HTTPServer(('0.0.0.0', WEBHOOK_PORT), WebhookHandler)

    try:
        logging.info(f"Webhook server listening on 0.0.0.0:{WEBHOOK_PORT}")
        logging.info("Available endpoints:")
        logging.info("  GET  /approve?token=TOKEN")
        logging.info("  GET  /reject?token=TOKEN")
        logging.info("  GET  /status?token=TOKEN")
        logging.info("  GET  /health")
        logging.info("  POST /email-webhook")

        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("Webhook server shutting down...")
        server.shutdown()
    except Exception as e:
        logging.error(f"Webhook server error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()