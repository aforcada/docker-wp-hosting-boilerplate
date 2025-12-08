# 🐳 Docker WordPress Hosting Boilerplate

This repository contains a complete Docker-based infrastructure for hosting multiple WordPress websites on a single server, using **Traefik** as a reverse proxy with automatic SSL certificates (Let's Encrypt).

## ✨ Features

- **Traefik v3**: Automatic reverse proxy with SSL certificate management.
- **Shared MariaDB**: A single database instance for all sites (resource efficient).
- **Centralized SFTP**: A single SFTP container managing access to all websites.
- **phpMyAdmin**: Visual database management.
- **Isolation**: Each WordPress runs in its own container.
- **Automation**: Scripts to initialize the server and create new sites quickly.

## 📋 Requirements

- Docker
- Docker Compose
- A domain pointing to the server IP (for Traefik and the websites).

## 🚀 Initial Setup

1. **Clone the repository:**

   ```bash
   git clone <repo-url>
   cd wp-hosting-boilerplate
   ```

2. **Initialize the environment:**
   Run the initialization script to create Docker networks and configure permissions (use `sudo` to ensure correct permissions):

   ```bash
   chmod +x init.sh create-site.sh
   sudo ./init.sh
   ```

3. **Configure environment variables:**
   Edit the generated `.env` file at the root and define:
   - `TRAEFIK_EMAIL`: Your email for Let's Encrypt.
   - `MYSQL_ROOT_PASSWORD`: The master password for MariaDB.

4. **Start main services:**
   ```bash
   docker compose up -d
   ```
   This will start Traefik, MariaDB, SFTP, and phpMyAdmin.

## 🛠️ Create a New WordPress Site

To create a new site, use the automated script (use `sudo` to ensure correct permissions):

```bash
sudo ./create-site.sh site-name
```

This script automatically:

1. Creates the `sites/site-name` folder based on the template.
2. Generates secure passwords for the Database and SFTP.
3. Creates the Database and User in MariaDB.
4. Adds the SFTP user to the configuration and restarts the service.

### Final steps for the new site:

1. The script will remind you to edit the new site's `.env` file:

   ```bash
   nano sites/site-name/.env
   ```

   **Important:** Set the real domain in the `DOMAINS` variable using **backticks** (`).

   ```dotenv
   # Single domain
   DOMAINS=`example.com`

   # Multiple domains
   DOMAINS=`example.com`, `www.example.com`
   ```

2. Start the site:
   ```bash
   cd sites/site-name
   docker compose up -d
   ```

## 📂 Directory Structure

```
.
├── compose.yml          # Global services (Traefik, MariaDB, SFTP, PMA)
├── create-site.sh       # Script to create new sites
├── init.sh              # Server initialization script
├── mariadb/             # Persistent DB data
├── sftp/
│   └── users.conf       # SFTP user configuration
├── sites/               # Where created websites are stored
│   └── site-name/       # Example site
│       ├── compose.yml
│       ├── .env
│       └── html/        # WordPress files
├── templates/           # Base template for new sites
└── traefik/             # Traefik configuration and certificates
```

## 🔧 Management & Access

### phpMyAdmin

Accessible at `https://any-of-your-domains.com/phpmyadmin`.
Use the specific user and password for each site (found in each site's `.env`).

### SFTP

- **Host**: Your server IP.
- **Port**: `2222`
- **User/Password**: Automatically generated when creating the site (stored in `sftp/users.conf` and shown during creation).
- **Directory**: The user will land directly in the `html` folder of their site.
- **Manual Configuration**: If you need to add users manually, edit `sftp/users.conf`.
  - **Format**: `user:password:UID:GID:directory`
  - **Important**: Do NOT add comments or empty lines to this file, or the SFTP container will crash.
  - **Example**: `myuser:mypassword:33:33:html`

## 🔒 Security

- **Database**: Does not expose ports to the Internet. Only accessible internally via the `db-net` network.
- **Networks**: Websites are isolated in their own `web-net` and `db-net` networks.
- **SSL**: Traefik automatically manages HTTPS certificates.

## ❓ Troubleshooting

### SFTP Connection Refused

- Ensure port `2222` is open in your firewall (AWS Security Group, UFW, etc.).
- Check if the SFTP container is restarting: `docker logs sftp`. If it complains about "bad ownership", run `sudo ./init.sh` again to fix permissions.

### SSL Certificate Errors

- Ensure your domain points to the server IP.
- Check `TRAEFIK_EMAIL` in `.env`.
- View logs: `docker compose logs traefik`.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Developed for fast and secure WordPress deployments.
