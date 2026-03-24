#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER CLOUD SYSTEM | VPS DEPLOYMENT SUITE
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
LOG_FILE="/tmp/gostdtgamer_install.log"
INSTALL_DIR="/opt/gostdtgamer"

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
 ██████╗  ██████╗ ███████╗████████╗██████╗  ██████╗ ████████╗ ██████╗  █████╗ ███╗   ███╗███████╗██████╗ 
██╔════╝ ██╔═══██╗██╔════╝╚══██╔══╝██╔══██╗██╔════╝ ╚══██╔══╝██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔══██╗
██║  ███╗██║   ██║███████╗   ██║   ██║  ██║██║  ███╗   ██║   ██║  ███╗███████║██╔████╔██║█████╗  ██████╔╝
██║   ██║██║   ██║╚════██║   ██║   ██║  ██║██║   ██║   ██║   ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ██╔══██╗
╚██████╔╝╚██████╔╝███████║   ██║   ██████╔╝╚██████╔╝   ██║   ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗██║  ██║
 ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   ╚═════╝  ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${R}☢️  GOSTDTGAMER DEPLOYMENT SUITE${NC} ${DG}v1.0${NC}          ${DG}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${DG}                   POWERED BY GOSTDTGAMER${NC}"
    echo ""
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}                    SYSTEM INFORMATION${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # CPU Info
    CPU_CORES=$(nproc)
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    echo -e "${DG}├─ CPU Cores      :${NC} ${W}$CPU_CORES${NC}"
    echo -e "${DG}├─ CPU Model      :${NC} ${W}$CPU_MODEL${NC}"
    
    # RAM Info
    RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    RAM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
    echo -e "${DG}├─ Total RAM      :${NC} ${W}$RAM_TOTAL${NC}"
    echo -e "${DG}├─ Used RAM       :${NC} ${W}$RAM_USED${NC}"
    echo -e "${DG}├─ Free RAM       :${NC} ${W}$RAM_FREE${NC}"
    
    # Disk Info
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    echo -e "${DG}├─ Total Disk     :${NC} ${W}$DISK_TOTAL${NC}"
    echo -e "${DG}├─ Used Disk      :${NC} ${W}$DISK_USED${NC}"
    echo -e "${DG}└─ Free Disk      :${NC} ${W}$DISK_FREE${NC}"
    
    # OS Info
    echo -e "${DG}├─ OS             :${NC} ${W}$OS $VER${NC}"
    
    # IP Info
    IP_PUBLIC=$(curl -s ifconfig.me || echo "Not available")
    echo -e "${DG}└─ Public IP      :${NC} ${W}$IP_PUBLIC${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

update_system() {
    log "Updating system packages..."
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    success "System updated"
}

install_node() {
    log "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y nodejs >> "$LOG_FILE" 2>&1
    success "Node.js installed: $(node -v)"
}

install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh >> "$LOG_FILE" 2>&1
    success "Tailscale installed"
    
    echo -e "\n  ${Y}Tailscale Setup${NC}"
    echo -ne "  ${DG}├─ Do you want to start Tailscale? (y/n): ${NC}"
    read -r start_tailscale
    if [[ "$start_tailscale" == "y" ]]; then
        echo -ne "  ${DG}├─ Enter Tailscale auth key (optional, press Enter for interactive): ${NC}"
        read -r tailscale_key
        if [[ -n "$tailscale_key" ]]; then
            tailscale up --auth-key "$tailscale_key" >> "$LOG_FILE" 2>&1
        else
            tailscale up >> "$LOG_FILE" 2>&1
        fi
        success "Tailscale started"
        tailscale status
    fi
}

install_cloudflared() {
    log "Installing Cloudflared..."
    
    # Add cloudflared repo
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >> "$LOG_FILE" 2>&1
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list >> "$LOG_FILE" 2>&1
    
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y cloudflared >> "$LOG_FILE" 2>&1
    
    success "Cloudflared installed"
    
    echo -e "\n  ${Y}Cloudflare Tunnel Setup${NC}"
    echo -e "  ${DG}├─ You need to authenticate with Cloudflare${NC}"
    echo -ne "  ${DG}├─ Press Enter to start Cloudflare authentication...${NC}"
    read -r
    
    cloudflared tunnel login
    
    echo -ne "\n  ${DG}├─ Enter tunnel name: ${NC}"
    read -r tunnel_name
    
    cloudflared tunnel create "$tunnel_name"
    
    echo -ne "  ${DG}├─ Enter hostname (e.g., example.com): ${NC}"
    read -r hostname
    
    cloudflared tunnel route dns "$tunnel_name" "$hostname"
    
    mkdir -p ~/.cloudflared
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $tunnel_name
credentials-file: /root/.cloudflared/${tunnel_name}.json

ingress:
  - hostname: $hostname
    service: http://localhost:8080
  - service: http_status:404
EOF
    
    echo -e "  ${G}✓ Cloudflare tunnel configured!${NC}"
    echo -e "  ${DG}└─ Run: ${W}cloudflared tunnel run $tunnel_name${NC}"
}

install_parodactak() {
    log "Installing Parodactak..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Clone or download Parodactak (adjust URL as needed)
    if [[ -d "Parodactak" ]]; then
        cd Parodactak
        git pull >> "$LOG_FILE" 2>&1
    else
        git clone https://github.com/yourusername/parodactak.git Parodactak >> "$LOG_FILE" 2>&1 || {
            error "Failed to clone Parodactak repository"
        }
        cd Parodactak
    fi
    
    # Install dependencies
    if [[ -f "package.json" ]]; then
        npm install >> "$LOG_FILE" 2>&1
        success "Parodactak installed with npm dependencies"
    else
        success "Parodactak files downloaded"
    fi
    
    echo -e "\n  ${Y}Parodactak Setup Complete${NC}"
    echo -e "  ${DG}├─ Location: ${W}$INSTALL_DIR/Parodactak${NC}"
    echo -e "  ${DG}└─ Start with: ${W}cd $INSTALL_DIR/Parodactak && npm start${NC}"
}

install_rdp() {
    log "Installing RDP (X2Go) for remote desktop..."
    
    apt-get install -y x2goserver x2goserver-xsession >> "$LOG_FILE" 2>&1
    
    # Install lightweight desktop environment
    apt-get install -y xfce4 xfce4-goodies >> "$LOG_FILE" 2>&1
    
    success "RDP installed (X2Go server)"
    
    echo -e "\n  ${Y}RDP Information${NC}"
    echo -e "  ${DG}├─ Desktop: XFCE4${NC}"
    echo -e "  ${DG}├─ Port: 22 (SSH)${NC}"
    echo -e "  ${DG}└─ Connect using X2Go client with SSH protocol${NC}"
}

install_norfurch() {
    log "Installing Norfurch (Monitoring Tool)..."
    
    # Install basic monitoring tools
    apt-get install -y htop nmon iotop iftop >> "$LOG_FILE" 2>&1
    
    # Install netdata for comprehensive monitoring
    curl -fsSL https://my-netdata.io/kickstart.sh | sh >> "$LOG_FILE" 2>&1
    
    success "Norfurch monitoring tools installed"
    
    echo -e "\n  ${Y}Monitoring Tools Available:${NC}"
    echo -e "  ${DG}├─ htop    : Interactive process viewer${NC}"
    echo -e "  ${DG}├─ nmon    : System performance monitor${NC}"
    echo -e "  ${DG}├─ iotop   : I/O monitoring${NC}"
    echo -e "  ${DG}├─ iftop   : Network bandwidth monitor${NC}"
    echo -e "  ${DG}└─ netdata : Web-based monitoring at http://localhost:19999${NC}"
}

main_menu() {
    clear
    show_specs
    
    echo -e "\n${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${C}                    SELECT COMPONENTS TO INSTALL${NC}"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${G}1)${NC} Install Everything (Full Suite)"
    echo -e "  ${G}2)${NC} Install Node.js"
    echo -e "  ${G}3)${NC} Install Tailscale VPN"
    echo -e "  ${G}4)${NC} Install Cloudflared (Cloudflare Tunnel)"
    echo -e "  ${G}5)${NC} Install Parodactak"
    echo -e "  ${G}6)${NC} Install RDP (X2Go Remote Desktop)"
    echo -e "  ${G}7)${NC} Install Norfurch (Monitoring Tools)"
    echo -e "  ${G}8)${NC} View System Specifications"
    echo -e "  ${G}9)${NC} View Installation Log"
    echo -e "  ${R}0)${NC} Exit"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -ne "  ${W}Enter your choice [0-9]: ${NC}"
    read -r choice
    
    case $choice in
        1)
            update_system
            install_node
            install_tailscale
            install_cloudflared
            install_parodactak
            install_rdp
            install_norfurch
            echo -e "\n${G}✓ Full installation completed!${NC}"
            ;;
        2)
            update_system
            install_node
            ;;
        3)
            update_system
            install_tailscale
            ;;
        4)
            update_system
            install_cloudflared
            ;;
        5)
            update_system
            install_parodactak
            ;;
        6)
            update_system
            install_rdp
            ;;
        7)
            update_system
            install_norfurch
            ;;
        8)
            show_specs
            echo -e "\n${W}Press Enter to continue...${NC}"
            read -r
            main_menu
            ;;
        9)
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
