#!/usr/bin/env python3
"""
Simple web service for Kubernetes deployment strategy demonstrations.
Provides version-specific responses and logs all requests to stdout.
"""

import os
import sys
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

# Get version from environment variable
SERVICE_VERSION = os.getenv('SERVICE_VERSION', 'unknown')
SERVICE_NAME = os.getenv('SERVICE_NAME', 'web-service')
PORT = int(os.getenv('PORT', 5000))


def log_request(message):
    """Log request to stdout with timestamp."""
    timestamp = datetime.utcnow().isoformat()
    print(f"[{timestamp}] {message}", file=sys.stdout, flush=True)


@app.before_request
def log_incoming_request():
    """Log incoming request details."""
    client_ip = request.remote_addr
    method = request.method
    path = request.path
    user_agent = request.headers.get('User-Agent', 'unknown')
    log_request(f"Incoming request: {method} {path} from {client_ip} - User-Agent: {user_agent}")


@app.route('/', methods=['GET'])
def index():
    """Root endpoint returning service info."""
    response = {
        'service': SERVICE_NAME,
        'version': SERVICE_VERSION,
        'timestamp': datetime.utcnow().isoformat(),
        'message': f'{SERVICE_NAME} v{SERVICE_VERSION} is running'
    }
    log_request(f"Responded to GET / with version {SERVICE_VERSION}")
    return jsonify(response), 200


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    response = {
        'status': 'healthy',
        'service': SERVICE_NAME,
        'version': SERVICE_VERSION
    }
    return jsonify(response), 200


@app.route('/version', methods=['GET'])
def version():
    """Version endpoint."""
    response = {
        'version': SERVICE_VERSION,
        'service': SERVICE_NAME
    }
    log_request(f"Version check: {SERVICE_VERSION}")
    return jsonify(response), 200


@app.route('/api/info', methods=['GET'])
def info():
    """Detailed service info endpoint."""
    response = {
        'service': SERVICE_NAME,
        'version': SERVICE_VERSION,
        'uptime_info': 'Container started',
        'timestamp': datetime.utcnow().isoformat()
    }
    return jsonify(response), 200


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    log_request(f"404 Not Found: {request.path}")
    return jsonify({'error': 'Not found', 'path': request.path}), 404


@app.errorhandler(500)
def server_error(error):
    """Handle 500 errors."""
    log_request(f"500 Server Error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    log_request(f"Starting {SERVICE_NAME} v{SERVICE_VERSION} on port {PORT}")
    app.run(host='0.0.0.0', port=PORT, debug=False)
