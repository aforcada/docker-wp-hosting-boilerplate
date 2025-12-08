#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root (sudo ./create-site.sh)"
  exit 1
fi

# Check if a site name is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: ./create-site.sh <site-name>"
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

# Check if the site directory already exists to prevent overwriting
if [ -d "$SITE_DIR" ]; then
    echo "❌ Site '$SITE_NAME' already exists."
    exit 1
fi

echo "🚀 Creating new site: $SITE_NAME"

# 1. Copy the site template to the new site directory
cp -r templates/site "$SITE_DIR"

# 2. Generate secure random passwords for DB and SFTP
DB_PASS=$(openssl rand -base64 12)
SFTP_PASS=$(openssl rand -base64 12)

# 3. Configure the site's .env file
# We use 'sed' to replace placeholders in .env.example with actual values
sed -i "s/^SITE_NAME=.*/SITE_NAME=$SITE_NAME/" "$SITE_DIR/.env.example"
sed -i "s/^DB_NAME=.*/DB_NAME=${SITE_NAME}/" "$SITE_DIR/.env.example"
sed -i "s/^DB_USER=.*/DB_USER=${SITE_NAME}/" "$SITE_DIR/.env.example"
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" "$SITE_DIR/.env.example"

# Rename .env.example to .env so Docker can use it
mv "$SITE_DIR/.env.example" "$SITE_DIR/.env"

# 4. Create Database and User automatically in MariaDB
# Load the root .env file to get the MYSQL_ROOT_PASSWORD
if [ -f .env ]; then
    # Export variables from .env ignoring comments
    export $(grep -v '^#' .env | xargs)
fi

if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    echo "🗄️  Creating Database and User in MariaDB..."
    # Check if the main mariadb container is running
    if docker ps | grep -q mariadb; then
        # Execute SQL commands inside the running mariadb container
        # - Create database if it doesn't exist
        # - Create user with the generated password
        # - Grant all privileges on that database to the user
        docker exec mariadb mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`${SITE_NAME}\`; CREATE USER IF NOT EXISTS '${SITE_NAME}'@'%' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON \`${SITE_NAME}\`.* TO '${SITE_NAME}'@'%'; FLUSH PRIVILEGES;"

        if [ $? -eq 0 ]; then
            echo "✅ Database '${SITE_NAME}' and user '${SITE_NAME}' created successfully."
        else
            echo "❌ Failed to create database. Check logs."
        fi
    else
        echo "⚠️  MariaDB container is not running. Skipping DB creation."
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
    docker compose restart sftp
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
echo "---------------------------------------------------"
echo "⚠️  STEP 1: Edit '$SITE_DIR/.env' and set the real domain in DOMAINS="
echo "   Example for one domain:      DOMAINS=\`example.com\`"
echo "   Example for multiple:        DOMAINS=\`example.com\`, \`www.example.com\`"
echo "---------------------------------------------------"
echo "🚀 To start the site:"
echo "cd $SITE_DIR && docker compose up -d"
