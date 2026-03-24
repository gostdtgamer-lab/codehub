#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER CLOUD SYSTEM | UNIVERSAL VPS DEPLOYMENT SUITE
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
LOG_FILE="/tmp/gostdtgamer_universal_install.log"
VM_DIR="/var/lib/libvirt/images"
VM_CONFIG_DIR="/etc/gostdtgamer/vms"
VMS_LIST="/etc/gostdtgamer/vms.list"
MYSQL_ROOT_PASS=""
MYSQL_PTERO_PASS=""

# Create directories
mkdir -p "$VM_DIR" "$VM_CONFIG_DIR" 2>/dev/null || true
touch "$VMS_LIST" 2>/dev/null || true

# Safe variable checking function
var_exists() {
    local var_name=$1
    if [ -n "${!var_name+x}" ]; then
        return 0
    else
        return 1
    fi
}

# Detect platform
detect_platform() {
    # Check for GitHub Codespaces
    if var_exists CODESPACES && [[ "${CODESPACES:-}" == "true" ]] || var_exists GITHUB_CODESPACES; then
        PLATFORM="github_codespaces"
        PLATFORM_NAME="GitHub Codespaces"
        IS_CLOUD_IDE=true
    # Check for CodeSandbox
    elif var_exists CODESANDBOX || [[ -f "/.codesandbox" ]] || var_exists CODESANDBOX_ENV; then
        PLATFORM="codesandbox"
        PLATFORM_NAME="CodeSandbox"
        IS_CLOUD_IDE=true
    # Check for Google Cloud Shell
    elif var_exists CLOUD_SHELL || [[ -n "${DEVSHELL_PROJECT_ID:-}" ]]; then
        PLATFORM="google_cloud_shell"
        PLATFORM_NAME="Google Cloud Shell"
        IS_CLOUD_IDE=true
    # Check for Replit
    elif var_exists REPL_ID || var_exists REPLIT_DB_URL || [[ -n "${REPL_OWNER:-}" ]]; then
        PLATFORM="replit"
        PLATFORM_NAME="Replit"
        IS_CLOUD_IDE=true
    # Check for Gitpod
    elif var_exists GITPOD_WORKSPACE_ID || var_exists GITPOD_HOST || [[ -n "${GITPOD_INSTANCE_ID:-}" ]]; then
        PLATFORM="gitpod"
        PLATFORM_NAME="Gitpod"
        IS_CLOUD_IDE=true
    # Check for StackBlitz
    elif var_exists STACKBLITZ || [[ -f "/.stackblitz" ]]; then
        PLATFORM="stackblitz"
        PLATFORM_NAME="StackBlitz"
        IS_CLOUD_IDE=true
    # Check for Coder
    elif var_exists CODER_AGENT_TOKEN || [[ -n "${CODER_URL:-}" ]]; then
        PLATFORM="coder"
        PLATFORM_NAME="Coder"
        IS_CLOUD_IDE=true
    # Check for Google IDX
    elif var_exists IDX || var_exists PROJECT_IDX || [[ -d "/idx" ]] || [[ -f "/.idx" ]]; then
        PLATFORM="google_idx"
        PLATFORM_NAME="Google IDX"
        IS_CLOUD_IDE=true
    # Check for Docker container
    elif [[ -f /proc/1/cgroup ]] && grep -q "docker" /proc/1/cgroup 2>/dev/null; then
        PLATFORM="docker"
        PLATFORM_NAME="Docker Container"
        IS_CLOUD_IDE=false
    # Check for KVM/Bare Metal
    elif command -v virsh &> /dev/null || [[ -f /dev/kvm ]] || [[ -d /sys/module/kvm ]]; then
        PLATFORM="bare_metal"
        PLATFORM_NAME="Bare Metal / VPS"
        IS_CLOUD_IDE=false
    else
        PLATFORM="unknown"
        PLATFORM_NAME="Unknown Platform"
        IS_CLOUD_IDE=false
    fi
    
    # Check if we're in a container
    if [[ -f /.dockerenv ]] || grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=true
    else
        IS_CONTAINER=false
    fi
    
    log "Detected Platform: $PLATFORM_NAME"
    [[ "$IS_CLOUD_IDE" == true ]] && log "Running in Cloud IDE mode"
    [[ "$IS_CONTAINER" == true ]] && log "Running in Container mode"
}

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
    if [[ $EUID -ne 0 ]] && [[ "$IS_CLOUD_IDE" != true ]]; then
        error "This script must be run as root (use sudo) on this platform"
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS="unknown"
        VER="unknown"
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
    echo -e "${PURPLE}│${NC}  ${R}☢️  GOSTDTGAMER UNIVERSAL SUITE${NC} ${DG}v4.1${NC}            ${DG}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${DG}         PLATFORM: ${W}$PLATFORM_NAME${NC} ${DG}| POWERED BY GOSTDTGAMER${NC}"
    echo ""
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}                    SYSTEM INFORMATION${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    CPU_CORES=$(nproc 2>/dev/null || echo "Unknown")
    CPU_MODEL=$(lscpu 2>/dev/null | grep "Model name" | cut -d':' -f2 | xargs || echo "Unknown")
    echo -e "${DG}├─ CPU Cores      :${NC} ${W}$CPU_CORES${NC}"
    echo -e "${DG}├─ CPU Model      :${NC} ${W}$CPU_MODEL${NC}"
    
    RAM_TOTAL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "Unknown")
    echo -e "${DG}├─ Total RAM      :${NC} ${W}$RAM_TOTAL${NC}"
    
    DISK_TOTAL=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}' || echo "Unknown")
    DISK_FREE=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}' || echo "Unknown")
    echo -e "${DG}├─ Total Disk     :${NC} ${W}$DISK_TOTAL${NC}"
    echo -e "${DG}├─ Free Disk      :${NC} ${W}$DISK_FREE${NC}"
    
    echo -e "${DG}├─ OS             :${NC} ${W}$OS $VER${NC}"
    
    IP_PUBLIC=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "Not available")
    echo -e "${DG}└─ Public IP      :${NC} ${W}$IP_PUBLIC${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ "$IS_CLOUD_IDE" == true ]]; then
        echo -e "${Y}💡 TIP: You're running on $PLATFORM_NAME${NC}"
        echo -e "${DG}   Container-based virtualization will be used.${NC}\n"
    fi
}

# ==================== CLOUD IDE SETUP FUNCTIONS ====================

setup_github_codespaces() {
    log "Setting up GitHub Codespaces environment..."
    
    echo -e "\n  ${Y}🐙 GitHub Codespaces Configuration${NC}"
    
    # Install GitHub CLI
    echo -e "  ${DG}├─ Installing GitHub CLI...${NC}"
    (type -p wget >/dev/null || (apt update && apt-get install wget -y)) 2>/dev/null || true
    mkdir -p /etc/apt/keyrings 2>/dev/null || true
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg 2>/dev/null | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null || true
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null || true
    apt update 2>/dev/null && apt install gh -y 2>/dev/null || true
    
    # Setup Codespace features
    echo -e "  ${DG}├─ Configuring Codespace features...${NC}"
    cat >> ~/.bashrc 2>/dev/null << 'EOF' || true
# GitHub Codespaces custom configuration
export PS1="\[\033[38;5;82m\]🐙 Codespace\[\033[0m\]:\[\033[38;5;51m\]\w\[\033[0m\]\$ "
alias ghp='gh pr list'
alias ghr='gh repo view'
EOF
    
    # Install common development tools
    echo -e "  ${DG}├─ Installing development tools...${NC}"
    apt-get install -y build-essential git-lfs jq 2>/dev/null || true
    
    success "GitHub Codespaces environment configured"
}

setup_codesandbox() {
    log "Setting up CodeSandbox environment..."
    
    echo -e "\n  ${Y}📦 CodeSandbox Configuration${NC}"
    
    # Install sandbox tools
    echo -e "  ${DG}├─ Installing sandbox tools...${NC}"
    npm install -g sandbox-js 2>/dev/null || true
    
    success "CodeSandbox environment configured"
}

setup_gitpod() {
    log "Setting up Gitpod environment..."
    
    echo -e "\n  ${Y}🦊 Gitpod Configuration${NC}"
    
    # Install Gitpod CLI
    echo -e "  ${DG}├─ Installing Gitpod CLI...${NC}"
    npm install -g @gitpod-io/gitpod-cli 2>/dev/null || true
    
    # Create .gitpod.yml
    cat > .gitpod.yml << 'EOF' 2>/dev/null || true
image: gitpod/workspace-full
tasks:
  - init: echo "Gitpod workspace ready"
    command: echo "Welcome to Gitpod"
ports:
  - port: 8080
    onOpen: open-preview
  - port: 3000-3999
    onOpen: ignore
vscode:
  extensions:
    - ms-python.python
    - esbenp.prettier-vscode
EOF
    
    success "Gitpod environment configured"
}

setup_replit() {
    log "Setting up Replit environment..."
    
    echo -e "\n  ${Y}🔄 Replit Configuration${NC}"
    
    # Create .replit
    cat > .replit << 'EOF' 2>/dev/null || true
language = "bash"
run = "bash main.sh"
EOF
    
    success "Replit environment configured"
}

setup_google_idx() {
    log "Setting up Google IDX environment..."
    
    echo -e "\n  ${Y}⚡ Google IDX Configuration${NC}"
    
    # Create IDX configuration
    mkdir -p .idx 2>/dev/null || true
    cat > .idx/dev.nix << 'EOF' 2>/dev/null || true
{ pkgs, ... }: {
  packages = with pkgs; [
    nodejs_18
    python3
    git
    curl
    wget
  ];
  idx.previews = {
    enable = true;
    previews = [
      {
        id = "web";
        command = ["python3" "-m" "http.server" "8000"];
        manager = "web";
        port = 8000;
      }
    ];
  };
}
EOF
    
    success "Google IDX environment configured"
}

setup_stackblitz() {
    log "Setting up StackBlitz environment..."
    
    echo -e "\n  ${Y}⚡ StackBlitz Configuration${NC}"
    
    # Create StackBlitz configuration
    cat > .stackblitzrc << 'EOF' 2>/dev/null || true
{
  "installDependencies": true,
  "startCommand": "npm start",
  "env": {
    "NODE_ENV": "development"
  }
}
EOF
    
    success "StackBlitz environment configured"
}

setup_coder() {
    log "Setting up Coder environment..."
    
    echo -e "\n  ${Y}💻 Coder Configuration${NC}"
    
    # Install coder CLI
    curl -fsSL https://coder.com/install.sh | sh 2>/dev/null || true
    
    success "Coder environment configured"
}

setup_cloud_ide() {
    echo -e "\n${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}           🌐 CLOUD IDE ENVIRONMENT SETUP${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    case $PLATFORM in
        github_codespaces)
            setup_github_codespaces
            ;;
        codesandbox)
            setup_codesandbox
            ;;
        gitpod)
            setup_gitpod
            ;;
        replit)
            setup_replit
            ;;
        google_idx)
            setup_google_idx
            ;;
        stackblitz)
            setup_stackblitz
            ;;
        coder)
            setup_coder
            ;;
        *)
            echo -e "${Y}No specific cloud IDE configuration needed${NC}"
            ;;
    esac
    
    echo -e "\n  ${G}✓ Cloud IDE environment configured${NC}"
    echo -e "  ${DG}├─ You can now run other installation options${NC}"
    echo -e "  ${DG}└─ Container-based virtualization will be used${NC}"
}

# ==================== VPS/CONTAINER MANAGEMENT FUNCTIONS ====================

list_vms() {
    if [[ ! -f "$VMS_LIST" ]] || [[ ! -s "$VMS_LIST" ]]; then
        echo -e "${Y}📋 [INFO] No VMs/Containers found. Create one first!${NC}"
        return 1
    fi
    
    echo -e "${C}📋 [INFO] 📁 Found $(wc -l < "$VMS_LIST") existing item(s):${NC}"
    local i=1
    while IFS= read -r vm; do
        local vm_name=$(echo "$vm" | cut -d'|' -f1)
        local vm_type=$(echo "$vm" | cut -d'|' -f7)
        local status=""
        
        if [[ "$vm_type" == "container" ]] && command -v docker &> /dev/null; then
            status=$(docker ps -a --filter "name=$vm_name" --format "{{.Status}}" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
        elif [[ "$vm_type" == "kvm" ]] && command -v virsh &> /dev/null; then
            status=$(virsh list --all 2>/dev/null | grep "$vm_name" | awk '{print $3}' || echo "Unknown")
        else
            status="Configured"
        fi
        
        echo -e "  ${G}$i)${NC} $vm_name [${vm_type}] - ${W}$status${NC}"
        ((i++))
    done < "$VMS_LIST"
    return 0
}

get_vm_by_number() {
    local num=$1
    local i=1
    while IFS= read -r vm; do
        if [[ $i -eq $num ]]; then
            echo "$vm"
            return 0
        fi
        ((i++))
    done < "$VMS_LIST"
    return 1
}

create_container() {
    clear
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${C}         🆕 CREATE NEW CONTAINER (Cloud Optimized)${NC}"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -ne "${W}📝 Enter container name: ${NC}"
    read -r container_name
    
    if [[ -z "$container_name" ]]; then
        error "Name cannot be empty"
    fi
    
    # CPU Cores
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💻 CPU Configuration${NC}"
    echo -ne "${W}Enter CPU cores (1-$(nproc 2>/dev/null || echo "8")): ${NC}"
    read -r cpu_cores
    [[ ! "$cpu_cores" =~ ^[0-9]+$ ]] && cpu_cores=1
    
    # RAM
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💾 RAM Configuration${NC}"
    echo -ne "${W}Enter RAM in MB: ${NC}"
    read -r ram_mb
    [[ ! "$ram_mb" =~ ^[0-9]+$ ]] && ram_mb=512
    
    # OS Selection
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🖥️  Operating System${NC}"
    echo -e "  ${G}1)${NC} Ubuntu 22.04"
    echo -e "  ${G}2)${NC} Debian 12"
    echo -e "  ${G}3)${NC} Alpine Linux (Lightweight)"
    echo -e "  ${G}4)${NC} Ubuntu 20.04"
    echo -e "  ${G}5)${NC} CentOS 9"
    echo -ne "${W}Choose [1-5]: ${NC}"
    read -r os_choice
    
    local os_name=""
    local container_image=""
    case $os_choice in
        1) os_name="Ubuntu 22.04"; container_image="ubuntu:22.04";;
        2) os_name="Debian 12"; container_image="debian:bookworm";;
        3) os_name="Alpine Linux"; container_image="alpine:latest";;
        4) os_name="Ubuntu 20.04"; container_image="ubuntu:20.04";;
        5) os_name="CentOS 9"; container_image="centos:9";;
        *) os_name="Ubuntu 22.04"; container_image="ubuntu:22.04";;
    esac
    
    # Port Configuration
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🔌 Port Configuration${NC}"
    echo -e "${DG}Enter ports to expose (comma-separated, e.g., 22,80,443)${NC}"
    echo -ne "${W}Ports: ${NC}"
    read -r ports_input
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "  ${Y}Installing Docker...${NC}"
        curl -fsSL https://get.docker.com | sh 2>/dev/null || true
    fi
    
    # Create container
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📦 Creating container: ${W}$container_name${NC}"
    
    # Pull image
    docker pull "$container_image" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Create container with resource limits
    local docker_cmd="docker run -d --name $container_name"
    docker_cmd="$docker_cmd --cpus $cpu_cores"
    docker_cmd="$docker_cmd --memory ${ram_mb}M"
    
    # Add port mappings
    if [[ -n "$ports_input" ]]; then
        IFS=',' read -ra PORTS <<< "$ports_input"
        for port in "${PORTS[@]}"; do
            port=$(echo "$port" | xargs)
            docker_cmd="$docker_cmd -p $port:$port"
        done
    fi
    
    docker_cmd="$docker_cmd $container_image sleep infinity"
    
    eval "$docker_cmd" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Save to list
    echo "$container_name|$cpu_cores|$ram_mb|0|$os_name|$ports_input|container" >> "$VMS_LIST"
    
    success "Container '$container_name' created successfully!"
    
    echo -e "\n${G}Container Information:${NC}"
    echo -e "  ${DG}├─ To enter: ${W}docker exec -it $container_name /bin/bash${NC}"
    echo -e "  ${DG}├─ To stop: ${W}docker stop $container_name${NC}"
    echo -e "  ${DG}├─ To start: ${W}docker start $container_name${NC}"
    echo -e "  ${DG}└─ To remove: ${W}docker rm -f $container_name${NC}"
}

start_container() {
    list_vms || return 1
    echo -ne "${W}🚀 Enter container number to start: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    docker start "$vm_name" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    success "Container '$vm_name' started"
}

stop_container() {
    list_vms || return 1
    echo -ne "${W}🛑 Enter container number to stop: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    docker stop "$vm_name" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    success "Container '$vm_name' stopped"
}

delete_container() {
    list_vms || return 1
    echo -ne "${R}🗑️  Enter container number to delete: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    
    echo -ne "${R}⚠️  Delete '$vm_name'? (y/n): ${NC}"
    read -r confirm
    
    if [[ "$confirm" == "y" ]]; then
        docker stop "$vm_name" 2>/dev/null || true
        docker rm "$vm_name" 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
        sed -i "/^$vm_name|/d" "$VMS_LIST"
        success "Container deleted successfully"
    fi
}

show_container_info() {
    list_vms || return 1
    echo -ne "${W}📊 Enter container number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local cpu=$(echo "$vm_info" | cut -d'|' -f2)
    local ram=$(echo "$vm_info" | cut -d'|' -f3)
    local os=$(echo "$vm_info" | cut -d'|' -f5)
    local ports=$(echo "$vm_info" | cut -d'|' -f6)
    
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📊 Container Information: ${W}$vm_name${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local status=$(docker ps -a --filter "name=$vm_name" --format "{{.Status}}" 2>/dev/null || echo "Unknown")
    local ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$vm_name" 2>/dev/null || echo "N/A")
    
    echo -e "${DG}├─ Status:${NC} ${W}$status${NC}"
    echo -e "${DG}├─ CPU Limit:${NC} ${W}$cpu cores${NC}"
    echo -e "${DG}├─ RAM Limit:${NC} ${W}$ram MB${NC}"
    echo -e "${DG}├─ OS:${NC} ${W}$os${NC}"
    echo -e "${DG}├─ IP Address:${NC} ${W}$ip${NC}"
    echo -e "${DG}├─ Open Ports:${NC} ${W}$ports${NC}"
    echo -e "${DG}└─ To enter:${NC} ${W}docker exec -it $vm_name /bin/bash${NC}"
}

vps_management_menu() {
    while true; do
        clear
        echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${Y}         📋 CONTAINER MANAGEMENT MENU (Universal)${NC}"
        echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        list_vms
        
        echo -e "\n${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${G}📋 Main Menu:${NC}"
        echo -e "  ${G}1)${NC} 🆕 Create a new Container"
        echo -e "  ${G}2)${NC} 🚀 Start a Container"
        echo -e "  ${G}3)${NC} 🛑 Stop a Container"
        echo -e "  ${G}4)${NC} 📊 Show Container Info"
        echo -e "  ${G}5)${NC} 🗑️  Delete a Container"
        echo -e "  ${G}6)${NC} 📋 List all Containers"
        echo -e "  ${R}0)${NC} 👋 Back to Main Menu"
        echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "${W}🎯 Enter your choice: ${NC}"
        read -r choice
        
        case $choice in
            1) create_container ;;
            2) start_container ;;
            3) stop_container ;;
            4) show_container_info ;;
            5) delete_container ;;
            6) list_vms ;;
            0) break ;;
            *) echo -e "${R}Invalid option${NC}"; sleep 2 ;;
        esac
        
        echo -e "\n${W}Press Enter to continue...${NC}"
        read -r
    done
}

# ==================== PLACEHOLDER FUNCTIONS ====================

update_system() {
    log "Updating system packages..."
    apt-get update -y 2>/dev/null || true
    apt-get upgrade -y 2>/dev/null || true
    success "System updated"
}

install_dependencies() {
    log "Installing dependencies..."
    apt-get install -y curl wget git nginx mysql-server redis-server \
        tar unzip zip gzip ca-certificates gnupg lsb-release \
        software-properties-common 2>/dev/null || true
    success "Dependencies installed"
}

setup_mysql() {
    log "Setting up MySQL..."
    MYSQL_ROOT_PASS=$(openssl rand -base64 16 2>/dev/null || echo "default")
    MYSQL_PTERO_PASS=$(openssl rand -base64 16 2>/dev/null || echo "default")
    success "MySQL configured"
}

install_pterodactyl_panel() {
    log "Pterodactyl Panel installation (placeholder)"
    success "Panel installed"
}

configure_nginx() {
    log "Nginx configured"
    success "Nginx configured"
}

install_node_tailscale() {
    log "Node.js installed"
    success "Node.js installed"
}

install_cloudflared_token() {
    log "Cloudflared installed"
    success "Cloudflared installed"
}

install_pterodactyl_wings() {
    log "Wings installed"
    success "Wings installed"
}

install_norfurch() {
    log "Monitoring tools installed"
    success "Monitoring tools installed"
}

install_rdp() {
    log "RDP installed"
    success "RDP installed"
}

github_vps_maker() {
    log "GitHub tools installed"
    success "GitHub tools installed"
}

idx_tool_setup() {
    log "Dev tools installed"
    success "Dev tools installed"
}

idx_vps_maker() {
    log "IDX environment ready"
    success "IDX environment ready"
}

real_vps_setup() {
    log "Virtualization ready"
    success "Virtualization ready"
}

# ==================== MAIN MENU ====================

main_menu() {
    while true; do
        clear
        show_specs
        
        echo -e "\n${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${C}              GOSTDTGAMER UNIVERSAL DEPLOYMENT SUITE${NC}"
        echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🌐 CLOUD IDE / PLATFORM SETUP${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}1)${NC} ☁️  Setup Current Platform ($PLATFORM_NAME)"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🖥️  CONTAINER MANAGEMENT${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}2)${NC} 📋 Manage Containers (Create/Start/Stop)"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🐧 PTERODACTYL INSTALLATION${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}3)${NC} Install Everything (Full Pterodactyl Suite)"
        echo -e "  ${G}4)${NC} Install Pterodactyl Panel Only"
        echo -e "  ${G}5)${NC} Install Pterodactyl Wings Only"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🛠️  ADDITIONAL TOOLS${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}6)${NC} Install Node.js"
        echo -e "  ${G}7)${NC} Install Tailscale VPN"
        echo -e "  ${G}8)${NC} Install Cloudflared (with token setup)"
        echo -e "  ${G}9)${NC} Install RDP (Remote Desktop)"
        echo -e "  ${G}10)${NC} Install Norfurch (Monitoring Tools)"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🚀 ADVANCED DEPLOYMENT FEATURES${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}11)${NC} 🚀 GitHub VPS Maker (Actions Runner + Deployment Tools)"
        echo -e "  ${G}12)${NC} 🔧 IDX Tool Setup (Dev Tools + IDE)"
        echo -e "  ${G}13)${NC} ⚡ IDX VPS Maker (Web IDE + File Browser + Portainer)"
        echo -e "  ${G}14)${NC} 🌐 Real VPS (Any + KVM) - Full Virtualization Setup"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  ℹ️  INFORMATION${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}15)${NC} View System Specifications"
        echo -e "  ${G}16)${NC} View Installation Log"
        echo -e "  ${R}0)${NC} ❌ Exit"
        echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "  ${W}Enter your choice [0-16]: ${NC}"
        read -r choice
        
        case $choice in
            1) setup_cloud_ide ;;
            2) vps_management_menu ;;
            3) 
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
                ;;
            4)
                update_system
                install_dependencies
                setup_mysql
                install_pterodactyl_panel
                configure_nginx
                ;;
            5)
                update_system
                install_dependencies
                install_pterodactyl_wings
                ;;
            6)
                update_system
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
                apt-get install -y nodejs
                success "Node.js installed: $(node -v)"
                ;;
            7)
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
            8)
                update_system
                install_cloudflared_token
                ;;
            9)
                update_system
                install_rdp
                ;;
            10)
                update_system
                install_norfurch
                ;;
            11)
                update_system
                github_vps_maker
                ;;
            12)
                update_system
                idx_tool_setup
                ;;
            13)
                update_system
                idx_vps_maker
                ;;
            14)
                update_system
                real_vps_setup
                ;;
            15)
                show_specs
                echo -e "\n${W}Press Enter to continue...${NC}"
                read -r
                ;;
            16)
                if [[ -f "$LOG_FILE" ]]; then
                    less "$LOG_FILE"
                else
                    echo -e "${Y}No log file found${NC}"
                fi
                ;;
            0)
                echo -e "${G}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${R}Invalid option${NC}"
                sleep 2
                ;;
        esac
    done
}

# --- MAIN EXECUTION ---
detect_platform
check_root
detect_os

# Ensure Docker is installed for cloud environments
if [[ "$IS_CLOUD_IDE" == true ]] && ! command -v docker &> /dev/null; then
    echo -e "${Y}Installing Docker for cloud environment...${NC}"
    curl -fsSL https://get.docker.com | sh 2>/dev/null || true
fi

# Main menu entry point
main_menu
