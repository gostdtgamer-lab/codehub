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

# Detect platform
detect_platform() {
    if [[ -n "${CODESPACES}" ]] || [[ -n "${GITHUB_CODESPACES}" ]]; then
        PLATFORM="github_codespaces"
        PLATFORM_NAME="GitHub Codespaces"
        IS_CLOUD_IDE=true
    elif [[ -n "${CODESANDBOX}" ]] || [[ -f "/.codesandbox" ]]; then
        PLATFORM="codesandbox"
        PLATFORM_NAME="CodeSandbox"
        IS_CLOUD_IDE=true
    elif [[ -n "${GOOGLE_CLOUD_SHELL}" ]] || [[ -n "${CLOUD_SHELL}" ]]; then
        PLATFORM="google_cloud_shell"
        PLATFORM_NAME="Google Cloud Shell"
        IS_CLOUD_IDE=true
    elif [[ -n "${REPLIT_DB_URL}" ]] || [[ -n "${REPL_ID}" ]]; then
        PLATFORM="replit"
        PLATFORM_NAME="Replit"
        IS_CLOUD_IDE=true
    elif [[ -n "${GITPOD_WORKSPACE_ID}" ]] || [[ -n "${GITPOD_HOST}" ]]; then
        PLATFORM="gitpod"
        PLATFORM_NAME="Gitpod"
        IS_CLOUD_IDE=true
    elif [[ -n "${STACKBLITZ}" ]]; then
        PLATFORM="stackblitz"
        PLATFORM_NAME="StackBlitz"
        IS_CLOUD_IDE=true
    elif [[ -n "${CODER}" ]] || [[ -n "${CODER_AGENT_TOKEN}" ]]; then
        PLATFORM="coder"
        PLATFORM_NAME="Coder"
        IS_CLOUD_IDE=true
    elif [[ -n "${PROJECT_IDX}" ]] || [[ -n "${IDX}" ]]; then
        PLATFORM="google_idx"
        PLATFORM_NAME="Google IDX"
        IS_CLOUD_IDE=true
    elif [[ -f /proc/1/cgroup ]] && grep -q "docker" /proc/1/cgroup; then
        PLATFORM="docker"
        PLATFORM_NAME="Docker Container"
        IS_CLOUD_IDE=false
    elif command -v virsh &> /dev/null || [[ -f /dev/kvm ]]; then
        PLATFORM="bare_metal"
        PLATFORM_NAME="Bare Metal / VPS"
        IS_CLOUD_IDE=false
    else
        PLATFORM="unknown"
        PLATFORM_NAME="Unknown Platform"
        IS_CLOUD_IDE=false
    fi
    
    log "Detected Platform: $PLATFORM_NAME"
}

# Create directories
mkdir -p "$VM_DIR" "$VM_CONFIG_DIR"
touch "$VMS_LIST"

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
    if [[ $EUID -ne 0 ]] && [[ "$PLATFORM" != "github_codespaces" ]] && [[ "$PLATFORM" != "codesandbox" ]] && [[ "$PLATFORM" != "gitpod" ]]; then
        error "This script must be run as root (use sudo) on this platform"
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
    echo -e "${PURPLE}│${NC}  ${R}☢️  GOSTDTGAMER UNIVERSAL SUITE${NC} ${DG}v4.0${NC}            ${DG}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${DG}         PLATFORM: ${W}$PLATFORM_NAME${NC} ${DG}| POWERED BY GOSTDTGAMER${NC}"
    echo ""
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}                    SYSTEM INFORMATION${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    CPU_CORES=$(nproc)
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs || echo "Unknown")
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
    
    if [[ "$IS_CLOUD_IDE" == true ]]; then
        echo -e "${Y}💡 TIP: You're running on $PLATFORM_NAME${NC}"
        echo -e "${DG}   Some virtualization features may be limited. Use compatible options.${NC}\n"
    fi
}

# ==================== CLOUD IDE SETUP FUNCTIONS ====================

setup_github_codespaces() {
    log "Setting up GitHub Codespaces environment..."
    
    echo -e "\n  ${Y}🐙 GitHub Codespaces Configuration${NC}"
    
    # Install GitHub CLI
    echo -e "  ${DG}├─ Installing GitHub CLI...${NC}"
    (type -p wget >/dev/null || (apt update && apt-get install wget -y)) && \
    mkdir -p -p /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt update && apt install gh -y 2>&1 | tee -a "$LOG_FILE"
    
    # Setup Codespace features
    echo -e "  ${DG}├─ Configuring Codespace features...${NC}"
    cat > ~/.bashrc_codespace << 'EOF'
# GitHub Codespaces custom configuration
export PS1="\[\033[38;5;82m\]🐙 Codespace\[\033[0m\]:\[\033[38;5;51m\]\w\[\033[0m\]\$ "
alias ghp='gh pr list'
alias ghr='gh repo view'
EOF
    
    echo "source ~/.bashrc_codespace" >> ~/.bashrc
    
    # Install common development tools
    echo -e "  ${DG}├─ Installing development tools...${NC}"
    apt-get install -y build-essential git-lfs jq 2>&1 | tee -a "$LOG_FILE"
    
    success "GitHub Codespaces environment configured"
}

setup_codesandbox() {
    log "Setting up CodeSandbox environment..."
    
    echo -e "\n  ${Y}📦 CodeSandbox Configuration${NC}"
    
    # Install sandbox tools
    echo -e "  ${DG}├─ Installing sandbox tools...${NC}"
    npm install -g sandbox-js 2>&1 | tee -a "$LOG_FILE" || true
    
    # Create sandbox configuration
    cat > .codesandbox/Dockerfile << 'EOF'
FROM node:18
RUN apt-get update && apt-get install -y git curl wget
EOF
    
    success "CodeSandbox environment configured"
}

setup_gitpod() {
    log "Setting up Gitpod environment..."
    
    echo -e "\n  ${Y}🦊 Gitpod Configuration${NC}"
    
    # Install Gitpod CLI
    echo -e "  ${DG}├─ Installing Gitpod CLI...${NC}"
    npm install -g @gitpod-io/gitpod-cli 2>&1 | tee -a "$LOG_FILE"
    
    # Create .gitpod.yml
    cat > .gitpod.yml << 'EOF'
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
    
    # Install replit packages
    echo -e "  ${DG}├─ Installing Replit tools...${NC}"
    npm install -g replit 2>&1 | tee -a "$LOG_FILE" || true
    
    # Create .replit
    cat > .replit << 'EOF'
language = "bash"
run = "bash main.sh"
EOF
    
    success "Replit environment configured"
}

setup_google_idx() {
    log "Setting up Google IDX environment..."
    
    echo -e "\n  ${Y}⚡ Google IDX Configuration${NC}"
    
    # Install IDX specific tools
    echo -e "  ${DG}├─ Installing IDX tools...${NC}"
    
    # Create IDX configuration
    mkdir -p .idx
    cat > .idx/dev.nix << 'EOF'
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
    cat > .stackblitzrc << 'EOF'
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
    curl -fsSL https://coder.com/install.sh | sh 2>&1 | tee -a "$LOG_FILE"
    
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
    
    # Common cloud IDE setup
    echo -e "\n  ${G}✓ Cloud IDE environment configured${NC}"
    echo -e "  ${DG}├─ You can now run other installation options${NC}"
    echo -e "  ${DG}└─ Some virtualization features may be limited in cloud IDEs${NC}"
}

# ==================== VPS MANAGEMENT FUNCTIONS ====================

list_vms() {
    if [[ ! -f "$VMS_LIST" ]] || [[ ! -s "$VMS_LIST" ]]; then
        echo -e "${Y}📋 [INFO] No VMs found. Create one first!${NC}"
        return 1
    fi
    
    echo -e "${C}📋 [INFO] 📁 Found $(wc -l < "$VMS_LIST") existing VM(s):${NC}"
    local i=1
    while IFS= read -r vm; do
        local vm_name=$(echo "$vm" | cut -d'|' -f1)
        local vm_status="N/A"
        if command -v virsh &> /dev/null; then
            vm_status=$(virsh list --all 2>/dev/null | grep "$vm_name" | awk '{print $3}' || echo "Unknown")
        fi
        echo -e "  ${G}$i)${NC} $vm_name - ${W}$vm_status${NC}"
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

create_vm_cloud() {
    clear
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${C}         🆕 CREATE VIRTUAL MACHINE (CLOUD OPTIMIZED)${NC}"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${Y}⚠️  Note: Running on $PLATFORM_NAME${NC}"
    echo -e "${DG}   Container-based virtualization will be used instead of KVM${NC}\n"
    
    # VM Name
    echo -ne "${W}📝 Enter VM/Container name: ${NC}"
    read -r vm_name
    
    if [[ -z "$vm_name" ]]; then
        error "Name cannot be empty"
    fi
    
    # CPU Cores
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💻 CPU Configuration${NC}"
    echo -ne "${W}Enter CPU cores (1-$(nproc)): ${NC}"
    read -r cpu_cores
    [[ ! "$cpu_cores" =~ ^[0-9]+$ ]] && cpu_cores=1
    
    # RAM
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💾 RAM Configuration${NC}"
    echo -ne "${W}Enter RAM in MB: ${NC}"
    read -r ram_mb
    [[ ! "$ram_mb" =~ ^[0-9]+$ ]] && ram_mb=512
    
    # Disk Size
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💿 Disk Configuration${NC}"
    echo -ne "${W}Enter disk size in GB: ${NC}"
    read -r disk_gb
    [[ ! "$disk_gb" =~ ^[0-9]+$ ]] && disk_gb=10
    
    # OS Selection
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🖥️  Operating System${NC}"
    echo -e "  ${G}1)${NC} Ubuntu 22.04"
    echo -e "  ${G}2)${NC} Debian 12"
    echo -e "  ${G}3)${NC} Alpine Linux (Lightweight)"
    echo -e "  ${G}4)${NC} Custom"
    echo -ne "${W}Choose [1-4]: ${NC}"
    read -r os_choice
    
    local os_name=""
    local container_image=""
    case $os_choice in
        1) os_name="Ubuntu 22.04"; container_image="ubuntu:22.04";;
        2) os_name="Debian 12"; container_image="debian:bookworm";;
        3) os_name="Alpine Linux"; container_image="alpine:latest";;
        *) os_name="Custom"; container_image="ubuntu:22.04";;
    esac
    
    # Port Configuration
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🔌 Port Configuration${NC}"
    echo -ne "${W}Ports to expose (comma-separated, e.g., 22,80,443): ${NC}"
    read -r ports_input
    
    # Create container instead of VM for cloud environments
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📦 Creating container: ${W}$vm_name${NC}"
    
    # Pull image
    docker pull "$container_image" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Create container with resource limits
    local docker_cmd="docker run -d --name $vm_name"
    docker_cmd="$docker_cmd --cpus $cpu_cores"
    docker_cmd="$docker_cmd --memory ${ram_mb}M"
    docker_cmd="$docker_cmd --storage-opt size=${disk_gb}G"
    
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
    
    # Save to VMs list
    echo "$vm_name|$cpu_cores|$ram_mb|$disk_gb|$os_name|$ports_input|docker|container" >> "$VMS_LIST"
    
    success "Container '$vm_name' created successfully!"
    
    echo -e "\n${G}Container Information:${NC}"
    echo -e "  ${DG}├─ To enter: ${W}docker exec -it $vm_name /bin/bash${NC}"
    echo -e "  ${DG}├─ To stop: ${W}docker stop $vm_name${NC}"
    echo -e "  ${DG}└─ To start: ${W}docker start $vm_name${NC}"
}

start_vm_cloud() {
    list_vms || return 1
    echo -ne "${W}🚀 Enter VM/Container number to start: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local vm_type=$(echo "$vm_info" | cut -d'|' -f7)
    
    if [[ "$vm_type" == "container" ]]; then
        docker start "$vm_name" 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
        success "Container '$vm_name' started"
    fi
}

stop_vm_cloud() {
    list_vms || return 1
    echo -ne "${W}🛑 Enter VM/Container number to stop: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local vm_type=$(echo "$vm_info" | cut -d'|' -f7)
    
    if [[ "$vm_type" == "container" ]]; then
        docker stop "$vm_name" 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
        success "Container '$vm_name' stopped"
    fi
}

delete_vm_cloud() {
    list_vms || return 1
    echo -ne "${R}🗑️  Enter VM/Container number to delete: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local vm_type=$(echo "$vm_info" | cut -d'|' -f7)
    
    echo -ne "${R}⚠️  Delete '$vm_name'? (y/n): ${NC}"
    read -r confirm
    
    if [[ "$confirm" == "y" ]]; then
        if [[ "$vm_type" == "container" ]]; then
            docker stop "$vm_name" 2>/dev/null || true
            docker rm "$vm_name" 2>&1 | while read line; do
                echo -e "  ${DG}│  ${NC}$line"
            done
        fi
        sed -i "/^$vm_name|/d" "$VMS_LIST"
        success "Deleted successfully"
    fi
}

show_vm_info_cloud() {
    list_vms || return 1
    echo -ne "${W}📊 Enter VM/Container number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local cpu=$(echo "$vm_info" | cut -d'|' -f2)
    local ram=$(echo "$vm_info" | cut -d'|' -f3)
    local disk=$(echo "$vm_info" | cut -d'|' -f4)
    local os=$(echo "$vm_info" | cut -d'|' -f5)
    local ports=$(echo "$vm_info" | cut -d'|' -f6)
    local vm_type=$(echo "$vm_info" | cut -d'|' -f7)
    
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📊 Container Information: ${W}$vm_name${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ "$vm_type" == "container" ]]; then
        local status=$(docker ps -a --filter "name=$vm_name" --format "{{.Status}}")
        local ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$vm_name" 2>/dev/null || echo "N/A")
        
        echo -e "${DG}├─ Status:${NC} ${W}$status${NC}"
        echo -e "${DG}├─ CPU Limit:${NC} ${W}$cpu cores${NC}"
        echo -e "${DG}├─ RAM Limit:${NC} ${W}$ram MB${NC}"
        echo -e "${DG}├─ Disk:${NC} ${W}$disk GB${NC}"
        echo -e "${DG}├─ OS:${NC} ${W}$os${NC}"
        echo -e "${DG}├─ IP Address:${NC} ${W}$ip${NC}"
        echo -e "${DG}├─ Open Ports:${NC} ${W}$ports${NC}"
        echo -e "${DG}└─ To enter:${NC} ${W}docker exec -it $vm_name /bin/bash${NC}"
    fi
}

vps_management_menu() {
    if [[ "$IS_CLOUD_IDE" == true ]] || [[ "$PLATFORM" == "docker" ]]; then
        # Cloud/Docker optimized menu
        while true; do
            clear
            echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${Y}         📋 CONTAINER MANAGEMENT MENU (Cloud Optimized)${NC}"
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
            echo -e "  ${G}6)${NC} 📊 List all Containers"
            echo -e "  ${R}0)${NC} 👋 Back to Main Menu"
            echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -ne "${W}🎯 Enter your choice: ${NC}"
            read -r choice
            
            case $choice in
                1) create_vm_cloud ;;
                2) start_vm_cloud ;;
                3) stop_vm_cloud ;;
                4) show_vm_info_cloud ;;
                5) delete_vm_cloud ;;
                6) list_vms ;;
                0) break ;;
                *) echo -e "${R}Invalid option${NC}"; sleep 2 ;;
            esac
            
            echo -e "\n${W}Press Enter to continue...${NC}"
            read -r
        done
    else
        # Full KVM menu
        while true; do
            clear
            echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${Y}                    📋 VPS MANAGEMENT MENU${NC}"
            echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            
            list_vms
            
            echo -e "\n${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${G}📋 Main Menu:${NC}"
            echo -e "  ${G}1)${NC} 🆕 Create a new VM"
            echo -e "  ${G}2)${NC} 🚀 Start a VM"
            echo -e "  ${G}3)${NC} 🛑 Stop a VM"
            echo -e "  ${G}4)${NC} 📊 Show VM info"
            echo -e "  ${G}5)${NC} ✏️  Edit VM configuration"
            echo -e "  ${G}6)${NC} 🗑️  Delete a VM"
            echo -e "  ${G}7)${NC} 📈 Resize VM disk"
            echo -e "  ${G}8)${NC} 📊 Show VM performance"
            echo -e "  ${G}9)${NC} 🔧 Fix VM issues"
            echo -e "  ${R}0)${NC} 👋 Back to Main Menu"
            echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -ne "${W}🎯 Enter your choice: ${NC}"
            read -r choice
            
            case $choice in
                1) create_vm_full ;;
                2) start_vm_full ;;
                3) stop_vm_full ;;
                4) show_vm_info_full ;;
                5) edit_vm_full ;;
                6) delete_vm_full ;;
                7) resize_vm_disk_full ;;
                8) show_vm_performance_full ;;
                9) fix_vm_issues_full ;;
                0) break ;;
                *) echo -e "${R}Invalid option${NC}"; sleep 2 ;;
            esac
            
            echo -e "\n${W}Press Enter to continue...${NC}"
            read -r
        done
    fi
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
        echo -e "${C}  🖥️  VPS/CONTAINER MANAGEMENT${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}2)${NC} 📋 Manage VMs/Containers (Create/Start/Stop)"
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

# ==================== WRAPPER FUNCTIONS ====================

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
        software-properties-common docker.io 2>&1 | tee -a "$LOG_FILE"
    systemctl enable docker
    systemctl start docker
    success "Dependencies installed"
}

setup_mysql() {
    log "Setting up MySQL..."
    MYSQL_ROOT_PASS=$(openssl rand -base64 16)
    MYSQL_PTERO_PASS=$(openssl rand -base64 16)
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS panel;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PTERO_PASS}';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';" 2>/dev/null || true
    cat > /root/pterodactyl_db_credentials.txt << EOF
MySQL Root: $MYSQL_ROOT_PASS
Pterodactyl DB Password: $MYSQL_PTERO_PASS
EOF
    success "MySQL configured"
}

install_pterodactyl_panel() {
    log "Installing Pterodactyl Panel..."
    cd /var/www
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    cd pterodactyl
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    cp .env.example .env
    composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    php artisan p:environment:setup --author=admin@localhost --url=http://localhost --timezone=UTC
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="${MYSQL_PTERO_PASS}"
    php artisan migrate --seed --force
    php artisan p:user:make --email=admin@localhost --username=admin --name-first=Admin --password=password123 --admin=1
    chown -R www-data:www-data /var/www/pterodactyl/*
    success "Panel installed"
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
}
EOF
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
    success "Nginx configured"
}

install_node_tailscale() {
    log "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    success "Node.js installed"
}

install_cloudflared_token() {
    log "Installing Cloudflared..."
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list
    apt-get update && apt-get install -y cloudflared
    success "Cloudflared installed"
}

install_pterodactyl_wings() {
    log "Installing Wings..."
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    mkdir -p /etc/pterodactyl
    success "Wings installed"
}

install_norfurch() {
    log "Installing monitoring tools..."
    apt-get install -y htop nmon iotop iftop
    curl -fsSL https://my-netdata.io/kickstart.sh | sh
    success "Monitoring tools installed"
}

install_rdp() {
    log "Installing RDP..."
    apt-get install -y x2goserver x2goserver-xsession xfce4 xfce4-goodies
    success "RDP installed"
}

github_vps_maker() {
    log "Setting up GitHub tools..."
    apt-get install -y gh
    mkdir -p /opt/actions-runner
    cd /opt/actions-runner
    LATEST_RUNNER=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep "browser_download_url.*linux-x64" | grep -v ".sha256" | cut -d '"' -f 4)
    curl -L -o runner.tar.gz "$LATEST_RUNNER"
    tar -xzf runner.tar.gz
    rm runner.tar.gz
    success "GitHub tools installed"
}

idx_tool_setup() {
    log "Setting up development tools..."
    apt-get install -y build-essential python3-pip golang-go default-jdk
    npm install -g yarn pm2 nodemon typescript
    pip3 install virtualenv pipenv
    success "Dev tools installed"
}

idx_vps_maker() {
    log "Setting up IDX environment..."
    curl -fsSL https://code-server.dev/install.sh | sh
    systemctl enable --now code-server@root
    docker volume create portainer_data
    docker run -d -p 9443:9443 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data portainer/portainer-ce:latest
    success "IDX environment ready"
}

real_vps_setup() {
    log "Setting up virtualization..."
    apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
    systemctl enable libvirtd
    systemctl start libvirtd
    success "KVM virtualization ready"
}

# ==================== KVM FUNCTIONS (Full Version) ====================

create_vm_full() {
    clear
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${C}                    🆕 CREATE NEW VIRTUAL MACHINE${NC}"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -ne "${W}📝 Enter VM name: ${NC}"
    read -r vm_name
    [[ -z "$vm_name" ]] && error "Name required"
    
    echo -ne "${W}Enter CPU cores (1-$(nproc)): ${NC}"
    read -r cpu_cores
    [[ ! "$cpu_cores" =~ ^[0-9]+$ ]] && cpu_cores=1
    
    echo -ne "${W}Enter RAM in MB: ${NC}"
    read -r ram_mb
    [[ ! "$ram_mb" =~ ^[0-9]+$ ]] && ram_mb=1024
    
    echo -ne "${W}Enter disk size in GB: ${NC}"
    read -r disk_gb
    [[ ! "$disk_gb" =~ ^[0-9]+$ ]] && disk_gb=20
    
    echo -e "${Y}OS Selection:"
    echo "  1) Ubuntu 22.04"
    echo "  2) Debian 12"
    echo -ne "Choose: "
    read -r os_choice
    local iso_url="https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
    
    local disk_path="$VM_DIR/${vm_name}.qcow2"
    qemu-img create -f qcow2 "$disk_path" "${disk_gb}G"
    
    virt-install --name "$vm_name" --vcpus "$cpu_cores" --memory "$ram_mb" \
        --disk path="$disk_path",format=qcow2 --cdrom "$iso_url" \
        --network bridge=virbr0 --graphics vnc --noautoconsole &
    
    echo "$vm_name|$cpu_cores|$ram_mb|$disk_gb|$os_choice||kvm" >> "$VMS_LIST"
    success "VM '$vm_name' created"
}

start_vm_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    virsh start "$vm_name"
    success "VM started"
}

stop_vm_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    virsh shutdown "$vm_name"
    success "VM stopped"
}

show_vm_info_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    virsh dominfo "$vm_name"
}

edit_vm_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    virsh edit "$vm_name"
}

delete_vm_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    echo -ne "${R}Delete '$vm_name'? (y/n): ${NC}"
    read -r confirm
    if [[ "$confirm" == "y" ]]; then
        virsh destroy "$vm_name" 2>/dev/null || true
        virsh undefine "$vm_name" --remove-all-storage
        sed -i "/^$vm_name|/d" "$VMS_LIST"
        success "Deleted"
    fi
}

resize_vm_disk_full() {
    echo "Resize disk function - Implement as needed"
}

show_vm_performance_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    virsh domstats "$vm_name"
}

fix_vm_issues_full() {
    list_vms || return 1
    echo -ne "${W}Enter VM number: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    [[ -z "$vm_info" ]] && error "Invalid"
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    virsh destroy "$vm_name" 2>/dev/null || true
    virsh start "$vm_name"
    success "VM restarted"
}

# --- MAIN EXECUTION ---
detect_platform
check_root
detect_os

# Ensure Docker is installed for cloud environments
if [[ "$IS_CLOUD_IDE" == true ]] && ! command -v docker &> /dev/null; then
    echo -e "${Y}Installing Docker for cloud environment...${NC}"
    curl -fsSL https://get.docker.com | sh
fi

main_menu
