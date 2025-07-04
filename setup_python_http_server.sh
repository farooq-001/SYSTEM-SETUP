#!/bin/bash

# ==============================
# Simple Python HTTP Server Setup Script
# ==============================

SERVICE_NAME="python-http"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
HTTP_PORT=8080
WORK_DIR="$HOME"

echo "==> Creating systemd service for Python HTTP server on port ${HTTP_PORT}..."

# Create systemd service file
sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=Simple Python HTTP Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=${WORK_DIR}
ExecStart=/usr/bin/python3 -m http.server ${HTTP_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
echo "==> Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "==> Enabling and starting ${SERVICE_NAME}.service..."
sudo systemctl enable ${SERVICE_NAME}.service
sudo systemctl start ${SERVICE_NAME}.service

echo "==> Checking service status..."
sudo systemctl status ${SERVICE_NAME}.service --no-pager

echo "==> Done! Access your server at: http://<server-ip>:${HTTP_PORT}/"
