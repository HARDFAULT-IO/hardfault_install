#!/bin/bash

# HARDFAULT.IO - Professional Orchestrator Installer
# Use: curl -fsSL https://hardfault.io/install.sh | bash

set -e

# --- Visuals ---
echo "------------------------------------------------"
echo " ██   ██  █████  ██████  ██████  ███████  █████  ██    ██ ██      ████████     ██  ██████  "
echo " ██   ██ ██   ██ ██   ██ ██   ██ ██      ██   ██ ██    ██ ██         ██        ██ ██    ██ "
echo " ███████ ███████ ██████  ██   ██ █████   ███████ ██    ██ ██         ██        ██ ██    ██ "
echo " ██   ██ ██   ██ ██   ██ ██   ██ ██      ██   ██ ██    ██ ██         ██        ██ ██    ██ "
echo " ██   ██ ██   ██ ██   ██ ██████  ██      ██   ██  ██████  ███████    ██    ██  ██  ██████  "
echo " version 0.0.2-test"
echo "------------------------------------------------"
echo "Initializing HARDFAULT.IO Environment..."

# 1. Dependency + Permissions Checks
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: Docker is not installed. Please install Docker to run the Orchestrator: https://docs.docker.com/get-docker/' >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: Cannot connect to Docker. You might need to run this with 'sudo' or add your user to the docker group." >&2
  exit 1
fi

# Set network settings for mDNS, set the hostname to http://hardfault.local
echo "Setting network identity to 'hardfault'..."
sudo hostnamectl set-hostname hardfault || true
# Ensure mDNS is running (Standard on Ubuntu/Jetson)
sudo apt-get update -q && sudo apt-get install -y avahi-daemon -q

# 2. Workspace Setup
# We use a consistent home for data to ensure persistence through updates
WORKSPACE_DIR="$HOME/hardfault"
mkdir -p "$WORKSPACE_DIR/data"
cd "$WORKSPACE_DIR"

# 3. Create the Production Docker Compose
# - unless-stopped: Resilient through reboots but respects manual 'docker compose stop'
# - network_mode host: Required for reliable mDNS discovery with Clipper Monolith (ESP32-S3)
# - volumes: Maps local ./data to container /app/data for persistent telemetry
cat <<EOF > docker-compose.yml
services:
  orchestrator:
    image: hardfaultio/hardfault:latest
    container_name: hardfault-orchestrator
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./data:/app/data
    environment:
      - NODE_ENV=production
      - TELEMETRY_PORT=80
EOF

# 4. Deployment
echo "Pulling latest HARDFAULT images..."
docker compose pull

echo "Starting services..."
docker compose up -d

# 5. Health Check
# Waits for the Flask/API server to actually start responding
echo -n "Waiting for Orchestrator to become healthy..."
for i in {1..10}; do
  if curl -s http://localhost:80 > /dev/null; then
    echo " Done."
    break
  fi
  echo -n "."
  sleep 1
  if [ $i -eq 10 ]; then
    echo -e "\nNote: Orchestrator is taking longer than expected to start. Check 'docker logs hardfault-orchestrator'."
  fi
done

# 6. Success Message
# Automated IP Discovery
LAN_IP=$(hostname -I | awk '{print $1}')
echo "------------------------------------------------"
echo "✅ SUCCESS: HARDFAULT.IO is ready."
echo "------------------------------------------------"
echo "Local Dashboard:   http://hardfault.local"
echo "Network Access:    http://$LAN_IP"

# Check for Tailscale/VPN
if command -v tailscale >/dev/null; then
  echo "Tailscale Access:  http://hardfault"
fi

echo "Workspace:         $WORKSPACE_DIR"
echo "Telemetry:         $WORKSPACE_DIR/data"
echo ""
echo "Note: The orchestrator will start automatically on boot."
echo "To stop it manually, run: cd $WORKSPACE_DIR && docker compose stop"
echo "------------------------------------------------"