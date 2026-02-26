#!/bin/bash

# HARDFAULT.IO - Professional Orchestrator Installer
# Use: curl -fsSL https://hardfault.io/install.sh | bash

set -e

# --- Visuals ---

echo " ██   ██  █████  ██████  ██████  ███████  █████  ██    ██ ██      ████████     ██  ██████  "
echo " ██   ██ ██   ██ ██   ██ ██   ██ ██      ██   ██ ██    ██ ██         ██        ██ ██    ██ "
echo " ███████ ███████ ██████  ██   ██ █████   ███████ ██    ██ ██         ██        ██ ██    ██ "
echo " ██   ██ ██   ██ ██   ██ ██   ██ ██      ██   ██ ██    ██ ██         ██        ██ ██    ██ "
echo " ██   ██ ██   ██ ██   ██ ██████  ██      ██   ██  ██████  ███████    ██    ██  ██  ██████  "
echo " version 0.0.1-test"
echo "------------------------------------------------"
echo "Initializing HARDFAULT.IO Environment..."

# 1. Dependency Check
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: Docker is not installed. Please install Docker to run the Orchestrator: https://docs.docker.com/get-docker/' >&2
  exit 1
fi

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
      - TELEMETRY_PORT=8080
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
  if curl -s http://localhost:8080 > /dev/null; then
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
echo "------------------------------------------------"
echo "✅ SUCCESS: HARDFAULT.IO is ready."
echo "------------------------------------------------"
echo "Dashboard:  http://localhost:8080"
echo "Workspace:  $WORKSPACE_DIR"
echo "Telemetry:  $WORKSPACE_DIR/data"
echo ""
echo "Note: The orchestrator will start automatically on boot."
echo "To stop it manually, run: cd $WORKSPACE_DIR && docker compose stop"
echo "------------------------------------------------"