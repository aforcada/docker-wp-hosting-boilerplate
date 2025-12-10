#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./create-site.sh)"
  exit 1
fi

# Check if a site name is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: sudo ./create-site.sh <site-name>"
    exit 1
fi

SITE_NAME=$1

# Validate site name format (lowercase, numbers, hyphens only)
if ! [[ "$SITE_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Error: Site name must contain only lowercase letters, numbers, and hyphens."
    echo "   Example: my-site"
    exit 1
fi

SITE_DIR="sites/$SITE_NAME"
CONFIG_DIR="config/$SITE_NAME"

# Check if the site directory already exists to prevent overwriting
if [ -d "$SITE_DIR" ] || [ -d "$CONFIG_DIR" ]; then
    echo "❌ Site '$SITE_NAME' already exists (in sites/ or config/)."
    exit 1
fi

echo "🚀 Creating new site: $SITE_NAME"

# 1. Create directories and copy templates
mkdir -p "$SITE_DIR/html"
mkdir -p "$CONFIG_DIR"

cp _template_/config/.env.example "$CONFIG_DIR/"
cp _template_/config/compose.yml "$CONFIG_DIR/"

# 2. Generate secure random passwords for DB and SFTP
DB_PASS=$(openssl rand -base64 12)
SFTP_PASS=$(openssl rand -base64 12)

# 3. Configure the site's .env file
# We use 'sed' to replace placeholders in .env.example with actual values
sed -i "s/^SITE_NAME=.*/SITE_NAME=$SITE_NAME/" "$CONFIG_DIR/.env.example"
sed -i "s/^DB_NAME=.*/DB_NAME=${SITE_NAME}/" "$CONFIG_DIR/.env.example"
sed -i "s/^DB_USER=.*/DB_USER=${SITE_NAME}/" "$CONFIG_DIR/.env.example"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" "$CONFIG_DIR/.env.example"

# Rename .env.example to .env so Docker can use it
mv "$CONFIG_DIR/.env.example" "$CONFIG_DIR/.env"

# 4. Create Database and User automatically
# Load the root .env file to get the MYSQL_ROOT_PASSWORD
if [ -f .env ]; then
    # Export variables from .env ignoring comments
    export $(grep -v '^#' .env | xargs)
fi

if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    echo "🗄️  Creating Database and User..."
    # Check if the main db container is running
    if docker ps | grep -q db; then
        # Detect DB client command (mariadb or mysql)
        if docker exec db sh -c 'command -v mariadb > /dev/null 2>&1'; then
            DB_CLIENT="mariadb"
        elif docker exec db sh -c 'command -v mysql > /dev/null 2>&1'; then
            DB_CLIENT="mysql"
        else
            echo "❌ Error: Neither 'mariadb' nor 'mysql' client found in the database container."
            echo "   Please check your DB_IMAGE in .env"
            exit 1
        fi

        # Execute SQL commands inside the running db container
        # - Create database if it doesn't exist
        # - Create user with the generated password
        # - Grant all privileges on that database to the user
        docker exec db $DB_CLIENT -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`${SITE_NAME}\`; CREATE USER IF NOT EXISTS '${SITE_NAME}'@'%' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON \`${SITE_NAME}\`.* TO '${SITE_NAME}'@'%'; FLUSH PRIVILEGES;"

        if [ $? -eq 0 ]; then
            echo "✅ Database '${SITE_NAME}' and user '${SITE_NAME}' created successfully."
        else
            echo "❌ Failed to create database. Check logs."
        fi
    else
        echo "⚠️  Database container is not running. Skipping DB creation."
    fi
else
    echo "⚠️  MYSQL_ROOT_PASSWORD not found in root .env. Skipping DB creation."
fi

# 5. Configure SFTP access
echo "📂 Adding SFTP user..."
if [ -f "sftp/users.conf" ]; then
    # Append the new user to the SFTP configuration file
    # Format: user:password:UID:GID:directory
    echo "${SITE_NAME}:${SFTP_PASS}:33:33:html" >> sftp/users.conf

    # Restart the SFTP service to apply changes
    # We use 'up -d --force-recreate' to ensure it picks up the config even if it was in a crash loop
    docker compose up -d --force-recreate sftp
    echo "✅ SFTP user added and service restarted."
else
    echo "⚠️  sftp/users.conf not found. Skipping SFTP configuration."
fi

# 6. Fix permissions for SFTP and WordPress
echo "🔧 Fixing permissions..."

chown root:root "$SITE_DIR"
chmod 755 "$SITE_DIR"
chown -R 33:33 "$SITE_DIR/html"
chmod -R 755 "$SITE_DIR/html"

echo "✅ Site created at: $SITE_DIR"
echo "✅ Config created at: $CONFIG_DIR"
echo "---------------------------------------------------"
echo "🔐 CREDENTIALS (SAVE THEM NOW!)"
echo "   - Database User: $SITE_NAME"
echo "   - Database Pass: $DB_PASS"
echo "   - SFTP User:     $SITE_NAME"
echo "   - SFTP Pass:     $SFTP_PASS"
echo "---------------------------------------------------"
echo "⚠️  STEP 1: Edit '$CONFIG_DIR/.env' and set the real domain in DOMAINS variable"
echo "🚀 To start the site:"
echo "cd $CONFIG_DIR && docker compose up -d"
