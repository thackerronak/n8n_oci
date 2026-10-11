#!/bin/bash
set -euo pipefail

# Pinned n8n release. Bump deliberately after checking
# https://github.com/n8n-io/n8n/security/advisories and the release notes.
N8N_VERSION="2.42.6"
N8N_TIMEZONE="Asia/Kolkata"

# Ensure all files are created in the user's home directory
cd "${HOME:-/root}"

# Install Docker Engine and the Docker Compose plugin from Docker's apt repo
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Create Docker Compose file. No credentials here: n8n 1.0+ has built-in user
# management (Basic Auth was removed), so the owner account is created on
# first visit to /setup.
# N8N_SECURE_COOKIE=false is only needed while n8n is served over plain HTTP.
# Remove it once HTTPS is enabled (see docs/nginx-ssl.md).
cat <<EOF | sudo tee docker-compose.yml > /dev/null
name: n8n
services:
  n8n:
    image: n8nio/n8n:${N8N_VERSION}
    restart: unless-stopped
    container_name: n8n
    ports:
      - "5678:5678"
    environment:
      - GENERIC_TIMEZONE=${N8N_TIMEZONE}
      - TZ=${N8N_TIMEZONE}
      - N8N_SECURE_COOKIE=false
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_DIAGNOSTICS_ENABLED=false
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

# Prepare volume and start container
mkdir -p n8n_data
sudo chown -R 1000:1000 n8n_data
sudo docker compose up -d
