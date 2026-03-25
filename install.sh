#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER PTERODACTYL DEPLOYMENT SUITE
# Full Pterodactyl Panel + Blueprint + Themes + Addons
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Please run as root (use sudo)"
    fi
}

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
    echo -e "${PURPLE}│${NC}  ${RED}☢️  GOSTDTGAMER PTERODACTYL SUITE${NC} ${GREEN}v4.0${NC}              ${CYAN}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${GREEN}                   POWERED BY GOSTDTGAMER${NC}"
    echo ""
}

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

# ==================== PHP 8.2 INSTALL ====================

install_php82() {
    echo -e "\n  ${WHITE}Installing PHP 8.2...${NC}"
    
    apt-get install -y software-properties-common >> "$LOG_FILE" 2>&1
    add-apt-repository -y ppa:ondrej/php >> "$LOG_FILE" 2>&1
    apt-get update -y >> "$LOG_FILE" 2>&1
    
    apt-get install -y php8.2 php8.2-cli php8.2-common php8.2-curl \
        php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml \
        php8.2-fpm php8.2-zip php8.2-redis php8.2-intl php8.2-tokenizer >> "$LOG_FILE" 2>&1
    
    PHP_VERSION=$(php -v | head -1 | cut -d' ' -f2 | cut -d'.' -f1-2)
    if [[ "$PHP_VERSION" != "8.2" ]]; then
        error "PHP 8.2 installation failed! Current version: $PHP_VERSION"
    fi
    
    success "PHP 8.2 installed: $(php -v | head -1)"
}

# ==================== PTERODACTYL PANEL INSTALL ====================

update_system() {
    log "Updating system packages..."
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    success "System updated"
}

install_dependencies() {
    log "Installing dependencies..."
    apt-get install -y curl wget git nginx mysql-server redis-server \
        tar unzip zip gzip ca-certificates gnupg lsb-release \
        software-properties-common >> "$LOG_FILE" 2>&1
    
    install_php82
    
    curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1
    systemctl enable docker
    systemctl start docker
    
    success "Dependencies installed"
}

setup_mysql() {
    log "Setting up MySQL database..."
    
    MYSQL_ROOT_PASS=$(openssl rand -base64 16)
    MYSQL_PTERO_PASS=$(openssl rand -base64 16)
    
    systemctl start mysql 2>/dev/null || true
    
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
    
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
}

download_panel() {
    echo -e "\n  ${WHITE}Downloading Pterodactyl Panel...${NC}"
    
    cd /var/www
    rm -rf pterodactyl panel.tar.gz 2>/dev/null || true
    
    if wget --tries=3 --timeout=30 -O panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz 2>/dev/null; then
        echo -e "  ${GREEN}Downloaded via wget${NC}"
    elif curl -L -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz 2>/dev/null; then
        echo -e "  ${GREEN}Downloaded via curl${NC}"
    else
        error "Failed to download panel"
    fi
    
    tar -xzf panel.tar.gz
    EXTRACTED_DIR=$(ls -d panel-* 2>/dev/null | head -1)
    mv "$EXTRACTED_DIR" pterodactyl
    rm -f panel.tar.gz
    
    success "Panel downloaded"
}

configure_panel() {
    echo -e "\n  ${WHITE}Configuring Panel...${NC}"
    
    cd /var/www/pterodactyl
    chmod -R 755 storage/* bootstrap/cache
    
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> "$LOG_FILE" 2>&1
    cp .env.example .env
    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --ignore-platform-reqs >> "$LOG_FILE" 2>&1
    
    php artisan key:generate --force >> "$LOG_FILE" 2>&1
    php artisan p:environment:setup --author="$ADMIN_EMAIL" --url="$PANEL_URL" --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 --no-interaction >> "$LOG_FILE" 2>&1 || true
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}" --no-interaction >> "$LOG_FILE" 2>&1 || true
    php artisan migrate --seed --force >> "$LOG_FILE" 2>&1
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first=Admin --name-last=User --password="$ADMIN_PASSWORD" --admin=1 --no-interaction >> "$LOG_FILE" 2>&1 || true
    
    chown -R www-data:www-data /var/www/pterodactyl/*
    
    success "Panel configured"
}

configure_nginx() {
    echo -e "\n  ${WHITE}Configuring Nginx...${NC}"
    
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
    
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
    
    success "Nginx configured"
}

# ==================== BLUEPRINT INSTALL ====================

install_blueprint() {
    log "Installing Blueprint..."
    
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}📦 INSTALLING BLUEPRINT${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "  ${RED}Error: Pterodactyl Panel not found! Please install Pterodactyl first.${NC}"
        return 1
    fi
    
    cd $PTERO_DIR
    
    echo -e "  ${WHITE}Downloading Blueprint...${NC}"
    curl -L -o blueprint.tar.gz https://github.com/BlueprintFramework/framework/releases/latest/download/blueprint.tar.gz
    tar -xzvf blueprint.tar.gz >> "$LOG_FILE" 2>&1
    
    echo -e "  ${WHITE}Installing Blueprint...${NC}"
    chmod +x blueprint.sh
    ./blueprint.sh install >> "$LOG_FILE" 2>&1
    
    success "Blueprint installed successfully!"
    echo -e "\n  ${GREEN}Blueprint is now installed!${NC}"
    echo -e "  ${WHITE}Access Blueprint at: ${CYAN}http://$(echo "$PANEL_URL" | sed 's|http://||')/blueprint${NC}"
}

# ==================== NEBULA THEME INSTALL ====================

install_nebula_theme() {
    log "Installing Nebula Theme..."
    
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🌌 INSTALLING NEBULA THEME${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "  ${RED}Error: Pterodactyl Panel not found! Please install Pterodactyl first.${NC}"
        return 1
    fi
    
    cd $PTERO_DIR
    
    echo -e "  ${WHITE}Creating backup...${NC}"
    cp -r resources/views resources/views.backup 2>/dev/null || true
    cp -r public/themes public/themes.backup 2>/dev/null || true
    
    echo -e "  ${WHITE}Downloading Nebula Theme...${NC}"
    curl -L -o nebula.zip https://github.com/WilliamTeder/nebula/releases/latest/download/nebula.zip
    unzip -o nebula.zip >> "$LOG_FILE" 2>&1
    
    echo -e "  ${WHITE}Installing dependencies...${NC}"
    npm install >> "$LOG_FILE" 2>&1
    npm run production >> "$LOG_FILE" 2>&1
    
    echo -e "  ${WHITE}Installing Nebula Theme...${NC}"
    php artisan nebula:install >> "$LOG_FILE" 2>&1 || true
    
    php artisan view:clear
    php artisan cache:clear
    
    success "Nebula Theme installed successfully!"
    echo -e "\n  ${GREEN}Nebula Theme is now active!${NC}"
}

# ==================== ADDONS INSTALL ====================

install_addon_server_transfer() {
    log "Installing Server Transfer Addon..."
    
    cd $PTERO_DIR
    
    echo -e "  ${WHITE}Installing Server Transfer Addon...${NC}"
    composer require pterodactyl-china/server-transfer --ignore-platform-reqs >> "$LOG_FILE" 2>&1
    php artisan migrate >> "$LOG_FILE" 2>&1
    php artisan view:clear
    
    success "Server Transfer Addon installed!"
}

install_addon_backup_manager() {
    log "Installing Backup Manager Addon..."
    
    cd $PTERO_DIR
    
    echo -e "  ${WHITE}Installing Backup Manager Addon...${NC}"
    composer require pterodactyl/panel-backups --ignore-platform-reqs >> "$LOG_FILE" 2>&1
    php artisan migrate >> "$LOG_FILE" 2>&1
    
    success "Backup Manager Addon installed!"
}

install_addon_resource_monitor() {
    log "Installing Resource Monitor Addon..."
    
    cd $PTERO_DIR
    
    echo -e "  ${WHITE}Installing Resource Monitor Addon...${NC}"
    composer require adriankoshka/resource-monitor --ignore-platform-reqs >> "$LOG_FILE" 2>&1
    php artisan migrate >> "$LOG_FILE" 2>&1
    
    success "Resource Monitor Addon installed!"
}

install_addon_discord_integration() {
    log "Installing Discord Integration Addon..."
    
    cd $PTERO_DIR
    
    echo -e "  ${WHITE}Installing Discord Integration Addon...${NC}"
    composer require avisi/pterodactyl-discord-integration --ignore-platform-reqs >> "$LOG_FILE" 2>&1
    php artisan migrate >> "$LOG_FILE" 2>&1
    
    success "Discord Integration Addon installed!"
}

# ==================== THEMES MENU ====================

themes_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    PTERODACTYL THEMES${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${GREEN}  [ 1 ]${NC} Nebula Theme ${CYAN}(Working)${NC}"
        echo -e "  ${YELLOW}  [ 2 ]${NC} Euphoria ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 3 ]${NC} BetterAdmin ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 4 ]${NC} Abysspurple ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 5 ]${NC} Amberabyss ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 6 ]${NC} Catppuccindactyl ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 7 ]${NC} Crimsonabyss ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 8 ]${NC} Emeraldabyss ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [ 9 ]${NC} Refreshtheme ${RED}(Coming Soon)${NC}"
        echo -e "  ${YELLOW}  [10]${NC} slice ${RED}(Coming Soon)${NC}"
        echo ""
        echo -ne "${WHITE}Select theme to install [1-10]: ${NC}"
        read theme_choice
        
        case $theme_choice in
            1) install_nebula_theme ;;
            2|3|4|5|6|7|8|9|10)
                echo -e "\n  ${RED}⚠️  Theme coming soon!${NC}"
                sleep 2
                ;;
            *) echo -e "${RED}Invalid choice${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

# ==================== ADDONS MENU ====================

addons_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    PTERODACTYL ADDONS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} Server Transfer Addon"
        echo -e "  ${GREEN}2)${NC} Backup Manager Addon"
        echo -e "  ${GREEN}3)${NC} Resource Monitor Addon"
        echo -e "  ${GREEN}4)${NC} Discord Integration Addon"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Select addon to install: ${NC}"
        read addon_choice
        
        case $addon_choice in
            1) install_addon_server_transfer ;;
            2) install_addon_backup_manager ;;
            3) install_addon_resource_monitor ;;
            4) install_addon_discord_integration ;;
            0) break ;;
            *) echo -e "${RED}Invalid choice${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

# ==================== HYPER V1 THEME ====================

hyper_v1_menu() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🚀 HYPER V1 THEME${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -ne "  ${YELLOW}Enter password to access Hyper V1: ${NC}"
    read -s pass
    echo ""
    
    if [[ "$pass" == "$HYPER_V1_PASS" ]]; then
        echo -e "\n  ${GREEN}✓ Access granted!${NC}"
        echo -e "\n  ${CYAN}Hyper V1 Theme Options:${NC}"
        echo -e "  ${GREEN}  [ 1 ]${NC} Install Hyper V1 Theme"
        echo -e "  ${GREEN}  [ 2 ]${NC} Configure Hyper V1 Settings"
        echo -e "  ${GREEN}  [ 3 ]${NC} Preview Theme"
        echo ""
        echo -ne "  ${WHITE}Select option: ${NC}"
        read hyper_choice
        
        case $hyper_choice in
            1)
                echo -e "\n  ${YELLOW}Installing Hyper V1 Theme...${NC}"
                echo -e "  ${RED}⚠️  Coming Soon!${NC}"
                ;;
            2)
                echo -e "\n  ${YELLOW}Configuration coming soon!${NC}"
                ;;
            3)
                echo -e "\n  ${CYAN}Preview: Hyper V1 Theme is a modern, sleek design${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
    else
        echo -e "\n  ${RED}✗ Access denied! Incorrect password.${NC}"
    fi
}

# ==================== PTERODACTYL EXTRAS MENU ====================

pterodactyl_extras_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}           PTERODACTYL EXTRAS (Themes & Addons)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Blueprint (Extension System) ${CYAN}[Working]${NC}"
        echo -e "  ${GREEN}2)${NC} Install Themes ${CYAN}[Nebula Working]${NC}"
        echo -e "  ${GREEN}3)${NC} Install Addons ${CYAN}[Working]${NC}"
        echo -e "  ${GREEN}4)${NC} 🚀 Hyper V1 Theme (Premium) ${CYAN}[Password Protected]${NC}"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-4]: ${NC}"
        read choice
        
        case $choice in
            1) install_blueprint ;;
            2) themes_menu ;;
            3) addons_menu ;;
            4) hyper_v1_menu ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

# ==================== NODE MANAGEMENT ====================

install_wings() {
    log "Installing Pterodactyl Wings..."
    
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🚀 INSTALLING PTERODACTYL WINGS${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1
    systemctl enable docker
    systemctl start docker
    
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    
    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes
    
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
    
    echo -e "\n  ${YELLOW}Configure your node:${NC}"
    echo -ne "  ${WHITE}Enter Panel URL (e.g., https://panel.example.com): ${NC}"
    read PANEL_URL_NODE
    echo -ne "  ${WHITE}Enter Node UUID: ${NC}"
    read NODE_UUID
    echo -ne "  ${WHITE}Enter Node Token: ${NC}"
    read NODE_TOKEN
    
    if [[ -n "$PANEL_URL_NODE" && -n "$NODE_UUID" && -n "$NODE_TOKEN" ]]; then
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
        
        systemctl start wings
        success "Wings configured and started!"
    else
        echo -e "  ${YELLOW}Wings installed but not configured. Edit /etc/pterodactyl/config.yml manually.${NC}"
    fi
}

# ==================== NODE MENU ====================

node_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    NODE MANAGEMENT (WINGS)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
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
        echo -e "  ${GREEN}1)${NC} Install Wings"
        echo -e "  ${GREEN}2)${NC} Start Wings"
        echo -e "  ${GREEN}3)${NC} Stop Wings"
        echo -e "  ${GREEN}4)${NC} Restart Wings"
        echo -e "  ${GREEN}5)${NC} View Wings Logs"
        echo -e "  ${RED}6)${NC} Uninstall Wings"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) install_wings ;;
            2) systemctl start wings 2>/dev/null && echo -e "${GREEN}Wings started${NC}" || echo -e "${RED}Not configured${NC}" ;;
            3) systemctl stop wings 2>/dev/null && echo -e "${GREEN}Wings stopped${NC}" ;;
            4) systemctl restart wings 2>/dev/null && echo -e "${GREEN}Wings restarted${NC}" ;;
            5) journalctl -u wings -n 50 --no-pager ;;
            6)
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

# ==================== PANEL MENU ====================

panel_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    PTERODACTYL PANEL MANAGEMENT${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if [[ -d "$PTERO_DIR" ]]; then
            echo -e "  ${GREEN}Panel: INSTALLED${NC}"
            echo -e "  ${WHITE}URL: $PANEL_URL${NC}"
        else
            echo -e "  ${RED}Panel: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Pterodactyl Panel"
        echo -e "  ${GREEN}2)${NC} View Panel Info"
        echo -e "  ${GREEN}3)${NC} 🎨 Pterodactyl Extras (Blueprint, Themes, Addons)"
        echo -e "  ${RED}4)${NC} Uninstall Pterodactyl Panel"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1)
                update_system
                install_dependencies
                setup_mysql
                
                echo -e "\n  ${YELLOW}Panel Configuration:${NC}"
                echo -ne "  ${WHITE}Panel Domain (press Enter for IP): ${NC}"
                read PANEL_URL
                if [[ -z "$PANEL_URL" ]]; then
                    PANEL_URL="http://$(curl -s ifconfig.me)"
                else
                    PANEL_URL="http://$PANEL_URL"
                fi
                
                echo -ne "  ${WHITE}Admin Email (default: admin@localhost): ${NC}"
                read ADMIN_EMAIL
                [[ -z "$ADMIN_EMAIL" ]] && ADMIN_EMAIL="admin@localhost"
                
                echo -ne "  ${WHITE}Admin Username (default: admin): ${NC}"
                read ADMIN_USERNAME
                [[ -z "$ADMIN_USERNAME" ]] && ADMIN_USERNAME="admin"
                
                echo -ne "  ${WHITE}Admin Password (default: password123): ${NC}"
                read -s ADMIN_PASSWORD
                echo ""
                [[ -z "$ADMIN_PASSWORD" ]] && ADMIN_PASSWORD="password123"
                
                download_panel
                configure_panel
                configure_nginx
                
                echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${GREEN}✓ PTERODACTYL PANEL INSTALLED SUCCESSFULLY!${NC}"
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Panel Access:${NC} $PANEL_URL"
                echo -e "${YELLOW}Admin Login:${NC} $ADMIN_USERNAME / $ADMIN_PASSWORD"
                echo -e "${YELLOW}DB Credentials:${NC} /root/pterodactyl_db_credentials.txt"
                ;;
            2)
                echo -e "\n${CYAN}Panel Information:${NC}"
                echo -e "  URL: $PANEL_URL"
                echo -e "  Admin: $ADMIN_USERNAME"
                echo -e "  DB: /root/pterodactyl_db_credentials.txt"
                ;;
            3) pterodactyl_extras_menu ;;
            4)
                echo -ne "${RED}Uninstall Pterodactyl? (y/n): ${NC}"
                read confirm
                if [[ "$confirm" == "y" ]]; then
                    systemctl stop pteroq wings nginx 2>/dev/null || true
                    rm -rf /var/www/pterodactyl /etc/pterodactyl
                    rm -f /etc/nginx/sites-available/pterodactyl.conf
                    rm -f /etc/nginx/sites-enabled/pterodactyl.conf
                    rm -f /etc/systemd/system/pteroq.service /etc/systemd/system/wings.service
                    mysql -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
                    echo -e "${GREEN}Pterodactyl uninstalled${NC}"
                fi
                ;;
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
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        echo -ne "${WHITE}Enter your choice: ${NC}"
        read choice
        
        case $choice in
            1) panel_menu ;;
            2) node_menu ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Start
check_root
detect_os
main_menu
