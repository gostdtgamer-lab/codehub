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
HYPER_V1_PASS="312010"

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
    echo -e "${PURPLE}│${NC}  ${RED}☢️  GOSTDTGAMER PTERODACTYL SUITE${NC} ${GREEN}v2.0${NC}              ${CYAN}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
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

# Install Pterodactyl Panel
install_pterodactyl_panel() {
    log "Installing Pterodactyl Panel..."
    
    cd /var/www
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
    php artisan p:environment:setup --author=admin@localhost --url=http://localhost --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379 --no-interaction >> "$LOG_FILE" 2>&1 || true
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}" --no-interaction >> "$LOG_FILE" 2>&1 || true
    php artisan migrate --seed --force >> "$LOG_FILE" 2>&1
    php artisan p:user:make --email=admin@localhost --username=admin --name-first=Admin --name-last=User --password=password123 --admin=1 --no-interaction >> "$LOG_FILE" 2>&1 || true
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
    
    useradd -r -d /var/lib/pterodactyl -m -s /bin/bash wings 2>/dev/null || true
    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/{tmp,archive,backups}
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 >> "$LOG_FILE" 2>&1
    chmod u+x /usr/local/bin/wings
    
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

# ==================== PTERODACTYL ADDONS ====================

install_blueprint() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}📦 BLUEPRINT INSTALLER${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${RED}⚠️  COMING SOON!${NC}"
    echo -e "  ${WHITE}Blueprint is a powerful extension system for Pterodactyl Panel${NC}"
    echo -e "  ${WHITE}It allows you to install themes, addons, and custom configurations${NC}"
    echo -e ""
    echo -e "  ${YELLOW}Expected features:${NC}"
    echo -e "  ${WHITE}├─ One-click theme installation${NC}"
    echo -e "  ${WHITE}├─ Addon marketplace${NC}"
    echo -e "  ${WHITE}├─ Custom egg management${NC}"
    echo -e "  ${WHITE}└─ Easy updates and backups${NC}"
    echo -e ""
    echo -e "  ${GREEN}Stay tuned for the next update!${NC}"
}

install_theme() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🎨 PTERODACTYL THEMES${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Available Themes:${NC}"
    echo -e "  ${GREEN}  [ 1 ]${NC} Nebula"
    echo -e "  ${GREEN}  [ 2 ]${NC} Euphoria"
    echo -e "  ${GREEN}  [ 3 ]${NC} BetterAdmin"
    echo -e "  ${GREEN}  [ 4 ]${NC} Abysspurple"
    echo -e "  ${GREEN}  [ 5 ]${NC} Amberabyss"
    echo -e "  ${GREEN}  [ 6 ]${NC} Catppuccindactyl"
    echo -e "  ${GREEN}  [ 7 ]${NC} Crimsonabyss"
    echo -e "  ${GREEN}  [ 8 ]${NC} Emeraldabyss"
    echo -e "  ${GREEN}  [ 9 ]${NC} Refreshtheme"
    echo -e "  ${GREEN}  [10]${NC} slice"
    echo -e "  ${YELLOW}  [11]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [12]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [13]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [14]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [15]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [16]${NC} Coming Soon"
    echo ""
    echo -ne "  ${WHITE}Select theme [1-16]: ${NC}"
    read theme_choice
    
    case $theme_choice in
        1|2|3|4|5|6|7|8|9|10)
            echo -e "\n  ${RED}⚠️  Theme installation coming soon!${NC}"
            echo -e "  ${YELLOW}This feature will be available in the next update${NC}"
            ;;
        11|12|13|14|15|16)
            echo -e "\n  ${YELLOW}⏳ Coming Soon!${NC}"
            echo -e "  ${WHITE}This theme is under development${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

install_addon() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🔌 PTERODACTYL ADDONS${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Available Addons:${NC}"
    echo -e "  ${GREEN}  [ 1 ]${NC} Server Transfer"
    echo -e "  ${GREEN}  [ 2 ]${NC} Backup Manager"
    echo -e "  ${GREEN}  [ 3 ]${NC} Resource Monitor"
    echo -e "  ${GREEN}  [ 4 ]${NC} Discord Integration"
    echo -e "  ${GREEN}  [ 5 ]${NC} Two-Factor Authentication"
    echo -e "  ${YELLOW}  [ 6 ]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [ 7 ]${NC} Coming Soon"
    echo -e "  ${YELLOW}  [ 8 ]${NC} Coming Soon"
    echo ""
    echo -ne "  ${WHITE}Select addon [1-8]: ${NC}"
    read addon_choice
    
    case $addon_choice in
        1|2|3|4|5)
            echo -e "\n  ${RED}⚠️  Addon installation coming soon!${NC}"
            echo -e "  ${YELLOW}This feature will be available in the next update${NC}"
            ;;
        6|7|8)
            echo -e "\n  ${YELLOW}⏳ Coming Soon!${NC}"
            echo -e "  ${WHITE}This addon is under development${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

# ==================== HYPER V1 THEME ====================

hyper_v1_menu() {
    echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}🚀 HYPER V1 THEME${NC}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}This is a premium theme with advanced features!${NC}"
    echo -e "  ${WHITE}Features:${NC}"
    echo -e "  ${WHITE}├─ Modern dark/light mode${NC}"
    echo -e "  ${WHITE}├─ Custom dashboard widgets${NC}"
    echo -e "  ${WHITE}├─ Advanced resource graphs${NC}"
    echo -e "  ${WHITE}├─ Mobile responsive design${NC}"
    echo -e "  ${WHITE}└─ One-click theme switching${NC}"
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
        echo -e "  ${GREEN}  [ 4 ]${NC} Uninstall Theme"
        echo ""
        echo -ne "  ${WHITE}Select option: ${NC}"
        read hyper_choice
        
        case $hyper_choice in
            1)
                echo -e "\n  ${YELLOW}Installing Hyper V1 Theme...${NC}"
                echo -e "  ${RED}⚠️  Coming Soon!${NC}"
                echo -e "  ${WHITE}Hyper V1 Theme will be available in the next update${NC}"
                ;;
            2)
                echo -e "\n  ${YELLOW}Configuration coming soon!${NC}"
                ;;
            3)
                echo -e "\n  ${CYAN}Preview: Hyper V1 Theme is a modern, sleek design${NC}"
                echo -e "  ${WHITE}├─ Dashboard: Clean cards with animations${NC}"
                echo -e "  ${WHITE}├─ Server List: Grid/List view toggle${NC}"
                echo -e "  ${WHITE}└─ Resource Usage: Real-time graphs${NC}"
                ;;
            4)
                echo -e "\n  ${YELLOW}Uninstall coming soon!${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
    else
        echo -e "\n  ${RED}✗ Access denied! Incorrect password.${NC}"
    fi
}

# ==================== PTERODACTYL EXTRA MENU ====================

pterodactyl_extras_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}           PTERODACTYL EXTRAS (Themes & Addons)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Blueprint (Extension System) ${RED}[Coming Soon]${NC}"
        echo -e "  ${GREEN}2)${NC} Install Themes ${RED}[Coming Soon]${NC}"
        echo -e "  ${GREEN}3)${NC} Install Addons ${RED}[Coming Soon]${NC}"
        echo -e "  ${GREEN}4)${NC} 🚀 Hyper V1 Theme (Premium) ${CYAN}[Password Protected]${NC}"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        echo -ne "${WHITE}Enter your choice [0-4]: ${NC}"
        read choice
        
        case $choice in
            1) install_blueprint ;;
            2) install_theme ;;
            3) install_addon ;;
            4) hyper_v1_menu ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
        
        echo -ne "\n${WHITE}Press Enter to continue...${NC}"
        read
    done
}

# ==================== TAILSCALE WITH AUTH KEY ====================

install_tailscale_with_key() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh >> "$LOG_FILE" 2>&1
    success "Tailscale installed"
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}🔐 TAILSCALE AUTH KEY SETUP${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}How to get your Auth Key:${NC}"
    echo -e "  ${CYAN}1. Go to https://login.tailscale.com/admin/authkeys${NC}"
    echo -e "  ${CYAN}2. Click 'Generate auth key'${NC}"
    echo -e "  ${CYAN}3. Copy the key (starts with 'tskey-')${NC}"
    echo ""
    echo -ne "  ${GREEN}► Paste your Tailscale Auth Key: ${NC}"
    read AUTH_KEY
    
    if [[ -z "$AUTH_KEY" ]]; then
        echo -e "\n  ${RED}No auth key entered! Using interactive login.${NC}"
        tailscale up
    else
        echo -e "\n  ${WHITE}Connecting with auth key...${NC}"
        tailscale up --auth-key "$AUTH_KEY"
        success "Tailscale connected with auth key!"
        echo -e "\n  ${GREEN}Tailscale Status:${NC}"
        tailscale status
        echo -e "\n  ${GREEN}Your Tailscale IP: $(tailscale ip 2>/dev/null)${NC}"
    fi
}

install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh >> "$LOG_FILE" 2>&1
    success "Tailscale installed"
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}🔐 TAILSCALE SETUP${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Setup with Auth Key (Recommended)"
    echo -e "  ${GREEN}2)${NC} Setup with Login Link"
    echo ""
    echo -ne "  ${WHITE}Choose method [1-2]: ${NC}"
    read method
    
    if [[ "$method" == "1" ]]; then
        install_tailscale_with_key
    else
        echo -e "\n  ${WHITE}Click the link below to authenticate:${NC}"
        echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        tailscale up 2>&1 | tee /tmp/tailscale_output.txt
        LOGIN_URL=$(grep -oP 'https://login.tailscale.com/a/[a-zA-Z0-9]+' /tmp/tailscale_output.txt || echo "https://login.tailscale.com")
        echo -e "  ${GREEN}👉 $LOGIN_URL${NC}"
        echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "\n  ${YELLOW}Instructions:${NC}"
        echo -e "  ${WHITE}1.${NC} Click the link above"
        echo -e "  ${WHITE}2.${NC} Log in with your account"
        echo -e "  ${WHITE}3.${NC} Click 'Connect'"
        echo -e "  ${WHITE}4.${NC} Return here and press Enter"
        echo ""
        echo -ne "  ${GREEN}Press Enter after authentication...${NC}"
        read
        success "Tailscale setup completed!"
        tailscale status
    fi
}

# ==================== CLOUDFLARED WITH TOKEN ====================

install_cloudflared() {
    log "Installing Cloudflared..."
    
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}☁️  CLOUDFLARED INSTALLATION${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Install cloudflared
    echo -e "  ${WHITE}[1/3] Adding Cloudflare GPG key...${NC}"
    mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
    success "GPG key added"
    
    echo -e "  ${WHITE}[2/3] Adding Cloudflare repository...${NC}"
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    success "Repository added"
    
    echo -e "  ${WHITE}[3/3] Installing cloudflared...${NC}"
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y cloudflared >> "$LOG_FILE" 2>&1
    success "Cloudflared installed: $(cloudflared version)"
    
    echo ""
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}🔑 ENTER YOUR CLOUDFLARE TUNNEL TOKEN${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}How to get your token:${NC}"
    echo -e "  ${CYAN}1. Go to https://dash.cloudflare.com/${NC}"
    echo -e "  ${CYAN}2. Click on your account → Zero Trust → Networks → Tunnels${NC}"
    echo -e "  ${CYAN}3. Click 'Create a tunnel'${NC}"
    echo -e "  ${CYAN}4. Name your tunnel and click 'Save'${NC}"
    echo -e "  ${CYAN}5. Copy the token from the 'Install and run' section${NC}"
    echo ""
    echo -e "  ${YELLOW}Note: The token starts with 'eyJ...' and is a long string${NC}"
    echo ""
    echo -ne "  ${GREEN}► Paste your token here: ${NC}"
    read CLOUDFLARE_TOKEN
    
    if [[ -z "$CLOUDFLARE_TOKEN" ]]; then
        echo -e "\n  ${RED}No token entered! Skipping tunnel setup.${NC}"
        return
    fi
    
    echo -e "\n  ${WHITE}Setting up tunnel with your token...${NC}"
    
    cat > /etc/systemd/system/cloudflared-tunnel.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/cloudflared tunnel run --token $CLOUDFLARE_TOKEN
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable cloudflared-tunnel
    systemctl start cloudflared-tunnel
    
    sleep 3
    
    if systemctl is-active --quiet cloudflared-tunnel; then
        success "✓ Cloudflare Tunnel is running!"
        echo -e "\n  ${GREEN}Your tunnel is now active and will auto-start on boot!${NC}"
    else
        echo -e "\n  ${RED}Failed to start tunnel. Try manually:${NC}"
        echo -e "  ${WHITE}cloudflared tunnel run --token \"$CLOUDFLARE_TOKEN\"${NC}"
    fi
}

# ==================== OTHER TOOLS ====================

install_node() {
    log "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y nodejs >> "$LOG_FILE" 2>&1
    success "Node.js installed: $(node -v)"
}

uninstall_node() {
    log "Uninstalling Node.js..."
    apt-get remove -y nodejs >> "$LOG_FILE" 2>&1
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    success "Node.js uninstalled"
}

uninstall_tailscale() {
    log "Uninstalling Tailscale..."
    
    if command -v tailscale &> /dev/null; then
        tailscale down >> "$LOG_FILE" 2>&1
        systemctl stop tailscaled >> "$LOG_FILE" 2>&1
    fi
    
    apt-get remove -y tailscale >> "$LOG_FILE" 2>&1
    rm -rf /var/lib/tailscale /etc/tailscale
    rm -f /etc/apt/sources.list.d/tailscale.list
    apt-get update >> "$LOG_FILE" 2>&1
    
    success "Tailscale uninstalled"
}

uninstall_cloudflared() {
    log "Uninstalling Cloudflared..."
    
    if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
        systemctl stop cloudflared-tunnel >> "$LOG_FILE" 2>&1
        systemctl disable cloudflared-tunnel >> "$LOG_FILE" 2>&1
        rm -f /etc/systemd/system/cloudflared-tunnel.service
        systemctl daemon-reload
    fi
    
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    apt-get remove -y cloudflared >> "$LOG_FILE" 2>&1
    rm -rf /root/.cloudflared /etc/cloudflared
    rm -f /etc/apt/sources.list.d/cloudflared.list
    rm -f /usr/share/keyrings/cloudflare-public-v2.gpg
    apt-get update >> "$LOG_FILE" 2>&1
    
    success "Cloudflared uninstalled"
}

show_cloudflared_status() {
    echo -e "\n  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}📊 CLOUDFLARED STATUS${NC}"
    echo -e "  ${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if command -v cloudflared &> /dev/null; then
        echo -e "  ${GREEN}✓ Cloudflared is installed${NC}"
        echo -e "  ${WHITE}Version: $(cloudflared version)${NC}"
        
        if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
            echo -e "  ${GREEN}✓ Tunnel service is running${NC}"
        else
            echo -e "  ${YELLOW}⚠ Tunnel service is not running${NC}"
        fi
    else
        echo -e "  ${RED}✗ Cloudflared is not installed${NC}"
    fi
}

install_rdp() {
    log "Installing RDP (X2Go)..."
    apt-get install -y x2goserver x2goserver-xsession xfce4 xfce4-goodies >> "$LOG_FILE" 2>&1
    success "RDP installed"
    echo -e "\n  ${YELLOW}RDP Information${NC}"
    echo -e "  ${WHITE}├─ Desktop: XFCE4${NC}"
    echo -e "  ${WHITE}├─ Port: 22 (SSH)${NC}"
    echo -e "  ${WHITE}└─ Connect using X2Go client with SSH protocol${NC}"
}

uninstall_rdp() {
    log "Uninstalling RDP..."
    apt-get remove -y x2goserver x2goserver-xsession xfce4 xfce4-goodies >> "$LOG_FILE" 2>&1
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    success "RDP uninstalled"
}

install_norfurch() {
    log "Installing Norfurch (Monitoring Tools)..."
    apt-get install -y htop nmon iotop iftop >> "$LOG_FILE" 2>&1
    curl -fsSL https://my-netdata.io/kickstart.sh | sh >> "$LOG_FILE" 2>&1
    success "Norfurch monitoring tools installed"
    echo -e "\n  ${YELLOW}Monitoring Tools Available:${NC}"
    echo -e "  ${WHITE}├─ htop    : Interactive process viewer${NC}"
    echo -e "  ${WHITE}├─ nmon    : System performance monitor${NC}"
    echo -e "  ${WHITE}├─ iotop   : I/O monitoring${NC}"
    echo -e "  ${WHITE}├─ iftop   : Network bandwidth monitor${NC}"
    echo -e "  ${WHITE}└─ netdata : http://localhost:19999${NC}"
}

uninstall_norfurch() {
    log "Uninstalling monitoring tools..."
    apt-get remove -y htop nmon iotop iftop >> "$LOG_FILE" 2>&1
    if command -v netdata &> /dev/null; then
        systemctl stop netdata >> "$LOG_FILE" 2>&1
        systemctl disable netdata >> "$LOG_FILE" 2>&1
        rm -rf /etc/netdata /var/lib/netdata /usr/share/netdata
    fi
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    success "Monitoring tools uninstalled"
}

# ==================== MENUS ====================

node_menu() {
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
            1) install_node ;;
            2) uninstall_node ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

tailscale_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    TAILSCALE MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if command -v tailscale &> /dev/null; then
            echo -e "  ${GREEN}Status: INSTALLED${NC}"
            tailscale status 2>&1 | head -3
        else
            echo -e "  ${RED}Status: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Tailscale (with Auth Key)"
        echo -e "  ${RED}2)${NC} Uninstall Tailscale"
        echo -e "  ${GREEN}3)${NC} Connect/Start"
        echo -e "  ${RED}4)${NC} Disconnect/Stop"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) install_tailscale ;;
            2) uninstall_tailscale ;;
            3) tailscale up ;;
            4) tailscale down ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

cloudflared_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    CLOUDFLARED MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if command -v cloudflared &> /dev/null; then
            echo -e "  ${GREEN}Status: INSTALLED - $(cloudflared version)${NC}"
            if systemctl is-active --quiet cloudflared-tunnel 2>/dev/null; then
                echo -e "  ${GREEN}Tunnel: RUNNING ✓${NC}"
            else
                echo -e "  ${YELLOW}Tunnel: NOT RUNNING${NC}"
            fi
        else
            echo -e "  ${RED}Status: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Cloudflared (with token)"
        echo -e "  ${RED}2)${NC} Uninstall Cloudflared"
        echo -e "  ${GREEN}3)${NC} Show Status"
        echo -e "  ${GREEN}4)${NC} Start Tunnel Service"
        echo -e "  ${RED}5)${NC} Stop Tunnel Service"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) install_cloudflared ;;
            2) uninstall_cloudflared ;;
            3) show_cloudflared_status ;;
            4) systemctl start cloudflared-tunnel 2>/dev/null && echo -e "${GREEN}Started${NC}" || echo -e "${RED}No tunnel configured${NC}" ;;
            5) systemctl stop cloudflared-tunnel 2>/dev/null && echo -e "${GREEN}Stopped${NC}" ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

rdp_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    RDP MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if command -v x2goserver &> /dev/null; then
            echo -e "  ${GREEN}Status: X2Go SERVER INSTALLED${NC}"
        else
            echo -e "  ${RED}Status: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install RDP (X2Go + XFCE4)"
        echo -e "  ${RED}2)${NC} Uninstall RDP"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) install_rdp ;;
            2) uninstall_rdp ;;
            0) break ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
        echo -ne "\n${WHITE}Press Enter...${NC}"; read
    done
}

norfurch_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    NORFURCH MANAGER${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if command -v htop &> /dev/null; then
            echo -e "  ${GREEN}Status: MONITORING TOOLS INSTALLED${NC}"
        else
            echo -e "  ${RED}Status: NOT INSTALLED${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1)${NC} Install Norfurch"
        echo -e "  ${RED}2)${NC} Uninstall Norfurch"
        echo -e "  ${YELLOW}0)${NC} Back"
        echo ""
        echo -ne "${WHITE}Choice: ${NC}"
        read choice
        
        case $choice in
            1) install_norfurch ;;
            2) uninstall_norfurch ;;
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
        echo -e "${YELLOW}                    PTERODACTYL INSTALLATION${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}1)${NC} Install Everything (Full Pterodactyl Suite)"
        echo -e "  ${GREEN}2)${NC} Install Pterodactyl Panel Only"
        echo -e "  ${GREEN}3)${NC} Install Pterodactyl Wings Only"
        echo -e "  ${GREEN}4)${NC} 🎨 Pterodactyl Extras (Themes, Blueprint, Addons)"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}                    ADDITIONAL TOOLS${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}5)${NC} 📦 Node.js Manager"
        echo -e "  ${GREEN}6)${NC} 🔒 Tailscale VPN Manager (with Auth Key)"
        echo -e "  ${GREEN}7)${NC} ☁️  Cloudflared Manager (with Token)"
        echo -e "  ${GREEN}8)${NC} 🖥️  RDP Manager"
        echo -e "  ${GREEN}9)${NC} 📊 Norfurch Manager"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}0)${NC} Exit"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "${WHITE}Enter your choice [0-9]: ${NC}"
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
                ;;
            2)
                update_system
                install_dependencies
                setup_mysql
                install_pterodactyl_panel
                configure_nginx
                echo -e "\n${GREEN}✓ Pterodactyl Panel installed!${NC}"
                echo -e "${YELLOW}Access at: http://$(curl -s ifconfig.me)${NC}"
                ;;
            3)
                update_system
                install_dependencies
                install_pterodactyl_wings
                ;;
            4) pterodactyl_extras_menu ;;
            5) node_menu ;;
            6) tailscale_menu ;;
            7) cloudflared_menu ;;
            8) rdp_menu ;;
            9) norfurch_menu ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
        
        if [[ $choice -ge 1 && $choice -le 3 ]]; then
            echo -ne "\n${WHITE}Press Enter...${NC}"; read
        fi
    done
}

# Start
check_root
detect_os
main_menu
