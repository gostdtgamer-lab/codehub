#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER PTERODACTYL DEPLOYMENT SUITE
# Supports: Ubuntu 20.04/22.04, Debian 11/12
# DATE: 2026-03-25
# ==========================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Config
LOG_FILE="/tmp/pterodactyl_install.log"
MYSQL_ROOT_PASS=""
MYSQL_PTERO_PASS=""

# Functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        error "Cannot detect OS"
    fi
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        error "This script only supports Ubuntu and Debian"
    fi
    
    log "Detected OS: $OS $VER"
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
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${RED}☢️  GOSTDTGAMER PTERODACTYL SUITE${NC} ${GREEN}v1.0${NC}              ${CYAN}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${GREEN}                   POWERED BY GOSTDTGAMER${NC}"
    echo ""
}

# Show system info
show_info() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                    SYSTEM INFORMATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    CPU_CORES=$(nproc)
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs || echo "Unknown")
    echo -e "${WHITE}├─ CPU Cores      :${NC} ${GREEN}$CPU_CORES${NC}"
    echo -e "${WHITE}├─ CPU Model      :${NC} ${GREEN}$CPU_MODEL${NC}"
    
    RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    echo -e "${WHITE}├─ Total RAM      :${NC} ${GREEN}$RAM_TOTAL${NC}"
    
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    echo -e "${WHITE}├─ Total Disk     :${NC} ${GREEN}$DISK_TOTAL${NC}"
    echo -e "${WHITE}├─ Free Disk      :${NC} ${GREEN}$DISK_FREE${NC}"
    
    echo -e "${WHITE}├─ OS             :${NC} ${GREEN}$OS $VER${NC}"
    
    IP_PUBLIC=$(curl -s --max-time 5 ifconfig.me || echo "Not available")
    echo -e "${WHITE}└─ Public IP      :${NC} ${GREEN}$IP_PUBLIC${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Update system
update_system() {
    log "Updating system packages..."
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    success "System updated"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    apt-get install -y curl wget git nginx mysql-server redis-server \
        tar unzip zip gzip ca-certificates gnupg lsb-release \
        software-properties-common >> "$LOG_FILE" 2>&1
    
    # Install PHP 8.2
    apt-get install -y php8.2 php8.2-cli php8.2-common php8.2-curl \
        php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml \
        php8.2-fpm php8.2-zip php8.2-redis >> "$LOG_FILE" 2>&1
    
    # Install Docker
    curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1
    systemctl enable docker
    systemctl start docker
    
    success "Dependencies installed"
}

# Setup MySQL
setup_mysql() {
    log "Setting up MySQL database..."
    
    # Generate random passwords
    MYSQL_ROOT_PASS=$(openssl rand -base64 16)
    MYSQL_PTERO_PASS=$(openssl rand -base64 16)
    
    # Secure MySQL installation
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
    mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    # Create Pterodactyl database
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
    echo -e "  ${YELLOW}Credentials saved to: /root/pterodactyl_db_credentials.txt${NC}"
}

# Install Pterodactyl Panel
install_pterodactyl_panel() {
    log "Installing Pterodactyl Panel..."
    
    cd /var/www
    
    # Download panel
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz >> "$LOG_FILE" 2>&1
    tar -xzvf panel.tar.gz >> "$LOG_FILE" 2>&1
    rm panel.tar.gz
    mv panel-* pterodactyl
    cd pterodactyl
    
    # Set permissions
    chmod -R 755 storage/* bootstrap/cache
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> "$LOG_FILE" 2>&1
    
    # Install dependencies
    cp .env.example .env
    composer install --no-dev --optimize-autoloader >> "$LOG_FILE" 2>&1
    
    # Generate key
    php artisan key:generate --force >> "$LOG_FILE" 2>&1
    
    # Configure environment
    php artisan p:environment:setup --author=admin@localhost --url=http://localhost --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 --no-interaction >> "$LOG_FILE" 2>&1 || true
    
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}" --no-interaction >> "$LOG_FILE" 2>&1 || true
    
    # Run migrations
    php artisan migrate --seed --force >> "$LOG_FILE" 2>&1
    
    # Create admin user
    php artisan p:user:make --email=admin@localhost --username=admin --name-first=Admin --name-last=User --password=password123 --admin=1 --no-interaction >> "$LOG_FILE" 2>&1 || true
    
    # Set permissions
    chown -R www-data:www-data /var/www/pterodactyl/*
    
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
    
    systemctl enable --now pteroq.service >> "$LOG_FILE" 2>&1
    
    # Setup cron job
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    success "Pterodactyl Panel installed"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    cat > /etc/nginx/sites-available/pterodactyl.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
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
    
    success "Nginx configured"
}

# Install Pterodactyl Wings
install_pterodactyl_wings() {
    log "Installing Pterodactyl Wings..."
    
    # Create wings user
    useradd -r -d /var/lib/pterodactyl -m -s /bin/bash wings 2>/dev/null || true
    
    # Create directories
    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/{tmp,archive,backups}
    
    # Download wings
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 >> "$LOG_FILE" 2>&1
    chmod u+x /usr/local/bin/wings
    
    # Create systemd service
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
    
    mkdir -p /var/run/wings
    chown -R wings:wings /var/run/wings
    
    success "Pterodactyl Wings installed"
    echo -e "\n  ${YELLOW}Wings Setup Required:${NC}"
    echo -e "  ${WHITE}├─ After panel installation, get node configuration from panel${NC}"
    echo -e "  ${WHITE}├─ Save config to: /etc/pterodactyl/config.yml${NC}"
    echo -e "  ${WHITE}└─ Then start wings: systemctl start wings${NC}"
}

# Install Node.js
install_node() {
    log "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y nodejs >> "$LOG_FILE" 2>&1
    success "Node.js installed: $(node -v)"
}

# Uninstall Node.js
uninstall_node() {
    log "Uninstalling Node.js..."
    apt-get remove -y nodejs >> "$LOG_FILE" 2>&1
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    rm -rf /usr/local/lib/node_modules
    rm -rf ~/.npm
    success "Node.js uninstalled"
}

# Install Tailscale with login link
install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh >> "$LOG_FILE" 2>&1
    success "Tailscale installed"
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}🔐 TAILSCALE AUTHENTICATION${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}Click the link below to authenticate your Tailscale account:${NC}"
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Start tailscale and capture the login URL
    tailscale up 2>&1 | tee /tmp/tailscale_output.txt
    LOGIN_URL=$(grep -oP 'https://login.tailscale.com/a/[a-zA-Z0-9]+' /tmp/tailscale_output.txt || echo "")
    
    if [[ -n "$LOGIN_URL" ]]; then
        echo -e "  ${GREEN}👉 $LOGIN_URL${NC}"
    else
        echo -e "  ${GREEN}👉 https://login.tailscale.com${NC}"
    fi
    
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}Instructions:${NC}"
    echo -e "  ${WHITE}1.${NC} Click the link above or copy it to your browser"
    echo -e "  ${WHITE}2.${NC} Log in with your Google, Microsoft, or GitHub account"
    echo -e "  ${WHITE}3.${NC} Click 'Connect' to add this device to your Tailscale network"
    echo -e "  ${WHITE}4.${NC} Return here and press Enter to complete setup"
    echo ""
    
    echo -ne "  ${GREEN}Press Enter after you've authenticated in your browser...${NC}"
    read
    
    # Check if authenticated
    if tailscale status 2>&1 | grep -q "Connected"; then
        success "Tailscale is now connected!"
        echo -e "\n  ${GREEN}Tailscale Status:${NC}"
        tailscale status
        echo -e "\n  ${GREEN}Your Tailscale IP: $(tailscale ip 2>/dev/null)${NC}"
    else
        echo -e "\n  ${YELLOW}Waiting for authentication...${NC}"
        tailscale up --accept-routes=true &
        echo -e "  ${WHITE}If the link didn't work, please visit: https://login.tailscale.com${NC}"
        echo -ne "  ${GREEN}Press Enter after authentication...${NC}"
        read
        success "Tailscale setup completed!"
    fi
}

# Uninstall Tailscale
uninstall_tailscale() {
    log "Uninstalling Tailscale..."
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}🗑️  TAILSCALE UNINSTALL${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Stop Tailscale
    if command -v tailscale &> /dev/null; then
        echo -e "  ${WHITE}Stopping Tailscale...${NC}"
        tailscale down >> "$LOG_FILE" 2>&1
        systemctl stop tailscaled >> "$LOG_FILE" 2>&1
    fi
    
    # Remove Tailscale package
    echo -e "  ${WHITE}Removing Tailscale packages...${NC}"
    apt-get remove -y tailscale >> "$LOG_FILE" 2>&1
    
    # Remove configuration and data
    echo -e "  ${WHITE}Removing Tailscale configuration...${NC}"
    rm -rf /var/lib/tailscale
    rm -rf /etc/tailscale
    rm -rf ~/.cache/tailscale
    rm -rf ~/.config/tailscale
    
    # Remove apt repository
    echo -e "  ${WHITE}Removing Tailscale repository...${NC}"
    rm -f /etc/apt/sources.list.d/tailscale.list
    apt-get update >> "$LOG_FILE" 2>&1
    
    success "Tailscale has been completely uninstalled"
    echo -e "  ${GREEN}✓ Tailscale removed from system${NC}"
}

# Install Cloudflared with Token Setup
install_cloudflared() {
    log "Installing Cloudflared..."
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}☁️  CLOUDFLARED INSTALLATION${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Add cloudflare gpg key
    echo -e "  ${WHITE}Step 1: Adding Cloudflare GPG key...${NC}"
    mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg > /dev/null
    success "GPG key added"
    
    # Add repository
    echo -e "  ${WHITE}Step 2: Adding Cloudflare repository...${NC}"
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
    success "Repository added"
    
    # Update and install
    echo -e "  ${WHITE}Step 3: Installing cloudflared...${NC}"
    apt-get update >> "$LOG_FILE" 2>&1
    apt-get install -y cloudflared >> "$LOG_FILE" 2>&1
    success "Cloudflared installed: $(cloudflared version)"
    
    echo -e "\n  ${GREEN}✓ Cloudflared installation complete!${NC}"
    echo ""
    
    # Ask for token setup
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}🔑 CLOUDFLARE TOKEN SETUP${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}Do you want to set up a Cloudflare Tunnel with your token?${NC}"
    echo -e "  ${GREEN}1)${NC} Yes, set up tunnel with token"
    echo -e "  ${RED}2)${NC} No, skip for now"
    echo ""
    echo -ne "  ${WHITE}Enter your choice [1-2]: ${NC}"
    read token_choice
    
    if [[ "$token_choice" == "1" ]]; then
        setup_cloudflare_with_token
    else
        echo -e "\n  ${YELLOW}You can set up a tunnel later by running:${NC}"
        echo -e "  ${WHITE}cloudflared tunnel login${NC}"
        echo -e "  ${WHITE}cloudflared tunnel create <tunnel-name>${NC}"
    fi
}

# Setup Cloudflare Tunnel with Token
setup_cloudflare_with_token() {
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}🔧 CLOUDFLARE TUNNEL SETUP${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Ask for token
    echo -e "  ${WHITE}Please enter your Cloudflare Tunnel Token:${NC}"
    echo -e "  ${YELLOW}(You can get this from Cloudflare Dashboard > Zero Trust > Networks > Tunnels)${NC}"
    echo ""
    echo -ne "  ${GREEN}► Put your token: ${NC}"
    read CLOUDFLARE_TOKEN
    
    if [[ -z "$CLOUDFLARE_TOKEN" ]]; then
        echo -e "\n  ${RED}Token cannot be empty! Skipping tunnel setup.${NC}"
        return
    fi
    
    # Validate token format (basic check)
    if [[ ! "$CLOUDFLARE_TOKEN" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ! "$CLOUDFLARE_TOKEN" =~ ^[A-Za-z0-9]+ ]]; then
        echo -e "\n  ${YELLOW}⚠️  Token format looks unusual, but we'll try to use it.${NC}"
    fi
    
    echo -e "\n  ${WHITE}Verifying and setting up tunnel with your token...${NC}"
    
    # Create tunnel using token
    echo -e "  ${WHITE}Creating tunnel with provided token...${NC}"
    
    # Use the token to create and run tunnel
    cloudflared tunnel --token "$CLOUDFLARE_TOKEN" run &
    TUNNEL_PID=$!
    
    # Wait a moment to see if it starts
    sleep 3
    
    # Check if tunnel is running
    if ps -p $TUNNEL_PID > /dev/null 2>&1; then
        success "✓ Tunnel created and running successfully!"
        echo -e "\n  ${GREEN}Your Cloudflare Tunnel is now active!${NC}"
        echo -e "  ${WHITE}Process ID: $TUNNEL_PID${NC}"
        echo -e "  ${YELLOW}To stop the tunnel: kill $TUNNEL_PID${NC}"
        
        # Ask if user wants to install as service
        echo -e "\n  ${WHITE}Do you want to install this tunnel as a service (auto-start on boot)?${NC}"
        echo -e "  ${GREEN}1)${NC} Yes, install as service"
        echo -e "  ${RED}2)${NC} No, keep running in background"
        echo ""
        echo -ne "  ${WHITE}Enter your choice [1-2]: ${NC}"
        read service_choice
        
        if [[ "$service_choice" == "1" ]]; then
            # Save token for service
            mkdir -p /root/.cloudflared
            cat > /root/.cloudflared/token << EOF
$CLOUDFLARE_TOKEN
EOF
            
            # Create service file
            cat > /etc/systemd/system/cloudflared-tunnel.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --token $(cat /root/.cloudflared/token)
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
            
            systemctl daemon-reload
            systemctl enable cloudflared-tunnel
            systemctl start cloudflared-tunnel
            
            success "✓ Tunnel installed as system service"
            echo -e "  ${WHITE}Status: systemctl status cloudflared-tunnel${NC}"
            echo -e "  ${WHITE}Stop: systemctl stop cloudflared-tunnel${NC}"
            echo -e "  ${WHITE}Start: systemctl start cloudflared-tunnel${NC}"
        fi
    else
        echo -e "\n  ${RED}✗ Failed to start tunnel. Please check your token.${NC}"
        echo -e "  ${YELLOW}You can try setting up manually:${NC}"
        echo -e "  ${WHITE}cloudflared tunnel --token YOUR_TOKEN run${NC}"
    fi
}

# Uninstall Cloudflared
uninstall_cloudflared() {
    log "Uninstalling Cloudflared..."
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}🗑️  CLOUDFLARED UNINSTALL${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Stop cloudflared service if running
    if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
        echo -e "  ${WHITE}Stopping cloudflared tunnel service...${NC}"
        systemctl stop cloudflared-tunnel >> "$LOG_FILE" 2>&1
        systemctl disable cloudflared-tunnel >> "$LOG_FILE" 2>&1
        rm -f /etc/systemd/system/cloudflared-tunnel.service
    fi
    
    # Kill any running cloudflared processes
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    
    # Remove cloudflared package
    echo -e "  ${WHITE}Removing cloudflared package...${NC}"
    apt-get remove -y cloudflared >> "$LOG_FILE" 2>&1
    
    # Remove configuration and tunnels
    echo -e "  ${WHITE}Removing cloudflared configuration...${NC}"
    rm -rf /root/.cloudflared
    rm -rf /etc/cloudflared
    
    # Remove apt repository and key
    echo -e "  ${WHITE}Removing cloudflared repository...${NC}"
    rm -f /etc/apt/sources.list.d/cloudflared.list
    rm -f /usr/share/keyrings/cloudflare-public-v2.gpg
    apt-get update >> "$LOG_FILE" 2>&1
    
    success "Cloudflared has been completely uninstalled"
    echo -e "  ${GREEN}✓ Cloudflared and all tunnels removed from system${NC}"
}

# Show Cloudflared Status
show_cloudflared_status() {
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}📊 CLOUDFLARED STATUS${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if command -v cloudflared &> /dev/null; then
        echo -e "  ${GREEN}✓ Cloudflared is installed${NC}"
        echo -e "  ${WHITE}Version: $(cloudflared version)${NC}"
        
        # Check if tunnel service is running
        if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
            echo -e "  ${GREEN}✓ Tunnel service is running${NC}"
            systemctl status cloudflared-tunnel --no-pager | head -5
        elif pgrep -f "cloudflared tunnel" > /dev/null; then
            echo -e "  ${GREEN}✓ Tunnel is running in background${NC}"
            echo -e "  ${WHITE}PID: $(pgrep -f 'cloudflared tunnel')${NC}"
        else
            echo -e "  ${YELLOW}⚠ No tunnel is currently running${NC}"
        fi
    else
        echo -e "  ${RED}✗ Cloudflared is not installed${NC}"
    fi
}

# Install RDP
install_rdp() {
    log "Installing RDP (X2Go)..."
    
    apt-get install -y x2goserver x2goserver-xsession xfce4 xfce4-goodies >> "$LOG_FILE" 2>&1
    
    success "RDP installed"
    echo -e "\n  ${YELLOW}RDP Information${NC}"
    echo -e "  ${WHITE}├─ Desktop: XFCE4${NC}"
    echo -e "  ${WHITE}├─ Port: 22 (SSH)${NC}"
    echo -e "  ${WHITE}└─ Connect using X2Go client with SSH protocol${NC}"
}

# Uninstall RDP
uninstall_rdp() {
    log "Uninstalling RDP..."
    
    apt-get remove -y x2goserver x2goserver-xsession xfce4 xfce4-goodies >> "$LOG_FILE" 2>&1
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    
    success "RDP uninstalled"
}

# Install Norfurch (Monitoring)
install_norfurch() {
    log "Installing Norfurch (Monitoring Tools)..."
    
    apt-get install -y htop nmon iotop iftop >> "$LOG_FILE" 2>&1
    
    # Install netdata
    curl -fsSL https://my-netdata.io/kickstart.sh | sh >> "$LOG_FILE" 2>&1
    
    success "Norfurch monitoring tools installed"
    echo -e "\n  ${YELLOW}Monitoring Tools Available:${NC}"
    echo -e "  ${WHITE}├─ htop    : Interactive process viewer${NC}"
    echo -e "  ${WHITE}├─ nmon    : System performance monitor${NC}"
    echo -e "  ${WHITE}├─ iotop   : I/O monitoring${NC}"
    echo -e "  ${WHITE}├─ iftop   : Network bandwidth monitor${NC}"
    echo -e "  ${WHITE}└─ netdata : Web-based monitoring at http://localhost:19999${NC}"
}

# Uninstall Norfurch
uninstall_norfurch() {
    log "Uninstalling monitoring tools..."
    
    apt-get remove -y htop nmon iotop iftop >> "$LOG_FILE" 2>&1
    
    # Uninstall netdata
    if command -v netdata &> /dev/null; then
        systemctl stop netdata >> "$LOG_FILE" 2>&1
        systemctl disable netdata >> "$LOG_FILE" 2>&1
        rm -rf /etc/netdata
        rm -rf /var/lib/netdata
        rm -rf /usr/share/netdata
    fi
    
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    
    success "Monitoring tools uninstalled"
}

# Node.js menu
node_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    NODE.JS MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if Node.js is installed
        if command -v node &> /dev/null; then
            echo -e "  ${GREEN}Status: NODE.JS IS INSTALLED${NC}"
            echo -e "  ${WHITE}Version: $(node -v)${NC}"
            echo -e "  ${WHITE}NPM Version: $(npm -v)${NC}"
        else
            echo -e "  ${RED}Status: NODE.JS NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Node.js"
        echo -e "  ${RED}2)${NC} Uninstall Node.js"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-2]: ${NC}"
        read choice
        
        case $choice in
            1) install_node ;;
            2) uninstall_node ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"
        read
    done
}

# Tailscale menu
tailscale_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    TAILSCALE VPN MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if Tailscale is installed
        if command -v tailscale &> /dev/null; then
            echo -e "  ${GREEN}Status: TAILSCALE IS INSTALLED${NC}"
            if tailscale status 2>&1 | grep -q "Connected"; then
                echo -e "  ${GREEN}Connection: Connected ✓${NC}"
                echo -e "  ${WHITE}IP Address: $(tailscale ip 2>/dev/null)${NC}"
            else
                echo -e "  ${YELLOW}Connection: Not connected${NC}"
            fi
        else
            echo -e "  ${RED}Status: TAILSCALE NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Tailscale VPN"
        echo -e "  ${RED}2)${NC} Uninstall Tailscale VPN"
        echo -e "  ${GREEN}3)${NC} Show Tailscale Status"
        echo -e "  ${GREEN}4)${NC} Connect/Start Tailscale"
        echo -e "  ${RED}5)${NC} Disconnect/Stop Tailscale"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-5]: ${NC}"
        read choice
        
        case $choice in
            1) install_tailscale ;;
            2) uninstall_tailscale ;;
            3) 
                if command -v tailscale &> /dev/null; then
                    tailscale status
                else
                    echo -e "${RED}Tailscale is not installed${NC}"
                fi
                echo -ne "\n${WHITE}Press Enter...${NC}"
                read
                ;;
            4)
                if command -v tailscale &> /dev/null; then
                    echo -e "${YELLOW}Starting Tailscale...${NC}"
                    tailscale up
                else
                    echo -e "${RED}Tailscale is not installed. Please install first.${NC}"
                fi
                echo -ne "\n${WHITE}Press Enter...${NC}"
                read
                ;;
            5)
                if command -v tailscale &> /dev/null; then
                    echo -e "${YELLOW}Stopping Tailscale...${NC}"
                    tailscale down
                else
                    echo -e "${RED}Tailscale is not installed${NC}"
                fi
                echo -ne "\n${WHITE}Press Enter...${NC}"
                read
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Cloudflared menu
cloudflared_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    CLOUDFLARED MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if Cloudflared is installed
        if command -v cloudflared &> /dev/null; then
            echo -e "  ${GREEN}Status: CLOUDFLARED IS INSTALLED${NC}"
            echo -e "  ${WHITE}Version: $(cloudflared version 2>/dev/null | head -1)${NC}"
            
            # Check if tunnel is running
            if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
                echo -e "  ${GREEN}Tunnel Status: SERVICE RUNNING ✓${NC}"
            elif pgrep -f "cloudflared tunnel" > /dev/null; then
                echo -e "  ${GREEN}Tunnel Status: RUNNING ✓${NC}"
            else
                echo -e "  ${YELLOW}Tunnel Status: NOT RUNNING${NC}"
            fi
        else
            echo -e "  ${RED}Status: CLOUDFLARED NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Cloudflared (with token setup)"
        echo -e "  ${RED}2)${NC} Uninstall Cloudflared"
        echo -e "  ${GREEN}3)${NC} Show Status"
        echo -e "  ${GREEN}4)${NC} Setup Tunnel with Token"
        echo -e "  ${GREEN}5)${NC} Start Tunnel (if token saved)"
        echo -e "  ${RED}6)${NC} Stop Tunnel"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-6]: ${NC}"
        read choice
        
        case $choice in
            1) install_cloudflared ;;
            2) uninstall_cloudflared ;;
            3) show_cloudflared_status ;;
            4) setup_cloudflare_with_token ;;
            5)
                if [[ -f "/root/.cloudflared/token" ]]; then
                    echo -e "${YELLOW}Starting tunnel with saved token...${NC}"
                    cloudflared tunnel --token "$(cat /root/.cloudflared/token)" run &
                    echo -e "${GREEN}Tunnel started in background${NC}"
                else
                    echo -e "${RED}No saved token found. Please setup tunnel first.${NC}"
                fi
                echo -ne "\n${WHITE}Press Enter...${NC}"
                read
                ;;
            6)
                pkill -f "cloudflared tunnel" 2>/dev/null || true
                if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
                    systemctl stop cloudflared-tunnel
                fi
                echo -e "${GREEN}All tunnels stopped${NC}"
                echo -ne "\n${WHITE}Press Enter...${NC}"
                read
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# RDP menu
rdp_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    RDP (X2Go) MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if RDP is installed
        if command -v x2goserver &> /dev/null; then
            echo -e "  ${GREEN}Status: X2Go SERVER IS INSTALLED${NC}"
            echo -e "  ${WHITE}Desktop: XFCE4${NC}"
            echo -e "  ${WHITE}Port: 22 (SSH)${NC}"
        else
            echo -e "  ${RED}Status: X2Go SERVER NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install RDP (X2Go + XFCE4)"
        echo -e "  ${RED}2)${NC} Uninstall RDP"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-2]: ${NC}"
        read choice
        
        case $choice in
            1) install_rdp ;;
            2) uninstall_rdp ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"
        read
    done
}

# Norfurch menu
norfurch_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    NORFURCH MONITORING MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if monitoring tools are installed
        if command -v htop &> /dev/null; then
            echo -e "  ${GREEN}Status: MONITORING TOOLS ARE INSTALLED${NC}"
            echo -e "  ${WHITE}Tools: htop, nmon, iotop, iftop, netdata${NC}"
        else
            echo -e "  ${RED}Status: MONITORING TOOLS NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Norfurch (Monitoring Tools)"
        echo -e "  ${RED}2)${NC} Uninstall Norfurch"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-2]: ${NC}"
        read choice
        
        case $choice in
            1) install_norfurch ;;
            2) uninstall_norfurch ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"
        read
    done
}

# Main menu
main_menu() {
    while true; do
        show_header
        show_info
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    PTERODACTYL INSTALLATION${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1)${NC} Install Everything (Full Pterodactyl Suite)"
        echo -e "  ${GREEN}2)${NC} Install Pterodactyl Panel Only"
        echo -e "  ${GREEN}3)${NC} Install Pterodactyl Wings Only"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    ADDITIONAL TOOLS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}4)${NC} 📦 Node.js Manager (Install/Uninstall)"
        echo -e "  ${GREEN}5)${NC} 🔒 Tailscale VPN Manager (Install/Uninstall/Connect)"
        echo -e "  ${GREEN}6)${NC} ☁️  Cloudflared Manager (Install/Uninstall/Tunnels)"
        echo -e "  ${GREEN}7)${NC} 🖥️  RDP Manager (Install/Uninstall)"
        echo -e "  ${GREEN}8)${NC} 📊 Norfurch Manager (Install/Uninstall)"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}0)${NC} Exit"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "${WHITE}Enter your choice [0-8]: ${NC}"
        read choice
        
        case $choice in
            1)
                update_system
                install_dependencies
                setup_mysql
                install_pterodactyl_panel
                configure_nginx
                install_pterodactyl_wings
                echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${GREEN}✓ Full Pterodactyl installation completed!${NC}"
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Panel Access: http://$(curl -s ifconfig.me)${NC}"
                echo -e "${YELLOW}Admin Login: admin@localhost / password123${NC}"
                echo -e "${YELLOW}DB Credentials: /root/pterodactyl_db_credentials.txt${NC}"
                echo -e "${YELLOW}Wings Config: /etc/pterodactyl/config.yml${NC}"
                ;;
            2)
                update_system
                install_dependencies
                setup_mysql
                install_pterodactyl_panel
                configure_nginx
                echo -e "\n${GREEN}✓ Pterodactyl Panel installed!${NC}"
                echo -e "${YELLOW}Access at: http://$(curl -s ifconfig.me)${NC}"
                echo -e "${YELLOW}Admin Login: admin@localhost / password123${NC}"
                ;;
            3)
                update_system
                install_dependencies
                install_pterodactyl_wings
                ;;
            4) node_menu ;;
            5) tailscale_menu ;;
            6) cloudflared_menu ;;
            7) rdp_menu ;;
            8) norfurch_menu ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 2
                ;;
        esac
        
        if [[ $choice -ge 1 && $choice -le 3 ]]; then
            echo ""
            echo -ne "${WHITE}Press Enter to continue...${NC}"
            read
        fi
    done
}

# Start
check_root
detect_os
main_menu
