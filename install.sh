#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER VPS DEPLOYMENT SUITE
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
NC='\033[0m'

# Config
LOG_FILE="/tmp/gostdtgamer.log"
VM_LIST="/tmp/vms.list"
touch "$VM_LIST"

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

# Show system info
show_info() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
   _____       _       _   _           _     
  / ____|     | |     | | | |         | |    
 | |  __  ___ | |_ ___| |_| | __ _  __| |___ 
 | | |_ |/ _ \| __/ _ \  _  |/ _` |/ _` / __|
 | |__| | (_) | ||  __/ | | | (_| | (_| \__ \
  \_____|\___/ \__\___\_| |_/\__,_|\__,_|___/
                                             
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}         GOSTDTGAMER VPS DEPLOYMENT SUITE${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # System info
    echo -e "${CYAN}System Information:${NC}"
    echo -e "  CPU Cores: $(nproc)"
    echo -e "  RAM: $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "  Disk: $(df -h / | awk 'NR==2 {print $2}') (Free: $(df -h / | awk 'NR==2 {print $4}'))"
    echo -e "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "  IP: $(curl -s ifconfig.me 2>/dev/null || echo 'Unknown')"
    echo ""
}

# List VMs
list_vms() {
    if [[ ! -s "$VM_LIST" ]]; then
        echo -e "${YELLOW}No VMs found. Create one first!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Existing VMs:${NC}"
    local i=1
    while IFS='|' read -r name cpu ram disk os ports; do
        echo -e "  ${YELLOW}$i)${NC} $name - ${WHITE}${cpu} CPU | ${ram}MB RAM | ${disk}GB Disk | $os${NC}"
        ((i++))
    done < "$VM_LIST"
    return 0
}

# Create container (for cloud/any environment)
create_container() {
    clear
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    CREATE NEW CONTAINER${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get name
    echo -ne "${WHITE}Container name: ${NC}"
    read name
    [[ -z "$name" ]] && error "Name required"
    
    # CPU
    echo -ne "${WHITE}CPU cores (1-$(nproc)): ${NC}"
    read cpu
    [[ ! "$cpu" =~ ^[0-9]+$ ]] && cpu=1
    
    # RAM
    echo -ne "${WHITE}RAM in MB (512, 1024, 2048): ${NC}"
    read ram
    [[ ! "$ram" =~ ^[0-9]+$ ]] && ram=512
    
    # Disk
    echo -ne "${WHITE}Disk size in GB (10, 20, 50): ${NC}"
    read disk
    [[ ! "$disk" =~ ^[0-9]+$ ]] && disk=10
    
    # OS
    echo -e "${CYAN}Select OS:${NC}"
    echo "  1) Ubuntu 22.04"
    echo "  2) Ubuntu 20.04"
    echo "  3) Debian 12"
    echo "  4) Alpine Linux"
    echo -ne "${WHITE}Choice: ${NC}"
    read os_choice
    
    case $os_choice in
        1) os="Ubuntu 22.04"; image="ubuntu:22.04";;
        2) os="Ubuntu 20.04"; image="ubuntu:20.04";;
        3) os="Debian 12"; image="debian:bookworm";;
        4) os="Alpine Linux"; image="alpine:latest";;
        *) os="Ubuntu 22.04"; image="ubuntu:22.04";;
    esac
    
    # Ports
    echo -ne "${WHITE}Ports to open (e.g., 22,80,443): ${NC}"
    read ports
    
    # Install Docker if needed
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Installing Docker...${NC}"
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    fi
    
    # Create container
    echo -e "${YELLOW}Creating container...${NC}"
    docker pull "$image"
    
    # Build command
    cmd="docker run -d --name $name --cpus $cpu --memory ${ram}M"
    
    # Add ports
    if [[ -n "$ports" ]]; then
        IFS=',' read -ra PORTS <<< "$ports"
        for port in "${PORTS[@]}"; do
            cmd="$cmd -p $port:$port"
        done
    fi
    
    cmd="$cmd $image sleep infinity"
    eval "$cmd"
    
    # Save to list
    echo "$name|$cpu|$ram|$disk|$os|$ports" >> "$VM_LIST"
    
    success "Container '$name' created!"
    echo ""
    echo -e "${GREEN}Container info:${NC}"
    echo -e "  Enter: docker exec -it $name /bin/bash"
    echo -e "  Stop:  docker stop $name"
    echo -e "  Start: docker start $name"
    echo -e "  Remove: docker rm -f $name"
}

# Start container
start_container() {
    list_vms || return
    echo -ne "${WHITE}Enter number to start: ${NC}"
    read num
    
    local i=1
    while IFS='|' read -r name cpu ram disk os ports; do
        if [[ $i -eq $num ]]; then
            docker start "$name"
            success "Container '$name' started"
            return
        fi
        ((i++))
    done < "$VM_LIST"
    error "Invalid number"
}

# Stop container
stop_container() {
    list_vms || return
    echo -ne "${WHITE}Enter number to stop: ${NC}"
    read num
    
    local i=1
    while IFS='|' read -r name cpu ram disk os ports; do
        if [[ $i -eq $num ]]; then
            docker stop "$name"
            success "Container '$name' stopped"
            return
        fi
        ((i++))
    done < "$VM_LIST"
    error "Invalid number"
}

# Delete container
delete_container() {
    list_vms || return
    echo -ne "${RED}Enter number to delete: ${NC}"
    read num
    
    local i=1
    while IFS='|' read -r name cpu ram disk os ports; do
        if [[ $i -eq $num ]]; then
            echo -ne "${RED}Delete '$name'? (y/n): ${NC}"
            read confirm
            if [[ "$confirm" == "y" ]]; then
                docker stop "$name" 2>/dev/null
                docker rm "$name" 2>/dev/null
                sed -i "/^$name|/d" "$VM_LIST"
                success "Container deleted"
            fi
            return
        fi
        ((i++))
    done < "$VM_LIST"
    error "Invalid number"
}

# Show container info
show_container_info() {
    list_vms || return
    echo -ne "${WHITE}Enter number: ${NC}"
    read num
    
    local i=1
    while IFS='|' read -r name cpu ram disk os ports; do
        if [[ $i -eq $num ]]; then
            clear
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Container: $name${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            status=$(docker ps -a --filter "name=$name" --format "{{.Status}}")
            ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null)
            
            echo -e "${CYAN}Status:${NC} $status"
            echo -e "${CYAN}CPU:${NC} $cpu cores"
            echo -e "${CYAN}RAM:${NC} $ram MB"
            echo -e "${CYAN}Disk:${NC} $disk GB"
            echo -e "${CYAN}OS:${NC} $os"
            echo -e "${CYAN}IP:${NC} $ip"
            echo -e "${CYAN}Ports:${NC} $ports"
            echo ""
            echo -e "${GREEN}Commands:${NC}"
            echo -e "  Enter: docker exec -it $name /bin/bash"
            echo -e "  Logs:  docker logs $name"
            return
        fi
        ((i++))
    done < "$VM_LIST"
    error "Invalid number"
}

# Install Node.js
install_node() {
    log "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    success "Node.js installed: $(node -v)"
}

# Install Tailscale
install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    success "Tailscale installed"
    
    echo -ne "Start Tailscale now? (y/n): "
    read start_ts
    if [[ "$start_ts" == "y" ]]; then
        tailscale up
    fi
}

# Install Cloudflared
install_cloudflared() {
    log "Installing Cloudflared..."
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list
    apt-get update
    apt-get install -y cloudflared
    success "Cloudflared installed"
    
    echo -e "${YELLOW}To setup tunnel: cloudflared tunnel login${NC}"
}

# Install monitoring
install_monitoring() {
    log "Installing monitoring tools..."
    apt-get install -y htop nmon iotop iftop
    success "Monitoring tools installed"
}

# Install RDP
install_rdp() {
    log "Installing RDP..."
    apt-get install -y x2goserver x2goserver-xsession xfce4
    success "RDP installed"
}

# Pterodactyl installer (simplified)
install_pterodactyl() {
    log "Installing Pterodactyl dependencies..."
    apt-get update
    apt-get install -y curl wget git nginx mysql-server redis-server php8.1 php8.1-{cli,common,curl,gd,mysql,mbstring,bcmath,xml,fpm,zip,redis}
    
    # Install Docker
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    
    # Install Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    
    # Download Panel
    cd /var/www
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 pterodactyl/storage pterodactyl/bootstrap/cache
    
    cd pterodactyl
    cp .env.example .env
    composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    
    success "Pterodactyl panel downloaded. Complete setup at: http://$(curl -s ifconfig.me)"
}

# Main menu
main_menu() {
    while true; do
        show_info
        
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}MAIN MENU${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  1) 📦 Manage Containers (Create/Start/Stop)"
        echo "  2) 🐧 Install Pterodactyl Panel"
        echo "  3) 📦 Install Node.js"
        echo "  4) 🔒 Install Tailscale VPN"
        echo "  5) ☁️  Install Cloudflared"
        echo "  6) 📊 Install Monitoring Tools"
        echo "  7) 🖥️  Install RDP"
        echo "  8) ℹ️  Show System Info"
        echo "  0) ❌ Exit"
        echo ""
        echo -ne "${WHITE}Enter choice: ${NC}"
        read choice
        
        case $choice in
            1) 
                while true; do
                    clear
                    show_info
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${GREEN}CONTAINER MANAGEMENT${NC}"
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    list_vms
                    echo ""
                    echo "  1) Create new container"
                    echo "  2) Start container"
                    echo "  3) Stop container"
                    echo "  4) Show container info"
                    echo "  5) Delete container"
                    echo "  6) Back to main menu"
                    echo ""
                    echo -ne "${WHITE}Choice: ${NC}"
                    read subchoice
                    
                    case $subchoice in
                        1) create_container ;;
                        2) start_container ;;
                        3) stop_container ;;
                        4) show_container_info ;;
                        5) delete_container ;;
                        6) break ;;
                        *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
                    esac
                    
                    echo ""
                    echo -ne "${WHITE}Press Enter...${NC}"
                    read
                done
                ;;
            2) 
                install_pterodactyl
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            3) 
                install_node
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            4) 
                install_tailscale
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            5) 
                install_cloudflared
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            6) 
                install_monitoring
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            7) 
                install_rdp
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            8) 
                show_info
                echo -ne "${WHITE}Press Enter...${NC}"
                read
                ;;
            0) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Start
check_root
main_menu
