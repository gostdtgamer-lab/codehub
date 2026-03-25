#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER PTERODACTYL PANEL INSTALLER
# Fixed download issues
# ==========================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variables
MYSQL_ROOT_PASS=""
MYSQL_PTERO_PASS=""
PANEL_DOMAIN=""

# Functions
success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Please run as root (use sudo)"
    fi
}

# Show header
show_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
██████╗ ████████╗███████╗██████╗  ██████╗ ██████╗  █████╗  ██████╗████████╗██╗   ██╗██╗     
██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝╚══██╔══╝╚██╗ ██╔╝██║     
██████╔╝   ██║   █████╗  ██║  ██║██║  ██║██████╔╝███████║██║        ██║    ╚████╔╝ ██║     
██╔═══╝    ██║   ██╔══╝  ██║  ██║██║  ██║██╔══██╗██╔══██║██║        ██║     ╚██╔╝  ██║     
██║        ██║   ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║╚██████╗   ██║      ██║   ███████╗
╚═╝        ╚═╝   ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝   ╚═╝      ╚═╝   ╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${GREEN}         GOSTDTGAMER PTERODACTYL PANEL INSTALLER${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Install PHP 8.2 properly
install_php82() {
    echo -e "\n${WHITE}Installing PHP 8.2...${NC}"
    
    # Add PHP repository
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update -y
    
    # Install PHP 8.2 and required extensions
    apt-get install -y php8.2 php8.2-cli php8.2-common php8.2-curl \
        php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml \
        php8.2-fpm php8.2-zip php8.2-redis php8.2-intl php8.2-tokenizer
    
    # Verify PHP version
    PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1-2)
    if [[ "$PHP_VERSION" != "8.2" ]]; then
        echo -e "${RED}PHP 8.2 installation failed! Current version: $PHP_VERSION${NC}"
        exit 1
    fi
    
    success "PHP 8.2 installed: $(php -v | head -1)"
}

# Download Pterodactyl Panel
download_panel() {
    echo -e "\n${WHITE}Downloading Pterodactyl Panel...${NC}"
    
    cd /var/www
    
    # Remove old files if they exist
    rm -rf pterodactyl panel.tar.gz 2>/dev/null || true
    
    # Download using wget with retry
    wget --tries=5 --timeout=30 -O panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    
    if [[ ! -f panel.tar.gz ]]; then
        echo -e "${RED}Download failed! Trying alternative method...${NC}"
        curl -L -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    fi
    
    if [[ ! -f panel.tar.gz ]]; then
        error "Failed to download panel. Check your internet connection."
    fi
    
    # Extract
    echo -e "${WHITE}Extracting...${NC}"
    tar -xzf panel.tar.gz
    
    # Find extracted directory
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "panel-*" | head -1)
    
    if [[ -z "$EXTRACTED_DIR" ]]; then
        error "Extraction failed! No panel directory found."
    fi
    
    # Move to pterodactyl directory
    mv "$EXTRACTED_DIR" pterodactyl
    rm -f panel.tar.gz
    
    success "Panel downloaded and extracted"
}

# Install Pterodactyl Panel
install_panel() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📦 INSTALLING PTERODACTYL PANEL${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get domain
    echo -ne "${WHITE}Enter your panel domain (e.g., panel.example.com or press Enter for IP): ${NC}"
    read PANEL_DOMAIN
    
    if [[ -z "$PANEL_DOMAIN" ]]; then
        PANEL_DOMAIN=$(curl -s ifconfig.me)
        echo -e "${YELLOW}Using IP: $PANEL_DOMAIN${NC}"
    fi
    
    # Step 1: Update system
    echo -e "\n${WHITE}[1/10] Updating system...${NC}"
    apt-get update -y
    apt-get upgrade -y
    
    # Step 2: Install base dependencies
    echo -e "\n${WHITE}[2/10] Installing base dependencies...${NC}"
    apt-get install -y curl wget git nginx mysql-server redis-server \
        tar unzip zip gzip ca-certificates gnupg lsb-release \
        software-properties-common
    
    # Step 3: Install PHP 8.2
    echo -e "\n${WHITE}[3/10] Installing PHP 8.2...${NC}"
    install_php82
    
    # Step 4: Install Docker
    echo -e "\n${WHITE}[4/10] Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    
    # Step 5: Setup MySQL
    echo -e "\n${WHITE}[5/10] Setting up MySQL...${NC}"
    
    # Start MySQL if not running
    systemctl start mysql 2>/dev/null || true
    
    MYSQL_ROOT_PASS=$(openssl rand -base64 16)
    MYSQL_PTERO_PASS=$(openssl rand -base64 16)
    
    # Set MySQL root password
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
    
    # Create database and user
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS panel;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PTERO_PASS}';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    # Save credentials
    cat > /root/pterodactyl_db_credentials.txt << EOF
====================================
PTERODACTYL DATABASE CREDENTIALS
====================================
MySQL Root Password: $MYSQL_ROOT_PASS
Pterodactyl Database User: pterodactyl
Pterodactyl Database Password: $MYSQL_PTERO_PASS
Database Name: panel
====================================
EOF
    
    success "MySQL configured"
    
    # Step 6: Download Panel
    echo -e "\n${WHITE}[6/10] Downloading Pterodactyl Panel...${NC}"
    download_panel
    
    # Step 7: Setup Panel permissions
    echo -e "\n${WHITE}[7/10] Setting permissions...${NC}"
    cd /var/www/pterodactyl
    chmod -R 755 storage/* bootstrap/cache
    
    # Step 8: Install Composer
    echo -e "\n${WHITE}[8/10] Installing Composer...${NC}"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    cp .env.example .env
    
    # Step 9: Install dependencies
    echo -e "\n${WHITE}[9/10] Installing PHP dependencies...${NC}"
    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --ignore-platform-reqs
    
    # Step 10: Configure Panel
    echo -e "\n${WHITE}[10/10] Configuring Panel...${NC}"
    php artisan key:generate --force
    
    # Setup environment
    php artisan p:environment:setup --author=admin@localhost --url=http://$PANEL_DOMAIN --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 --no-interaction || true
    
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}" --no-interaction || true
    
    # Run migrations
    php artisan migrate --seed --force
    
    # Create admin user
    echo -e "\n${YELLOW}Create Admin User:${NC}"
    echo -ne "${WHITE}Admin Email (default: admin@localhost): ${NC}"
    read ADMIN_EMAIL
    [[ -z "$ADMIN_EMAIL" ]] && ADMIN_EMAIL="admin@localhost"
    
    echo -ne "${WHITE}Admin Username (default: admin): ${NC}"
    read ADMIN_USERNAME
    [[ -z "$ADMIN_USERNAME" ]] && ADMIN_USERNAME="admin"
    
    echo -ne "${WHITE}Admin Password (default: password123): ${NC}"
    read -s ADMIN_PASSWORD
    echo ""
    [[ -z "$ADMIN_PASSWORD" ]] && ADMIN_PASSWORD="password123"
    
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first=Admin --name-last=User --password="$ADMIN_PASSWORD" --admin=1 --no-interaction
    
    # Set permissions
    chown -R www-data:www-data /var/www/pterodactyl/*
    
    # Configure Nginx
    echo -e "\n${WHITE}Configuring Nginx...${NC}"
    cat > /etc/nginx/sites-available/pterodactyl.conf << EOF
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
    systemctl restart php8.2-fpm
    
    # Setup queue worker
    cat > /etc/systemd/system/pteroq.service << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now pteroq
    
    # Setup cron
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    # Completion
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ PTERODACTYL PANEL INSTALLED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Panel Access:${NC} http://$PANEL_DOMAIN"
    echo -e "${YELLOW}Admin Login:${NC} $ADMIN_USERNAME / $ADMIN_PASSWORD"
    echo -e "${YELLOW}DB Credentials:${NC} /root/pterodactyl_db_credentials.txt"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Access your panel at http://$PANEL_DOMAIN"
    echo -e "  2. Login with admin credentials"
    echo -e "  3. Go to Admin → Nodes → Create New to add a node"
    echo -e "  4. Install Wings on your node server"
    echo ""
}

# Install Wings Only
install_wings() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🚀 INSTALLING PTERODACTYL WINGS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Install Docker
    echo -e "${WHITE}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    
    # Download Wings
    echo -e "${WHITE}Downloading Wings...${NC}"
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    
    # Create directories
    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes
    
    # Create service
    cat > /etc/systemd/system/wings.service << 'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable wings
    
    echo -e "\n${GREEN}✓ Wings installed!${NC}"
    echo ""
    echo -e "${YELLOW}To configure Wings:${NC}"
    echo -e "  1. Go to your Pterodactyl Panel → Admin → Nodes"
    echo -e "  2. Create a new node"
    echo -e "  3. After creating, go to the node's Configuration tab"
    echo -e "  4. Copy the configuration and save to /etc/pterodactyl/config.yml"
    echo -e "  5. Run: systemctl start wings"
    echo ""
}

# Fix PHP version
fix_php_version() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🔧 FIXING PHP VERSION ISSUE${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    install_php82
    systemctl restart php8.2-fpm
    
    echo -e "\n${GREEN}PHP version fixed! Now you can install the panel.${NC}"
}

# Uninstall Panel
uninstall_panel() {
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  UNINSTALL PTERODACTYL${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "${RED}Are you sure? This will delete everything! (y/n): ${NC}"
    read confirm
    
    if [[ "$confirm" != "y" ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return
    fi
    
    echo -e "${WHITE}Stopping services...${NC}"
    systemctl stop pteroq 2>/dev/null || true
    systemctl stop wings 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    echo -e "${WHITE}Removing files...${NC}"
    rm -rf /var/www/pterodactyl
    rm -rf /etc/pterodactyl
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/systemd/system/pteroq.service
    rm -f /etc/systemd/system/wings.service
    
    echo -e "${WHITE}Removing database...${NC}"
    mysql -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
    mysql -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Pterodactyl uninstalled!${NC}"
}

# Main menu
main_menu() {
    show_header
    
    echo -e "  ${GREEN}1)${NC} Install Pterodactyl Panel (Full)"
    echo -e "  ${GREEN}2)${NC} Install Pterodactyl Wings Only"
    echo -e "  ${GREEN}3)${NC} Fix PHP Version Issue"
    echo -e "  ${GREEN}4)${NC} Uninstall Pterodactyl"
    echo -e "  ${RED}0)${NC} Exit"
    echo ""
    echo -ne "${WHITE}Enter your choice: ${NC}"
    read choice
    
    case $choice in
        1) install_panel ;;
        2) install_wings ;;
        3) fix_php_version ;;
        4) uninstall_panel ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid choice${NC}"; sleep 2; main_menu ;;
    esac
}

# Start
check_root
main_menu
