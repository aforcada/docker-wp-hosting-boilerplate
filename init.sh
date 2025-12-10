#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./init.sh)"
  exit 1
fi

echo "🚀 Starting server configuration..."

# 1. Create Traefik acme.json file and set permissions
echo "🔒 Configuring Traefik permissions..."
if [ ! -f traefik/acme.json ]; then
    touch traefik/acme.json
fi
chmod 600 traefik/acme.json

# 2b. Create Traefik dynamic config directories
if [ ! -d traefik/dynamic ]; then
    echo "📂 Creating traefik/dynamic directory..."
    mkdir -p traefik/dynamic
    cp _template_/traefik/dynamic/certs.yml traefik/dynamic/certs.yml
fi
if [ ! -d traefik/certs ]; then
    echo "📂 Creating traefik/certs directory..."
    mkdir -p traefik/certs
fi

# 3. Copy .env if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Copying _template_/.env.example to .env..."
    cp _template_/.env.example .env

    # Generate secure random password for Database Root
    ROOT_PASS=$(openssl rand -base64 24)
    sed -i "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=$ROOT_PASS|" .env

    echo "✅ Generated secure MYSQL_ROOT_PASSWORD in .env"
    echo "🔑 Root Password: $ROOT_PASS"
    echo "⚠️  REMEMBER TO EDIT .env WITH YOUR EMAIL!"
fi

# 4. Prepare SFTP configuration
if [ ! -f sftp/users.conf ]; then
    echo "📝 Creating empty sftp/users.conf..."
    touch sftp/users.conf
    echo "⚠️  NOTE: SFTP service will restart/fail until you create the first site."
fi

# 5. Fix 'sites' directory permissions for SFTP
echo "🔧 Setting permissions for 'sites/' directory (required for SFTP chroot)..."
chown root:root sites
chmod 755 sites

echo "🎉 Server ready! Now edit .env and run 'docker compose up -d'"
