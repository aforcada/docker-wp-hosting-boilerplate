#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./init.sh)"
  exit 1
fi

echo "🚀 Starting server configuration..."

# 1. Create Docker Networks
echo "🌐 Creating Docker networks..."
docker network create web-net 2>/dev/null || true
docker network create db-net 2>/dev/null || true

# 2. Prepare Traefik permissions (acme.json)
echo "🔒 Configuring Traefik permissions..."
touch traefik/acme.json
chmod 600 traefik/acme.json

# 3. Copy .env if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Copying .env.example to .env..."
    cp .env.example .env
    echo "⚠️  REMEMBER TO EDIT .env WITH REAL PASSWORDS!"
fi

# 4. Prepare SFTP configuration
if [ ! -f sftp/users.conf ]; then
    echo "📝 Creating empty sftp/users.conf..."
    touch sftp/users.conf
fi

# 5. Fix 'sites' directory permissions for SFTP
echo "🔧 Setting permissions for 'sites/' directory (required for SFTP chroot)..."
chown root:root sites
chmod 755 sites

echo "🎉 Server ready! Now edit .env and run 'docker compose up -d'"
