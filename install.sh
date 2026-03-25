#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER PTERODACTYL DEPLOYMENT SUITE
# Full Pterodactyl Panel + Node Management + Auto/Manual Setup
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
HYPER_V1_PASS="312010"
PTERO_DIR="/var/www/pterodactyl"
PANEL_URL=""
ADMIN_EMAIL=""
ADMIN_USERNAME=""
ADMIN_PASSWORD=""
NODE_NAME=""
NODE_DOMAIN=""

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
    echo -e "${PURPLE}│${NC}  ${RED}☢️  GOSTDTGAMER PTERODACTYL SUITE${NC} ${GREEN}v3.0${NC}              ${CYAN}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
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
    
    apt-get install -y php8.2 php8.2-cli php8.2-common php8.2-curl \
        php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml \
        php8.2-fpm php8.2-zip php8.2-redis >> "$LOG_FILE" 2>&1
    
    curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1
    systemctl enable docker
    systemctl start docker
    
    success "Dependencies installed"
}

# Setup MySQL
setup_mysql() {
    log "Setting up MySQL database..."
    
    MYSQL_ROOT_PASS=$(openssl rand -base64 16)
    MYSQL_PTERO_PASS=$(openssl rand -base64 16)
    
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
    mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS panel;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PTERO_PASS}';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
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

# Configure Panel Domain
configure_panel_domain() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🌐 CONFIGURE PANEL DOMAIN${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "  ${WHITE}Enter your panel domain (e.g., panel.example.com): ${NC}"
    read PANEL_URL
    
    if [[ -z "$PANEL_URL" ]]; then
        IP_PUBLIC=$(curl -s ifconfig.me)
        PANEL_URL="http://$IP_PUBLIC"
        echo -e "  ${YELLOW}Using IP: $PANEL_URL${NC}"
    else
        PANEL_URL="http://$PANEL_URL"
    fi
}

# Create Admin User
create_admin_user() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}👤 CREATE ADMIN USER${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "  ${WHITE}Admin Email: ${NC}"
    read ADMIN_EMAIL
    
    if [[ -z "$ADMIN_EMAIL" ]]; then
        ADMIN_EMAIL="admin@localhost"
        echo -e "  ${YELLOW}Using default: $ADMIN_EMAIL${NC}"
    fi
    
    echo -ne "  ${WHITE}Admin Username: ${NC}"
    read ADMIN_USERNAME
    
    if [[ -z "$ADMIN_USERNAME" ]]; then
        ADMIN_USERNAME="admin"
        echo -e "  ${YELLOW}Using default: $ADMIN_USERNAME${NC}"
    fi
    
    echo -ne "  ${WHITE}Admin Password: ${NC}"
    read -s ADMIN_PASSWORD
    echo ""
    
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD="password123"
        echo -e "  ${YELLOW}Using default: password123${NC}"
    fi
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
    
    chmod -R 755 storage/* bootstrap/cache
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> "$LOG_FILE" 2>&1
    cp .env.example .env
    composer install --no-dev --optimize-autoloader >> "$LOG_FILE" 2>&1
    php artisan key:generate --force >> "$LOG_FILE" 2>&1
    php artisan p:environment:setup --author="$ADMIN_EMAIL" --url="$PANEL_URL" --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 --no-interaction >> "$LOG_FILE" 2>&1 || true
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}" --no-interaction >> "$LOG_FILE" 2>&1 || true
    php artisan migrate --seed --force >> "$LOG_FILE" 2>&1
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first=Admin --name-last=User --password="$ADMIN_PASSWORD" --admin=1 --no-interaction >> "$LOG_FILE" 2>&1 || true
    chown -R www-data:www-data /var/www/pterodactyl/*
    
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
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    success "Pterodactyl Panel installed"
}

# Configure Nginx with Domain
configure_nginx() {
    log "Configuring Nginx with domain..."
    
    # Extract domain without http://
    DOMAIN=$(echo "$PANEL_URL" | sed 's|http://||' | sed 's|https://||')
    
    cat > /etc/nginx/sites-available/pterodactyl.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
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
    
    success "Nginx configured for $DOMAIN"
}

# Uninstall Pterodactyl Panel
uninstall_pterodactyl() {
    echo -e "\n  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${RED}⚠️  UNINSTALL PTERODACTYL${NC}"
    echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "  ${RED}Are you sure you want to uninstall Pterodactyl? (y/n): ${NC}"
    read confirm
    
    if [[ "$confirm" != "y" ]]; then
        echo -e "  ${YELLOW}Cancelled${NC}"
        return
    fi
    
    log "Uninstalling Pterodactyl..."
    
    # Stop services
    systemctl stop pteroq 2>/dev/null || true
    systemctl stop wings 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    # Remove files
    rm -rf /var/www/pterodactyl
    rm -rf /etc/pterodactyl
    rm -f /etc/nginx/sites-available/pterodactyl.conf
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/systemd/system/pteroq.service
    rm -f /etc/systemd/system/wings.service
    
    # Remove MySQL database
    mysql -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
    mysql -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';" 2>/dev/null || true
    
    # Remove Docker images
    docker system prune -af 2>/dev/null || true
    
    success "Pterodactyl uninstalled"
    echo -e "  ${GREEN}✓ All Pterodactyl files and databases removed${NC}"
}

# ==================== NODE MANAGEMENT ====================

# Auto Deploy Node
auto_deploy_node() {
    log "Auto Deploying Node..."
    
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🚀 AUTO DEPLOY NODE${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get node information
    echo -ne "  ${WHITE}Node Name: ${NC}"
    read NODE_NAME
    
    if [[ -z "$NODE_NAME" ]]; then
        NODE_NAME="node1"
        echo -e "  ${YELLOW}Using default: $NODE_NAME${NC}"
    fi
    
    echo -ne "  ${WHITE}Node Domain/IP (e.g., node.example.com or IP): ${NC}"
    read NODE_DOMAIN
    
    if [[ -z "$NODE_DOMAIN" ]]; then
        NODE_DOMAIN=$(curl -s ifconfig.me)
        echo -e "  ${YELLOW}Using IP: $NODE_DOMAIN${NC}"
    fi
    
    # Get API credentials from panel
    echo -e "\n  ${CYAN}Get these from your Pterodactyl Panel:${NC}"
    echo -e "  ${WHITE}1. Go to Admin Panel → Nodes → Create New${NC}"
    echo -e "  ${WHITE}2. Enter node details and save${NC}"
    echo -e "  ${WHITE}3. Get the configuration token from the node page${NC}"
    echo ""
    
    echo -ne "  ${GREEN}► Enter Node UUID: ${NC}"
    read NODE_UUID
    
    echo -ne "  ${GREEN}► Enter Node Token: ${NC}"
    read NODE_TOKEN
    
    echo -ne "  ${GREEN}► Enter Panel URL (e.g., http://your-panel.com): ${NC}"
    read PANEL_URL_NODE
    
    if [[ -z "$NODE_UUID" ]] || [[ -z "$NODE_TOKEN" ]] || [[ -z "$PANEL_URL_NODE" ]]; then
        echo -e "  ${RED}Missing required information!${NC}"
        return
    fi
    
    # Create config directory
    mkdir -p /etc/pterodactyl
    
    # Create Wings config
    cat > /etc/pterodactyl/config.yml << EOF
debug: false
uuid: $NODE_UUID
token_id: $(echo "$NODE_TOKEN" | cut -d'.' -f1 2>/dev/null || echo "token")
token: $(echo "$NODE_TOKEN" | cut -d'.' -f2- 2>/dev/null || echo "$NODE_TOKEN")
api:
  host: $PANEL_URL_NODE
  port: 443
  ssl: true
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
  uploads:
    enabled: true
  disks:
    - /var/lib/pterodactyl/volumes
allowed_mounts: []
remote: 'https://$PANEL_URL_NODE'
EOF
    
    # Download Wings
    echo -e "  ${WHITE}Downloading Wings...${NC}"
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    
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
    systemctl start wings
    
    sleep 3
    
    if systemctl is-active --quiet wings; then
        success "Node deployed successfully!"
        echo -e "\n  ${GREEN}Node Information:${NC}"
        echo -e "  ${WHITE}Name: $NODE_NAME${NC}"
        echo -e "  ${WHITE}Domain: $NODE_DOMAIN${NC}"
        echo -e "  ${WHITE}Status: Running${NC}"
        echo -e "\n  ${YELLOW}Wings Commands:${NC}"
        echo -e "  Status: systemctl status wings"
        echo -e "  Stop:   systemctl stop wings"
        echo -e "  Start:  systemctl start wings"
        echo -e "  Logs:   journalctl -u wings -f"
    else
        echo -e "  ${RED}Failed to start Wings. Check logs:${NC}"
        journalctl -u wings -n 20 --no-pager
    fi
}

# Manual Node Setup
manual_node_setup() {
    log "Manual Node Setup..."
    
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🔧 MANUAL NODE SETUP${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "  ${WHITE}Follow these steps to set up a node:${NC}"
    echo -e "  ${CYAN}1. In your Pterodactyl Panel, go to Admin → Nodes${NC}"
    echo -e "  ${CYAN}2. Click 'Create New' and fill in the details${NC}"
    echo -e "  ${CYAN}3. After creating, click on the node and go to 'Configuration'${NC}"
    echo -e "  ${CYAN}4. Copy the configuration token${NC}"
    echo -e "  ${CYAN}5. Run the command below on this server:${NC}"
    echo ""
    
    echo -e "  ${GREEN}wings -c /etc/pterodactyl/config.yml${NC}"
    echo ""
    
    echo -ne "  ${WHITE}Enter your Node UUID: ${NC}"
    read NODE_UUID
    
    echo -ne "  ${WHITE}Enter your Node Token: ${NC}"
    read NODE_TOKEN
    
    echo -ne "  ${WHITE}Enter Panel URL (with https://): ${NC}"
    read PANEL_URL_NODE
    
    if [[ -n "$NODE_UUID" ]] && [[ -n "$NODE_TOKEN" ]] && [[ -n "$PANEL_URL_NODE" ]]; then
        mkdir -p /etc/pterodactyl
        cat > /etc/pterodactyl/config.yml << EOF
debug: false
uuid: $NODE_UUID
token_id: $(echo "$NODE_TOKEN" | cut -d'.' -f1)
token: $(echo "$NODE_TOKEN" | cut -d'.' -f2-)
api:
  host: $(echo "$PANEL_URL_NODE" | sed 's|https://||' | sed 's|http://||')
  port: 443
  ssl: true
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
EOF
        echo -e "  ${GREEN}✓ Configuration saved to /etc/pterodactyl/config.yml${NC}"
        
        if ! command -v wings &> /dev/null; then
            echo -e "  ${WHITE}Installing Wings...${NC}"
            curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
            chmod u+x /usr/local/bin/wings
        fi
        
        echo -e "\n  ${YELLOW}Start Wings with:${NC}"
        echo -e "  ${GREEN}wings -c /etc/pterodactyl/config.yml${NC}"
    fi
}

# Configure Node with UUID and Token
configure_node_with_credentials() {
    log "Configuring Node with credentials..."
    
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🔧 NODE CREDENTIALS SETUP${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "  ${WHITE}From your Pterodactyl Panel:${NC}"
    echo -e "  ${CYAN}1. Go to Admin → Nodes → Your Node${NC}"
    echo -e "  ${CYAN}2. Click on 'Configuration' tab${NC}"
    echo -e "  ${CYAN}3. You'll see the UUID and Token${NC}"
    echo ""
    
    echo -ne "  ${GREEN}► Enter Node UUID: ${NC}"
    read NODE_UUID
    
    echo -ne "  ${GREEN}► Enter Node Token: ${NC}"
    read NODE_TOKEN
    
    echo -ne "  ${GREEN}► Enter Panel URL (e.g., https://panel.example.com): ${NC}"
    read PANEL_URL_NODE
    
    if [[ -z "$NODE_UUID" ]] || [[ -z "$NODE_TOKEN" ]] || [[ -z "$PANEL_URL_NODE" ]]; then
        echo -e "  ${RED}All fields are required!${NC}"
        return
    fi
    
    # Create config directory
    mkdir -p /etc/pterodactyl
    
    # Create Wings config
    cat > /etc/pterodactyl/config.yml << EOF
debug: false
uuid: $NODE_UUID
token_id: $(echo "$NODE_TOKEN" | cut -d'.' -f1)
token: $(echo "$NODE_TOKEN" | cut -d'.' -f2-)
api:
  host: $(echo "$PANEL_URL_NODE" | sed 's|https://||' | sed 's|http://||')
  port: 443
  ssl: true
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
  uploads:
    enabled: true
  disks:
    - /var/lib/pterodactyl/volumes
allowed_mounts: []
remote: '$PANEL_URL_NODE'
EOF
    
    # Create directories
    mkdir -p /var/lib/pterodactyl/volumes
    chmod -R 755 /var/lib/pterodactyl
    
    # Install Wings if not installed
    if ! command -v wings &> /dev/null; then
        echo -e "  ${WHITE}Installing Wings...${NC}"
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
        chmod u+x /usr/local/bin/wings
    fi
    
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
    
    systemctl daemon-reload
    systemctl enable wings
    
    echo -e "\n  ${GREEN}✓ Configuration saved to /etc/pterodactyl/config.yml${NC}"
    echo -e "\n  ${YELLOW}Start Wings with:${NC}"
    echo -e "  ${GREEN}systemctl start wings${NC}"
    echo -e "  ${WHITE}or${NC}"
    echo -e "  ${GREEN}wings -c /etc/pterodactyl/config.yml${NC}"
}

# ==================== NODE MENU ====================

node_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    NODE MANAGEMENT${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if Wings is installed
        if command -v wings &> /dev/null; then
            echo -e "  ${GREEN}Wings: INSTALLED${NC}"
            if systemctl is-active --quiet wings 2>/dev/null; then
                echo -e "  ${GREEN}Status: RUNNING ✓${NC}"
            else
                echo -e "  ${YELLOW}Status: NOT RUNNING${NC}"
            fi
        else
            echo -e "  ${RED}Wings: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Auto Deploy Node (with UUID & Token)"
        echo -e "  ${GREEN}2)${NC} Manual Node Setup (Guided)"
        echo -e "  ${GREEN}3)${NC} Configure Node with UUID & Token"
        echo -e "  ${GREEN}4)${NC} Start Wings Service"
        echo -e "  ${GREEN}5)${NC} Stop Wings Service"
        echo -e "  ${GREEN}6)${NC} Restart Wings Service"
        echo -e "  ${GREEN}7)${NC} View Wings Logs"
        echo -e "  ${GREEN}8)${NC} Check Node Status"
        echo -e "  ${RED}9)${NC} Uninstall Wings"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) auto_deploy_node ;;
            2) manual_node_setup ;;
            3) configure_node_with_credentials ;;
            4) systemctl start wings 2>/dev/null && echo -e "${GREEN}Wings started${NC}" || echo -e "${RED}Failed to start${NC}" ;;
            5) systemctl stop wings 2>/dev/null && echo -e "${GREEN}Wings stopped${NC}" ;;
            6) systemctl restart wings 2>/dev/null && echo -e "${GREEN}Wings restarted${NC}" ;;
            7) journalctl -u wings -n 50 --no-pager ;;
            8) 
                if systemctl is-active --quiet wings; then
                    echo -e "${GREEN}Wings is running${NC}"
                    wings -c /etc/pterodactyl/config.yml -debug 2>&1 | head -20
                else
                    echo -e "${RED}Wings is not running${NC}"
                fi
                ;;
            9)
                echo -ne "${RED}Uninstall Wings? (y/n): ${NC}"
                read confirm
                if [[ "$confirm" == "y" ]]; then
                    systemctl stop wings 2>/dev/null || true
                    systemctl disable wings 2>/dev/null || true
                    rm -f /usr/local/bin/wings
                    rm -f /etc/systemd/system/wings.service
                    rm -rf /etc/pterodactyl
                    rm -rf /var/lib/pterodactyl
                    echo -e "${GREEN}Wings uninstalled${NC}"
                fi
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

# ==================== PTERODACTYL PANEL MENU ====================

panel_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    PTERODACTYL PANEL MANAGEMENT${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Check if Pterodactyl is installed
        if [[ -d "$PTERO_DIR" ]]; then
            echo -e "  ${GREEN}Panel: INSTALLED${NC}"
            if systemctl is-active --quiet nginx; then
                echo -e "  ${GREEN}Web Server: RUNNING ✓${NC}"
            fi
            echo -e "  ${WHITE}URL: $PANEL_URL${NC}"
        else
            echo -e "  ${RED}Panel: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Pterodactyl Panel (Full Setup)"
        echo -e "  ${GREEN}2)${NC} Install Pterodactyl Wings Only"
        echo -e "  ${GREEN}3)${NC} Configure Panel Domain"
        echo -e "  ${GREEN}4)${NC} Create Admin User"
        echo -e "  ${GREEN}5)${NC} View Panel Information"
        echo -e "  ${RED}6)${NC} Uninstall Pterodactyl Panel"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1)
                update_system
                install_dependencies
                setup_mysql
                configure_panel_domain
                create_admin_user
                install_pterodactyl_panel
                configure_nginx
                echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${GREEN}✓ Pterodactyl Panel installation completed!${NC}"
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Panel Access: $PANEL_URL${NC}"
                echo -e "${YELLOW}Admin Login: $ADMIN_USERNAME / $ADMIN_PASSWORD${NC}"
                echo -e "${YELLOW}DB Credentials: /root/pterodactyl_db_credentials.txt${NC}"
                ;;
            2)
                update_system
                install_dependencies
                echo -e "\n${GREEN}✓ Pterodactyl Wings installed!${NC}"
                echo -e "${YELLOW}Configure node using Node Management menu${NC}"
                ;;
            3) configure_panel_domain ;;
            4) create_admin_user ;;
            5)
                echo -e "\n${CYAN}Panel Information:${NC}"
                echo -e "  URL: $PANEL_URL"
                echo -e "  Admin: $ADMIN_USERNAME"
                echo -e "  DB Credentials: /root/pterodactyl_db_credentials.txt"
                ;;
            6) uninstall_pterodactyl ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

# ==================== MAIN MENU ====================

main_menu() {
    while true; do
        show_header
        show_info
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    MAIN MENU${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1)${NC} 📦 Pterodactyl Panel Management"
        echo -e "  ${GREEN}2)${NC} 🖥️  Node Management (Wings)"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    ADDITIONAL TOOLS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}3)${NC} 📦 Node.js Manager"
        echo -e "  ${GREEN}4)${NC} 🔒 Tailscale VPN Manager (with Auth Key)"
        echo -e "  ${GREEN}5)${NC} ☁️  Cloudflared Manager (with Token)"
        echo -e "  ${GREEN}6)${NC} 🖥️  RDP Manager"
        echo -e "  ${GREEN}7)${NC} 📊 Norfurch Manager"
        echo -e "  ${GREEN}8)${NC} 🎨 Pterodactyl Extras (Blueprint, Themes, Addons)"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}0)${NC} Exit"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "${WHITE}Enter your choice [0-8]: ${NC}"
        read choice
        
        case $choice in
            1) panel_menu ;;
            2) node_menu ;;
            3) node_menu_simple ;;
            4) tailscale_menu ;;
            5) cloudflared_menu ;;
            6) rdp_menu ;;
            7) norfurch_menu ;;
            8) pterodactyl_extras_menu ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Simple Node.js menu
node_menu_simple() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    NODE.JS MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if command -v node &> /dev/null; then
            echo -e "  ${GREEN}Status: INSTALLED - Version: $(node -v)${NC}"
        else
            echo -e "  ${RED}Status: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Node.js"
        echo -e "  ${RED}2)${NC} Uninstall Node.js"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) 
                log "Installing Node.js..."
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >> "$LOG_FILE" 2>&1
                apt-get install -y nodejs >> "$LOG_FILE" 2>&1
                success "Node.js installed: $(node -v)"
                ;;
            2)
                log "Uninstalling Node.js..."
                apt-get remove -y nodejs >> "$LOG_FILE" 2>&1
                apt-get autoremove -y >> "$LOG_FILE" 2>&1
                success "Node.js uninstalled"
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

# Include other menus from previous script (tailscale_menu, cloudflared_menu, rdp_menu, norfurch_menu, pterodactyl_extras_menu)
# [Previous menu functions would go here - they remain the same as in the previous script]

# Start
check_root
detect_os
main_menu
