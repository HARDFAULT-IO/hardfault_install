#!/bin/bash

# HARDFAULT.IO - Universal Orchestrator Installer
# Use: curl -fsSL https://hardfault.io/install.sh | bash

set -e

echo "------------------------------------------------"
echo " ██   ██  █████  ██████  ██████  ███████  █████  ██    ██ ██      ████████     ██  ██████  "
echo " ██   ██ ██   ██ ██   ██ ██   ██ ██      ██   ██ ██    ██ ██         ██        ██ ██    ██ "
echo " ███████ ███████ ██████  ██   ██ █████   ███████ ██    ██ ██         ██        ██ ██    ██ "
echo " ██   ██ ██   ██ ██   ██ ██   ██ ██      ██   ██ ██    ██ ██         ██        ██ ██    ██ "
echo " ██   ██ ██   ██ ██   ██ ██████  ██      ██   ██  ██████  ███████    ██    ██  ██  ██████  "
echo " version 0.0.3-universal"
echo "------------------------------------------------"

# 1. Platform Detection
OS_TYPE="$(uname)"
echo "Detected Operating System: $OS_TYPE"

# 2. Dependency + Permissions Checks
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: Docker is not installed.' >&2
  exit 1
fi

# 3. Network Identity (Hostname)
echo "Configuring network identity to 'hardfault' (requires sudo)..."
if [ "$OS_TYPE" == "Darwin" ]; then
    # macOS Way
    sudo scutil --set HostName hardfault.local || true
    sudo scutil --set LocalHostName hardfault || true
    sudo scutil --set ComputerName hardfault || true
else
    # Linux Way
    if [ -x "$(command -v hostnamectl)" ]; then
        sudo hostnamectl set-hostname hardfault || true
    fi
    # Ensure Avahi (mDNS) is installed on Linux
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -q && sudo apt-get install -y avahi-daemon -q || true
    fi
fi

# 4. Workspace Setup
WORKSPACE_DIR="$HOME/hardfault"
mkdir -p "$WORKSPACE_DIR/data"
cd "$WORKSPACE_DIR"

# 5. Create Docker Compose 
# For Mac, we use port mapping. For Linux, we use host mode for better mDNS.
if [ "$OS_TYPE" == "Darwin" ]; then
    NET_CONFIG="ports: [\"80:80\"]"
else
    NET_CONFIG="network_mode: host"
fi

cat <<EOF > docker-compose.yml
services:
  orchestrator:
    image: hardfaultio/hardfault:latest
    container_name: hardfault-orchestrator
    $NET_CONFIG
    restart: unless-stopped
    volumes:
      - ./data:/app/data
    environment:
      - NODE_ENV=production
      - TELEMETRY_PORT=80
EOF

# 6. Deployment
echo "Pulling and starting HARDFAULT..."
docker compose pull
docker compose up -d

# 7. Health Check
echo -n "Waiting for Orchestrator to become healthy..."
for i in {1..10}; do
  if curl -s http://localhost:80 > /dev/null; then
    echo " Done."
    break
  fi
  echo -n "."
  sleep 1
done

# 8. IP Discovery
if [ "$OS_TYPE" == "Darwin" ]; then
    LAN_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo "Unknown")
else
    LAN_IP=$(hostname -I | awk '{print $1}')
fi

echo "------------------------------------------------"
echo "✅ SUCCESS: HARDFAULT.IO is ready."
echo "------------------------------------------------"
echo "Local Dashboard:   http://hardfault.local"
echo "Network Access:    http://$LAN_IP"

if command -v tailscale >/dev/null; then
  echo "Tailscale Access:  http://hardfault"
fi
echo "------------------------------------------------"