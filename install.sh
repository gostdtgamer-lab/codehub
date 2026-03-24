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

# Install Tailscale
install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh >> "$LOG_FILE" 2>&1
    success "Tailscale installed"
    
    echo -e "\n  ${YELLOW}Tailscale Setup${NC}"
    echo -ne "  ${WHITE}├─ Start Tailscale? (y/n): ${NC}"
    read start_ts
    if [[ "$start_ts" == "y" ]]; then
        echo -ne "  ${WHITE}├─ Auth key (optional): ${NC}"
        read ts_key
        if [[ -n "$ts_key" ]]; then
            tailscale up --auth-key "$ts_key" >> "$LOG_FILE" 2>&1
        else
            tailscale up >> "$LOG_FILE" 2>&1
        fi
        success "Tailscale started"
        tailscale status
    fi
}

# Install Cloudflared
install_cloudflared() {
    log "Installing Cloudflared..."
    
    # Add cloudflared repo
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >> "$LOG_FILE" 2>&1
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list >> "$LOG_FILE" 2>&1
    
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y cloudflared >> "$LOG_FILE" 2>&1
    
    success "Cloudflared installed: $(cloudflared version)"
    
    echo -e "\n  ${YELLOW}Cloudflare Tunnel Setup${NC}"
    echo -e "  ${WHITE}├─ You need to authenticate with Cloudflare${NC}"
    echo -ne "  ${WHITE}├─ Press Enter to start authentication...${NC}"
    read
    
    cloudflared tunnel login
    
    echo -ne "  ${WHITE}├─ Enter tunnel name: ${NC}"
    read tunnel_name
    
    cloudflared tunnel create "$tunnel_name"
    
    echo -ne "  ${WHITE}├─ Enter hostname (e.g., panel.example.com): ${NC}"
    read hostname
    
    cloudflared tunnel route dns "$tunnel_name" "$hostname"
    
    mkdir -p /root/.cloudflared
    cat > /root/.cloudflared/config.yml << EOF
tunnel: $tunnel_name
credentials-file: /root/.cloudflared/${tunnel_name}.json

ingress:
  - hostname: $hostname
    service: http://localhost:80
  - service: http_status:404
EOF
    
    echo -e "\n  ${GREEN}✓ Cloudflare tunnel configured!${NC}"
    echo -e "  ${WHITE}├─ Run: cloudflared tunnel run $tunnel_name${NC}"
    echo -e "  ${WHITE}└─ Or install as service: cloudflared service install${NC}"
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
        echo -e "  ${GREEN}4)${NC} Install Node.js"
        echo -e "  ${GREEN}5)${NC} Install Tailscale VPN"
        echo -e "  ${GREEN}6)${NC} Install Cloudflared (with token setup)"
        echo -e "  ${GREEN}7)${NC} Install RDP (Remote Desktop)"
        echo -e "  ${GREEN}8)${NC} Install Norfurch (Monitoring Tools)"
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
            4)
                update_system
                install_node
                ;;
            5)
                update_system
                install_tailscale
                ;;
            6)
                update_system
                install_cloudflared
                ;;
            7)
                update_system
                install_rdp
                ;;
            8)
                update_system
                install_norfurch
                ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 2
                ;;
        esac
        
        if [[ $choice -ge 1 && $choice -le 8 ]]; then
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
