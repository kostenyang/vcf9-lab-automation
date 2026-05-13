#!/bin/bash
# setup-mcp-ubuntu.sh
# Install and start the VCF Lab MCP Server on Ubuntu 10.0.0.65
# Run as root:  bash setup-mcp-ubuntu.sh

set -e

INSTALL_DIR="/opt/vcf-mcp"
SERVICE_NAME="vcf-mcp"
SERVER_FILE="vcf-lab-mcp-server.py"
PORT=7000

echo "=== VCF Lab MCP Server Setup ==="

# ── Install system packages ───────────────────────────────────────────────────
apt-get update -q
apt-get install -y python3 python3-pip python3-venv dnsutils iputils-ping openssh-client

# ── Create install dir and virtualenv ─────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

# ── Install Python packages ───────────────────────────────────────────────────
pip install --upgrade pip -q
pip install "mcp[cli]" paramiko requests -q

echo "Python packages installed."

# ── Copy server file ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/$SERVER_FILE" ]; then
    cp "$SCRIPT_DIR/$SERVER_FILE" "$INSTALL_DIR/"
    echo "Copied $SERVER_FILE to $INSTALL_DIR/"
else
    echo "ERROR: $SERVER_FILE not found next to this script ($SCRIPT_DIR)."
    echo "Copy vcf-lab-mcp-server.py to $INSTALL_DIR/ manually, then run:"
    echo "  systemctl start $SERVICE_NAME"
    exit 1
fi

deactivate

# ── Create systemd service ────────────────────────────────────────────────────
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=VCF Lab MCP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python3 ${INSTALL_DIR}/${SERVER_FILE}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo ""
echo "=== Setup Complete ==="
echo "Service status:"
systemctl status "$SERVICE_NAME" --no-pager -l | head -20
echo ""
echo "MCP Server URL: http://10.0.0.65:${PORT}/sse"
echo ""
echo "Test with:"
echo "  curl -N http://10.0.0.65:${PORT}/sse"
echo ""
echo "Logs:"
echo "  journalctl -u $SERVICE_NAME -f"
