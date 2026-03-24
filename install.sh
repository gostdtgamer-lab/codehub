#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER CLOUD SYSTEM | PTERODACTYL DEPLOYMENT SUITE
# DATE: 2026-03-25 | UI-TYPE: SEMA-HYPER-VISUAL
# ==========================================================
set -euo pipefail

# --- SEMA-BANE THEME ---
R='\033[1;38;5;196m'  # Crimson
G='\033[1;38;5;82m'   # Emerald
Y='\033[1;38;5;220m'  # Gold
C='\033[1;38;5;51m'   # Cyan
W='\033[1;38;5;255m'  # Pure White
DG='\033[0;38;5;244m' # Steel Gray
PURPLE='\033[1;38;5;141m'
NC='\033[0m'          # Reset

# --- CONFIG ---
LOG_FILE="/tmp/gostdtgamer_ptero_install.log"
PTERO_DIR="/var/www/pterodactyl"
WINGS_DIR="/etc/pterodactyl"
MYSQL_ROOT_PASS=""
MYSQL_PTERO_PASS=""

# --- FUNCTIONS ---
log() {
    echo -e "${DG}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${R}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${G}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
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

show_specs() {
    clear
    echo -e "${G}"
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
    echo -e "${PURPLE}│${NC}  ${R}☢️  GOSTDTGAMER PTERODACTYL SUITE${NC} ${DG}v2.0${NC}          ${DG}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${DG}                   POWERED BY GOSTDTGAMER${NC}"
    echo ""
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}                    SYSTEM INFORMATION${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    CPU_CORES=$(nproc)
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    echo -e "${DG}├─ CPU Cores      :${NC} ${W}$CPU_CORES${NC}"
    echo -e "${DG}├─ CPU Model      :${NC} ${W}$CPU_MODEL${NC}"
    
    RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    echo -e "${DG}├─ Total RAM      :${NC} ${W}$RAM_TOTAL${NC}"
    
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    echo -e "${DG}├─ Total Disk     :${NC} ${W}$DISK_TOTAL${NC}"
    echo -e "${DG}├─ Free Disk      :${NC} ${W}$DISK_FREE${NC}"
    
    echo -e "${DG}├─ OS             :${NC} ${W}$OS $VER${NC}"
    
    IP_PUBLIC=$(curl -s --max-time 5 ifconfig.me || echo "Not available")
    echo -e "${DG}└─ Public IP      :${NC} ${W}$IP_PUBLIC${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

update_system() {
    log "Updating system packages..."
    apt-get update -y 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    success "System updated"
}

install_dependencies() {
    log "Installing dependencies..."
    
    apt-get install -y curl wget git nginx mysql-server redis-server \
        tar unzip zip gzip ca-certificates gnupg lsb-release \
        software-properties-common 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Install PHP 8.2
    echo -e "  ${DG}├─ Installing PHP 8.2...${NC}"
    apt-get install -y php8.2 php8.2-cli php8.2-common php8.2-curl \
        php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml \
        php8.2-fpm php8.2-zip php8.2-redis 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Install Docker for Wings
    echo -e "  ${DG}├─ Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    success "Dependencies installed"
}

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
MySQL Root Password: $MYSQL_ROOT_PASS
Pterodactyl Database User: pterodactyl
Pterodactyl Database Password: $MYSQL_PTERO_PASS
Database Name: panel
EOF
    
    success "MySQL configured"
    echo -e "  ${Y}├─ Credentials saved to: /root/pterodactyl_db_credentials.txt${NC}"
}

install_pterodactyl_panel() {
    log "Installing Pterodactyl Panel..."
    
    cd /var/www
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz 2>&1 | tee -a "$LOG_FILE"
    tar -xzvf panel.tar.gz 2>&1 | tee -a "$LOG_FILE"
    chmod -R 755 storage/* bootstrap/cache/
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 2>&1 | tee -a "$LOG_FILE"
    
    cd "$PTERO_DIR"
    cp .env.example .env
    composer install --no-dev --optimize-autoloader 2>&1 | tee -a "$LOG_FILE"
    
    # Generate key
    php artisan key:generate --force
    
    # Configure database
    php artisan p:environment:setup --author=admin@localhost --url=http://localhost --timezone=UTC --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}"
    
    # Run migrations
    php artisan migrate --seed --force
    
    # Create admin user
    php artisan p:user:make --email=admin@localhost --username=admin --name-first=Admin --password=password123 --admin=1
    
    # Set permissions
    chown -R www-data:www-data /var/www/pterodactyl/*
    
    # Setup queue worker
    cat > /etc/systemd/system/pteroq.service << EOF
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
    
    systemctl enable --now pteroq.service
    
    # Setup cron job
    echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | crontab -
    
    success "Pterodactyl Panel installed"
}

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
    
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
    systemctl restart php8.2-fpm
    
    success "Nginx configured"
}

install_node_tailscale() {
    log "Installing Node.js and Tailscale..."
    
    # Node.js
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - 2>&1 | tee -a "$LOG_FILE"
    apt-get install -y nodejs 2>&1 | tee -a "$LOG_FILE"
    success "Node.js installed: $(node -v)"
    
    # Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh 2>&1 | tee -a "$LOG_FILE"
    success "Tailscale installed"
    
    echo -e "\n  ${Y}Tailscale Setup${NC}"
    echo -ne "  ${DG}├─ Start Tailscale? (y/n): ${NC}"
    read -r start_ts
    if [[ "$start_ts" == "y" ]]; then
        echo -ne "  ${DG}├─ Auth key (optional): ${NC}"
        read -r ts_key
        if [[ -n "$ts_key" ]]; then
            tailscale up --auth-key "$ts_key"
        else
            tailscale up
        fi
        success "Tailscale started"
    fi
}

install_cloudflared_token() {
    log "Installing Cloudflared..."
    
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >> "$LOG_FILE"
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list
    apt-get update -y >> "$LOG_FILE"
    apt-get install -y cloudflared 2>&1 | tee -a "$LOG_FILE"
    
    success "Cloudflared installed"
    
    echo -e "\n  ${Y}Cloudflare Tunnel Setup${NC}"
    echo -e "  ${DG}├─ You will need to authenticate with Cloudflare${NC}"
    echo -ne "  ${DG}├─ Press Enter to start authentication...${NC}"
    read -r
    
    cloudflared tunnel login
    
    echo -ne "  ${DG}├─ Enter tunnel name: ${NC}"
    read -r tunnel_name
    
    cloudflared tunnel create "$tunnel_name"
    
    echo -ne "  ${DG}├─ Enter hostname (e.g., panel.example.com): ${NC}"
    read -r hostname
    
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
    
    echo -e "\n  ${G}✓ Cloudflare tunnel configured!${NC}"
    echo -e "  ${DG}├─ Run: ${W}cloudflared tunnel run $tunnel_name${NC}"
    echo -e "  ${DG}└─ Or install as service: ${W}cloudflared service install${NC}"
}

install_pterodactyl_wings() {
    log "Installing Pterodactyl Wings..."
    
    # Create wings user
    useradd -r -d /var/lib/pterodactyl -m -s /bin/bash wings || true
    
    # Create directories
    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/{tmp,archive,backups}
    
    # Download wings
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 2>&1 | tee -a "$LOG_FILE"
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
    echo -e "\n  ${Y}Wings Setup Required:${NC}"
    echo -e "  ${DG}├─ After panel installation, get node configuration from panel${NC}"
    echo -e "  ${DG}├─ Save config to: /etc/pterodactyl/config.yml${NC}"
    echo -e "  ${DG}└─ Then start wings: ${W}systemctl start wings${NC}"
}

install_norfurch() {
    log "Installing Norfurch (Monitoring Tools)..."
    
    apt-get install -y htop nmon iotop iftop netdata 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Install netdata if not available
    if ! command -v netdata &> /dev/null; then
        curl -fsSL https://my-netdata.io/kickstart.sh | sh 2>&1 | tee -a "$LOG_FILE"
    fi
    
    success "Monitoring tools installed"
    
    echo -e "\n  ${Y}Monitoring Tools Available:${NC}"
    echo -e "  ${DG}├─ htop    : Interactive process viewer${NC}"
    echo -e "  ${DG}├─ nmon    : System performance monitor${NC}"
    echo -e "  ${DG}├─ iotop   : I/O monitoring${NC}"
    echo -e "  ${DG}├─ iftop   : Network bandwidth monitor${NC}"
    echo -e "  ${DG}└─ netdata : http://localhost:19999${NC}"
}

install_rdp() {
    log "Installing RDP (X2Go)..."
    
    apt-get install -y x2goserver x2goserver-xsession xfce4 xfce4-goodies 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    success "RDP installed"
    echo -e "\n  ${Y}RDP Info:${NC}"
    echo -e "  ${DG}├─ Desktop: XFCE4${NC}"
    echo -e "  ${DG}├─ Port: 22 (SSH)${NC}"
    echo -e "  ${DG}└─ Connect with X2Go client${NC}"
}

# ==================== NEW FEATURES ====================

github_vps_maker() {
    log "GitHub VPS Maker - Setting up GitHub Actions runners and deployment tools..."
    
    echo -e "\n  ${Y}🚀 GitHub VPS Maker${NC}"
    echo -e "  ${DG}├─ This will set up GitHub Actions runner and deployment tools${NC}"
    
    # Install GitHub CLI
    echo -e "  ${DG}├─ Installing GitHub CLI...${NC}"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y gh >> "$LOG_FILE" 2>&1
    
    # Install GitHub Actions Runner
    echo -e "  ${DG}├─ Setting up GitHub Actions Runner...${NC}"
    mkdir -p /opt/actions-runner
    cd /opt/actions-runner
    
    LATEST_RUNNER=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep "browser_download_url.*linux-x64" | grep -v ".sha256" | cut -d '"' -f 4)
    curl -L -o actions-runner.tar.gz "$LATEST_RUNNER" 2>&1 | tee -a "$LOG_FILE"
    tar -xzf actions-runner.tar.gz
    rm actions-runner.tar.gz
    
    echo -e "  ${Y}├─ GitHub Actions Runner Configuration${NC}"
    echo -ne "  ${DG}├─ Enter GitHub repository URL (or press Enter to skip): ${NC}"
    read -r repo_url
    
    if [[ -n "$repo_url" ]]; then
        echo -ne "  ${DG}├─ Enter GitHub token (with repo scope): ${NC}"
        read -r github_token
        
        ./config.sh --url "$repo_url" --token "$github_token" --unattended
        ./svc.sh install
        ./svc.sh start
        success "GitHub Actions Runner configured and started"
    fi
    
    # Install deployment tools
    echo -e "  ${DG}├─ Installing deployment tools...${NC}"
    apt-get install -y ansible terraform 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Install kubectl if needed
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >> "$LOG_FILE" 2>&1
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    success "GitHub VPS Maker completed"
    echo -e "  ${G}├─ GitHub CLI: ${W}gh --version${NC}"
    echo -e "  ${G}├─ Actions Runner: ${W}/opt/actions-runner${NC}"
    echo -e "  ${G}└─ Deployment tools: Ansible, Terraform, kubectl${NC}"
}

idx_tool_setup() {
    log "IDX Tool Setup - Installing development and IDE tools..."
    
    echo -e "\n  ${Y}🔧 IDX Tool Setup${NC}"
    echo -e "  ${DG}├─ This will install development tools and IDEs${NC}"
    
    # Install VS Code
    echo -e "  ${DG}├─ Installing VS Code...${NC}"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list
    rm -f packages.microsoft.gpg
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y code >> "$LOG_FILE" 2>&1
    
    # Install Docker Compose
    echo -e "  ${DG}├─ Installing Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install development tools
    echo -e "  ${DG}├─ Installing development tools...${NC}"
    apt-get install -y build-essential python3-pip python3-venv golang-go \
        default-jdk postgresql-client redis-tools 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Install npm global tools
    echo -e "  ${DG}├─ Installing npm global tools...${NC}"
    npm install -g yarn pm2 nodemon typescript ts-node 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Install Python tools
    echo -e "  ${DG}├─ Installing Python tools...${NC}"
    pip3 install virtualenv pipenv poetry 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Create development directory
    mkdir -p /opt/dev/projects
    chmod 755 /opt/dev
    
    success "IDX Tool Setup completed"
    echo -e "  ${G}├─ VS Code: ${W}code${NC}"
    echo -e "  ${G}├─ Docker Compose: ${W}docker-compose${NC}"
    echo -e "  ${G}├─ Node.js tools: yarn, pm2, nodemon${NC}"
    echo -e "  ${G}├─ Python tools: virtualenv, pipenv, poetry${NC}"
    echo -e "  ${G}└─ Dev directory: ${W}/opt/dev/projects${NC}"
}

idx_vps_maker() {
    log "IDX VPS Maker - Setting up IDX (Project IDX) development environment..."
    
    echo -e "\n  ${Y}⚡ IDX VPS Maker${NC}"
    echo -e "  ${DG}├─ Setting up Project IDX compatible environment${NC}"
    
    # Install Web IDE (Code-Server)
    echo -e "  ${DG}├─ Installing Code-Server (Web IDE)...${NC}"
    curl -fsSL https://code-server.dev/install.sh | sh 2>&1 | tee -a "$LOG_FILE"
    
    # Create config directory
    mkdir -p /root/.config/code-server
    
    # Generate random password for code-server
    CODE_PASS=$(openssl rand -base64 12)
    cat > /root/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $CODE_PASS
cert: false
EOF
    
    # Create systemd service for code-server
    cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/code-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable code-server
    systemctl start code-server
    
    # Install File Browser
    echo -e "  ${DG}├─ Installing File Browser...${NC}"
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash 2>&1 | tee -a "$LOG_FILE"
    
    cat > /etc/systemd/system/filebrowser.service << EOF
[Unit]
Description=File Browser
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/filebrowser -r / -a 0.0.0.0 -p 8081
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable filebrowser
    systemctl start filebrowser
    
    # Install Portainer for container management
    echo -e "  ${DG}├─ Installing Portainer...${NC}"
    docker volume create portainer_data >> "$LOG_FILE" 2>&1
    docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data portainer/portainer-ce:latest >> "$LOG_FILE" 2>&1
    
    # Create workspace
    mkdir -p /opt/idx-workspace
    chmod 777 /opt/idx-workspace
    
    # Save credentials
    cat > /root/idx_credentials.txt << EOF
====================================
IDX VPS MAKER - ACCESS CREDENTIALS
====================================
Code-Server (Web IDE): http://$(curl -s ifconfig.me):8080
Code-Server Password: $CODE_PASS

File Browser: http://$(curl -s ifconfig.me):8081
File Browser Login: admin/admin (first login will prompt to change)

Portainer: https://$(curl -s ifconfig.me):9443
Portainer Setup: Create admin user on first login

Workspace Directory: /opt/idx-workspace
====================================
EOF
    
    success "IDX VPS Maker completed"
    echo -e "  ${G}├─ Web IDE: ${W}http://$(curl -s ifconfig.me):8080${NC}"
    echo -e "  ${G}├─ File Browser: ${W}http://$(curl -s ifconfig.me):8081${NC}"
    echo -e "  ${G}├─ Portainer: ${W}https://$(curl -s ifconfig.me):9443${NC}"
    echo -e "  ${G}└─ Credentials saved: ${W}/root/idx_credentials.txt${NC}"
}

real_vps_setup() {
    log "Real VPS (Any + KVM) - Setting up complete VPS environment..."
    
    echo -e "\n  ${Y}🌐 Real VPS Setup (Any + KVM)${NC}"
    echo -e "  ${DG}├─ This will set up a complete VPS with virtualization${NC}"
    
    # Check for KVM support
    echo -e "  ${DG}├─ Checking KVM support...${NC}"
    if grep -E -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        echo -e "  ${G}│  ✓ KVM supported${NC}"
        
        # Install KVM and virtualization tools
        apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager \
            cpu-checker virtinst 2>&1 | tee -a "$LOG_FILE" | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
        
        systemctl enable libvirtd
        systemctl start libvirtd
        
        # Add current user to libvirt group
        usermod -aG libvirt,libvirt-qemu,kvm $SUDO_USER 2>/dev/null || true
        
        success "KVM virtualization installed"
    else
        echo -e "  ${Y}│  ⚠ KVM not supported on this VPS${NC}"
    fi
    
    # Install LXD for containers
    echo -e "  ${DG}├─ Installing LXD...${NC}"
    snap install lxd 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    lxd init --auto
    
    # Install Cockpit for web management
    echo -e "  ${DG}├─ Installing Cockpit...${NC}"
    apt-get install -y cockpit cockpit-machines cockpit-docker 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    systemctl enable cockpit
    systemctl start cockpit
    
    # Install cloud-init
    echo -e "  ${DG}├─ Installing cloud-init...${NC}"
    apt-get install -y cloud-init cloud-utils 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Create VM storage directory
    mkdir -p /var/lib/libvirt/images/vms
    chmod 755 /var/lib/libvirt/images/vms
    
    # Create network bridge
    cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: yes
  bridges:
    br0:
      interfaces: [eth0]
      dhcp4: yes
EOF
    
    # Install monitoring for VPS
    echo -e "  ${DG}├─ Installing VPS monitoring...${NC}"
    apt-get install -y prometheus-node-exporter 2>&1 | tee -a "$LOG_FILE" | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    success "Real VPS Setup completed"
    echo -e "\n  ${G}├─ KVM Status: ${W}$([ -f /dev/kvm ] && echo "Available" || echo "Not available")${NC}"
    echo -e "  ${G}├─ LXD: ${W}lxc list${NC}"
    echo -e "  ${G}├─ Cockpit: ${W}https://$(curl -s ifconfig.me):9090${NC}"
    echo -e "  ${G}├─ VM Storage: ${W}/var/lib/libvirt/images/vms${NC}"
    echo -e "  ${G}└─ Monitoring: ${W}http://$(curl -s ifconfig.me):9100${NC}"
}

# ==================== MAIN MENU ====================

main_menu() {
    clear
    show_specs
    
    echo -e "\n${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${C}                    GOSTDTGAMER VPS DEPLOYMENT SUITE${NC}"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${C}  🐧 PTERODACTYL INSTALLATION${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${G}1)${NC} Install Everything (Full Pterodactyl Suite)"
    echo -e "  ${G}2)${NC} Install Pterodactyl Panel Only"
    echo -e "  ${G}3)${NC} Install Pterodactyl Wings Only"
    echo ""
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${C}  🛠️  ADDITIONAL TOOLS${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${G}4)${NC} Install Node.js"
    echo -e "  ${G}5)${NC} Install Tailscale VPN"
    echo -e "  ${G}6)${NC} Install Cloudflared (with token setup)"
    echo -e "  ${G}7)${NC} Install RDP (Remote Desktop)"
    echo -e "  ${G}8)${NC} Install Norfurch (Monitoring Tools)"
    echo ""
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${C}  🚀 ADVANCED DEPLOYMENT FEATURES${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${G}9)${NC} 🚀 GitHub VPS Maker (Actions Runner + Deployment Tools)"
    echo -e "  ${G}10)${NC} 🔧 IDX Tool Setup (Dev Tools + IDE)"
    echo -e "  ${G}11)${NC} ⚡ IDX VPS Maker (Web IDE + File Browser + Portainer)"
    echo -e "  ${G}12)${NC} 🌐 Real VPS (Any + KVM) - Full Virtualization Setup"
    echo ""
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${C}  ℹ️  INFORMATION${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${G}13)${NC} View System Specifications"
    echo -e "  ${G}14)${NC} View Installation Log"
    echo -e "  ${R}0)${NC} ❌ Exit"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne "  ${W}Enter your choice [0-14]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            update_system
            install_dependencies
            setup_mysql
            install_pterodactyl_panel
            configure_nginx
            install_pterodactyl_wings
            install_node_tailscale
            install_cloudflared_token
            install_rdp
            install_norfurch
            echo -e "\n${G}✓ Full Pterodactyl installation completed!${NC}"
            echo -e "${Y}Panel Access: http://$(curl -s ifconfig.me)${NC}"
            echo -e "${Y}Admin Login: admin@localhost / password123${NC}"
            echo -e "${Y}DB Credentials: /root/pterodactyl_db_credentials.txt${NC}"
            ;;
        2)
            update_system
            install_dependencies
            setup_mysql
            install_pterodactyl_panel
            configure_nginx
            echo -e "\n${G}✓ Pterodactyl Panel installed!${NC}"
            echo -e "${Y}Access at: http://$(curl -s ifconfig.me)${NC}"
            ;;
        3)
            update_system
            install_dependencies
            install_pterodactyl_wings
            ;;
        4)
            update_system
            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            apt-get install -y nodejs
            success "Node.js installed: $(node -v)"
            ;;
        5)
            update_system
            curl -fsSL https://tailscale.com/install.sh | sh
            echo -ne "Start Tailscale? (y/n): "
            read -r start_ts
            if [[ "$start_ts" == "y" ]]; then
                echo -ne "Auth key (optional): "
                read -r ts_key
                [[ -n "$ts_key" ]] && tailscale up --auth-key "$ts_key" || tailscale up
            fi
            ;;
        6)
            update_system
            install_cloudflared_token
            ;;
        7)
            update_system
            install_rdp
            ;;
        8)
            update_system
            install_norfurch
            ;;
        9)
            update_system
            github_vps_maker
            ;;
        10)
            update_system
            idx_tool_setup
            ;;
        11)
            update_system
            idx_vps_maker
            ;;
        12)
            update_system
            real_vps_setup
            ;;
        13)
            show_specs
            echo -e "\n${W}Press Enter to continue...${NC}"
            read -r
            main_menu
            ;;
        14)
            if [[ -f "$LOG_FILE" ]]; then
                less "$LOG_FILE"
            else
                echo -e "${Y}No log file found${NC}"
            fi
            main_menu
            ;;
        0)
            echo -e "${G}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${R}Invalid option${NC}"
            sleep 2
            main_menu
            ;;
    esac
    
    echo -e "\n${W}Press Enter to return to menu...${NC}"
    read -r
    main_menu
}

# --- MAIN EXECUTION ---
check_root
detect_os
main_menu
