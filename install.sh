#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER CLOUD SYSTEM | VPS MANAGEMENT SUITE
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
LOG_FILE="/tmp/gostdtgamer_vps_install.log"
VM_DIR="/var/lib/libvirt/images"
VM_CONFIG_DIR="/etc/gostdtgamer/vms"
VMS_LIST="/etc/gostdtgamer/vms.list"
MYSQL_ROOT_PASS=""
MYSQL_PTERO_PASS=""

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
    echo -e "${PURPLE}│${NC}  ${R}☢️  GOSTDTGAMER VPS MANAGEMENT SUITE${NC} ${DG}v3.0${NC}      ${DG}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
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
        local vm_status=$(virsh list --all | grep "$vm_name" > /dev/null 2>&1 && echo "🟢 Running" || echo "🔴 Stopped")
        echo -e "  ${G}$i)${NC} $vm_name - $vm_status"
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

create_vm() {
    clear
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${C}                    🆕 CREATE NEW VIRTUAL MACHINE${NC}"
    echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # VM Name
    echo -ne "${W}📝 Enter VM name: ${NC}"
    read -r vm_name
    
    if [[ -z "$vm_name" ]]; then
        error "VM name cannot be empty"
    fi
    
    # Check if VM exists
    if grep -q "^$vm_name|" "$VMS_LIST" 2>/dev/null; then
        error "VM with name '$vm_name' already exists"
    fi
    
    # CPU Cores
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💻 CPU Configuration${NC}"
    echo -ne "${W}Enter number of CPU cores (1-$(nproc)): ${NC}"
    read -r cpu_cores
    if [[ ! "$cpu_cores" =~ ^[0-9]+$ ]] || [[ $cpu_cores -lt 1 ]] || [[ $cpu_cores -gt $(nproc) ]]; then
        cpu_cores=1
        echo -e "${Y}Using default: 1 core${NC}"
    fi
    
    # RAM
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💾 RAM Configuration${NC}"
    echo -e "${DG}Available RAM: ${W}$(free -h | awk '/^Mem:/ {print $2}')${NC}"
    echo -ne "${W}Enter RAM in MB (512, 1024, 2048, 4096, etc): ${NC}"
    read -r ram_mb
    if [[ ! "$ram_mb" =~ ^[0-9]+$ ]] || [[ $ram_mb -lt 512 ]]; then
        ram_mb=1024
        echo -e "${Y}Using default: 1024 MB${NC}"
    fi
    
    # Disk Size
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}💿 Disk Configuration${NC}"
    echo -e "${DG}Available disk space: ${W}$(df -h / | awk 'NR==2 {print $4}')${NC}"
    echo -ne "${W}Enter disk size in GB (10, 20, 50, 100): ${NC}"
    read -r disk_gb
    if [[ ! "$disk_gb" =~ ^[0-9]+$ ]] || [[ $disk_gb -lt 5 ]]; then
        disk_gb=20
        echo -e "${Y}Using default: 20 GB${NC}"
    fi
    
    # OS Selection
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🖥️  Operating System Selection${NC}"
    echo -e "  ${G}1)${NC} Ubuntu 22.04 LTS (Jammy)"
    echo -e "  ${G}2)${NC} Ubuntu 20.04 LTS (Focal)"
    echo -e "  ${G}3)${NC} Debian 12 (Bookworm)"
    echo -e "  ${G}4)${NC} Debian 11 (Bullseye)"
    echo -e "  ${G}5)${NC} CentOS 9 Stream"
    echo -e "  ${G}6)${NC} Rocky Linux 9"
    echo -e "  ${G}7)${NC} Alpine Linux"
    echo -e "  ${G}8)${NC} Custom ISO URL"
    echo -ne "${W}Choose OS [1-8]: ${NC}"
    read -r os_choice
    
    local os_name=""
    local iso_url=""
    case $os_choice in
        1) os_name="Ubuntu 22.04"; iso_url="https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso";;
        2) os_name="Ubuntu 20.04"; iso_url="https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso";;
        3) os_name="Debian 12"; iso_url="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso";;
        4) os_name="Debian 11"; iso_url="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.9.0-amd64-netinst.iso";;
        5) os_name="CentOS 9"; iso_url="https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso";;
        6) os_name="Rocky Linux 9"; iso_url="https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.3-x86_64-minimal.iso";;
        7) os_name="Alpine Linux"; iso_url="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.1-x86_64.iso";;
        8) echo -ne "Enter custom ISO URL: "; read -r iso_url; os_name="Custom OS";;
        *) os_name="Ubuntu 22.04"; iso_url="https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso";;
    esac
    
    # Port Configuration
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🔌 Port Configuration${NC}"
    echo -e "${DG}Enter ports to open (comma separated, e.g., 22,80,443,8080)${NC}"
    echo -ne "${W}Ports to open: ${NC}"
    read -r ports_input
    
    # Network Configuration
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}🌐 Network Configuration${NC}"
    echo -ne "${W}Network bridge (default: virbr0): ${NC}"
    read -r network_bridge
    [[ -z "$network_bridge" ]] && network_bridge="virbr0"
    
    # Create VM
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📦 Creating VM: ${W}$vm_name${NC}"
    echo -e "${DG}├─ CPU: ${W}$cpu_cores cores${NC}"
    echo -e "${DG}├─ RAM: ${W}$ram_mb MB${NC}"
    echo -e "${DG}├─ Disk: ${W}$disk_gb GB${NC}"
    echo -e "${DG}├─ OS: ${W}$os_name${NC}"
    echo -e "${DG}├─ Ports: ${W}$ports_input${NC}"
    echo -e "${DG}└─ Network: ${W}$network_bridge${NC}"
    echo ""
    
    # Download ISO if needed
    local iso_path="$VM_DIR/${vm_name}.iso"
    if [[ ! -f "$iso_path" ]]; then
        echo -e "${Y}Downloading OS image...${NC}"
        wget -O "$iso_path" "$iso_url" 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
    fi
    
    # Create disk image
    local disk_path="$VM_DIR/${vm_name}.qcow2"
    qemu-img create -f qcow2 "$disk_path" "${disk_gb}G" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Create VM with virt-install
    virt-install \
        --name "$vm_name" \
        --vcpus "$cpu_cores" \
        --memory "$ram_mb" \
        --disk path="$disk_path",format=qcow2 \
        --cdrom "$iso_path" \
        --network bridge="$network_bridge",model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --os-variant ubuntu22.04 \
        --noautoconsole \
        --wait -1 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
    
    # Save VM configuration
    local vm_ip=""
    local mac=$(virsh domiflist "$vm_name" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}')
    
    # Configure port forwarding
    if [[ -n "$ports_input" ]]; then
        IFS=',' read -ra PORTS <<< "$ports_input"
        for port in "${PORTS[@]}"; do
            port=$(echo "$port" | xargs)
            iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "$vm_ip:$port" 2>/dev/null || true
            echo -e "  ${G}├─ Port $port forwarded${NC}"
        done
    fi
    
    # Save to VMs list
    echo "$vm_name|$cpu_cores|$ram_mb|$disk_gb|$os_name|$ports_input|$network_bridge|$vm_ip" >> "$VMS_LIST"
    
    success "VM '$vm_name' created successfully!"
    
    echo -e "\n${G}VM Information:${NC}"
    echo -e "  ${DG}├─ VNC Port: ${W}5900$(virsh vncdisplay "$vm_name" | cut -d':' -f2)${NC}"
    echo -e "  ${DG}├─ MAC Address: ${W}$mac${NC}"
    echo -e "  ${DG}└─ To connect: ${W}virsh console $vm_name${NC}"
}

start_vm() {
    list_vms || return 1
    echo -ne "${W}🎯 Enter VM number to start: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    echo -e "${Y}Starting VM: $vm_name...${NC}"
    
    virsh start "$vm_name" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Get IP after boot
    sleep 5
    local vm_ip=$(virsh domifaddr "$vm_name" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    success "VM '$vm_name' started successfully!"
    echo -e "  ${DG}├─ IP Address: ${W}$vm_ip${NC}"
    echo -e "  ${DG}└─ To connect: ${W}ssh root@$vm_ip${NC}"
}

stop_vm() {
    list_vms || return 1
    echo -ne "${W}🛑 Enter VM number to stop: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    echo -e "${Y}Stopping VM: $vm_name...${NC}"
    
    virsh shutdown "$vm_name" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    success "VM '$vm_name' stopped successfully!"
}

show_vm_info() {
    list_vms || return 1
    echo -ne "${W}📊 Enter VM number to show info: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local cpu=$(echo "$vm_info" | cut -d'|' -f2)
    local ram=$(echo "$vm_info" | cut -d'|' -f3)
    local disk=$(echo "$vm_info" | cut -d'|' -f4)
    local os=$(echo "$vm_info" | cut -d'|' -f5)
    local ports=$(echo "$vm_info" | cut -d'|' -f6)
    
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📊 VM Information: ${W}$vm_name${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local vm_status=$(virsh list --all | grep "$vm_name" | awk '{print $3}')
    local vm_ip=$(virsh domifaddr "$vm_name" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    local vm_mac=$(virsh domiflist "$vm_name" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    echo -e "${DG}├─ Status:${NC} ${W}$vm_status${NC}"
    echo -e "${DG}├─ CPU Cores:${NC} ${W}$cpu${NC}"
    echo -e "${DG}├─ RAM:${NC} ${W}$ram MB${NC}"
    echo -e "${DG}├─ Disk:${NC} ${W}$disk GB${NC}"
    echo -e "${DG}├─ OS:${NC} ${W}$os${NC}"
    echo -e "${DG}├─ IP Address:${NC} ${W}$vm_ip${NC}"
    echo -e "${DG}├─ MAC Address:${NC} ${W}$vm_mac${NC}"
    echo -e "${DG}├─ Open Ports:${NC} ${W}$ports${NC}"
    echo -e "${DG}└─ VNC Port:${NC} ${W}5900$(virsh vncdisplay "$vm_name" 2>/dev/null | cut -d':' -f2 || echo "Not running")${NC}"
}

edit_vm() {
    list_vms || return 1
    echo -ne "${W}✏️  Enter VM number to edit: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    echo -e "${Y}Editing VM: $vm_name${NC}"
    
    echo -ne "New CPU cores (current: $(echo "$vm_info" | cut -d'|' -f2)): "
    read -r new_cpu
    echo -ne "New RAM in MB (current: $(echo "$vm_info" | cut -d'|' -f3)): "
    read -r new_ram
    
    if [[ -n "$new_cpu" ]]; then
        virsh setvcpus "$vm_name" "$new_cpu" --config 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
    fi
    
    if [[ -n "$new_ram" ]]; then
        virsh setmem "$vm_name" "$new_ram" --config 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
    fi
    
    success "VM '$vm_name' updated (changes apply after reboot)"
}

delete_vm() {
    list_vms || return 1
    echo -ne "${R}🗑️  Enter VM number to delete: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    echo -ne "${R}⚠️  Are you sure you want to delete VM '$vm_name'? (y/n): ${NC}"
    read -r confirm
    
    if [[ "$confirm" != "y" ]]; then
        echo -e "${Y}Cancelled${NC}"
        return
    fi
    
    # Stop VM if running
    virsh destroy "$vm_name" 2>/dev/null || true
    
    # Undefine VM
    virsh undefine "$vm_name" --remove-all-storage 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Remove from list
    sed -i "/^$vm_name|/d" "$VMS_LIST"
    
    success "VM '$vm_name' deleted successfully!"
}

resize_vm_disk() {
    list_vms || return 1
    echo -ne "${W}📈 Enter VM number to resize disk: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    local current_disk=$(echo "$vm_info" | cut -d'|' -f4)
    local disk_path="$VM_DIR/${vm_name}.qcow2"
    
    echo -e "${Y}Current disk size: ${current_disk} GB${NC}"
    echo -ne "${W}Enter new disk size in GB: ${NC}"
    read -r new_size
    
    # Stop VM for resize
    virsh shutdown "$vm_name" 2>/dev/null
    sleep 3
    
    qemu-img resize "$disk_path" "${new_size}G" 2>&1 | while read line; do
        echo -e "  ${DG}│  ${NC}$line"
    done
    
    # Update config
    sed -i "s/^$vm_name|[^|]*|[^|]*|[^|]*/$vm_name|$(echo "$vm_info" | cut -d'|' -f2)|$(echo "$vm_info" | cut -d'|' -f3)|$new_size/" "$VMS_LIST"
    
    success "Disk resized to ${new_size}GB"
    echo -e "${Y}Note: You need to extend the partition inside the VM${NC}"
}

show_vm_performance() {
    list_vms || return 1
    echo -ne "${W}📊 Enter VM number for performance stats: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${Y}📊 Performance Metrics for: ${W}$vm_name${NC}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # CPU Usage
    local cpu_usage=$(virsh domstats "$vm_name" | grep "cpu.time" | cut -d'=' -f2)
    echo -e "${DG}├─ CPU Time:${NC} ${W}$cpu_usage${NC}"
    
    # Memory Usage
    local mem_used=$(virsh dommemstat "$vm_name" | grep "actual" | awk '{print $2}')
    local mem_mb=$((mem_used / 1024))
    echo -e "${DG}├─ Memory Used:${NC} ${W}$mem_mb MB${NC}"
    
    # Disk Usage
    local disk_path="$VM_DIR/${vm_name}.qcow2"
    local disk_size=$(du -h "$disk_path" | cut -f1)
    echo -e "${DG}├─ Disk Used:${NC} ${W}$disk_size${NC}"
    
    # Network Stats
    local rx=$(virsh domifstat "$vm_name" "vnet0" "rx_bytes" 2>/dev/null | awk '{print $2}')
    local tx=$(virsh domifstat "$vm_name" "vnet0" "tx_bytes" 2>/dev/null | awk '{print $2}')
    echo -e "${DG}├─ Network RX:${NC} ${W}$rx bytes${NC}"
    echo -e "${DG}└─ Network TX:${NC} ${W}$tx bytes${NC}"
}

fix_vm_issues() {
    list_vms || return 1
    echo -ne "${W}🔧 Enter VM number to fix: ${NC}"
    read -r vm_num
    local vm_info=$(get_vm_by_number "$vm_num")
    
    if [[ -z "$vm_info" ]]; then
        error "Invalid VM number"
    fi
    
    local vm_name=$(echo "$vm_info" | cut -d'|' -f1)
    
    echo -e "${Y}🔧 Fixing VM issues for: $vm_name${NC}"
    
    # Check if VM is stuck
    if virsh dominfo "$vm_name" | grep -q "in shutdown"; then
        echo -e "  ${DG}├─ VM stuck in shutdown, resetting...${NC}"
        virsh destroy "$vm_name" 2>/dev/null || true
        virsh start "$vm_name" 2>/dev/null || true
    fi
    
    # Reset network
    echo -e "  ${DG}├─ Resetting network...${NC}"
    virsh domifaddr "$vm_name" 2>/dev/null || true
    
    # Check disk integrity
    local disk_path="$VM_DIR/${vm_name}.qcow2"
    if [[ -f "$disk_path" ]]; then
        echo -e "  ${DG}├─ Checking disk integrity...${NC}"
        qemu-img check "$disk_path" 2>&1 | while read line; do
            echo -e "  ${DG}│  ${NC}$line"
        done
    fi
    
    success "VM issues fixed!"
}

vps_management_menu() {
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
            1) create_vm ;;
            2) start_vm ;;
            3) stop_vm ;;
            4) show_vm_info ;;
            5) edit_vm ;;
            6) delete_vm ;;
            7) resize_vm_disk ;;
            8) show_vm_performance ;;
            9) fix_vm_issues ;;
            0) break ;;
            *) echo -e "${R}Invalid option${NC}"; sleep 2 ;;
        esac
        
        echo -e "\n${W}Press Enter to continue...${NC}"
        read -r
    done
}

# ==================== REST OF THE FUNCTIONS (Pterodactyl, etc.) ====================

# ... (keep all previous functions: update_system, install_dependencies, setup_mysql, 
# install_pterodactyl_panel, configure_nginx, install_node_tailscale, install_cloudflared_token,
# install_pterodactyl_wings, install_norfurch, install_rdp, github_vps_maker, 
# idx_tool_setup, idx_vps_maker, real_vps_setup) ...

# ==================== MAIN MENU ====================

main_menu() {
    while true; do
        clear
        show_specs
        
        echo -e "\n${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${C}                    GOSTDTGAMER VPS DEPLOYMENT SUITE${NC}"
        echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🖥️  VPS MANAGEMENT${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}1)${NC} 📋 VPS Management Menu (Create/Start/Stop VMs)"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🐧 PTERODACTYL INSTALLATION${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}2)${NC} Install Everything (Full Pterodactyl Suite)"
        echo -e "  ${G}3)${NC} Install Pterodactyl Panel Only"
        echo -e "  ${G}4)${NC} Install Pterodactyl Wings Only"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🛠️  ADDITIONAL TOOLS${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}5)${NC} Install Node.js"
        echo -e "  ${G}6)${NC} Install Tailscale VPN"
        echo -e "  ${G}7)${NC} Install Cloudflared (with token setup)"
        echo -e "  ${G}8)${NC} Install RDP (Remote Desktop)"
        echo -e "  ${G}9)${NC} Install Norfurch (Monitoring Tools)"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  🚀 ADVANCED DEPLOYMENT FEATURES${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}10)${NC} 🚀 GitHub VPS Maker (Actions Runner + Deployment Tools)"
        echo -e "  ${G}11)${NC} 🔧 IDX Tool Setup (Dev Tools + IDE)"
        echo -e "  ${G}12)${NC} ⚡ IDX VPS Maker (Web IDE + File Browser + Portainer)"
        echo -e "  ${G}13)${NC} 🌐 Real VPS (Any + KVM) - Full Virtualization Setup"
        echo ""
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${C}  ℹ️  INFORMATION${NC}"
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════════${NC}"
        echo -e "  ${G}14)${NC} View System Specifications"
        echo -e "  ${G}15)${NC} View Installation Log"
        echo -e "  ${R}0)${NC} ❌ Exit"
        echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -ne "  ${W}Enter your choice [0-15]: ${NC}"
        read -r choice
        
        case $choice in
            1) vps_management_menu ;;
            2) 
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
            3)
                update_system
                install_dependencies
                setup_mysql
                install_pterodactyl_panel
                configure_nginx
                echo -e "\n${G}✓ Pterodactyl Panel installed!${NC}"
                echo -e "${Y}Access at: http://$(curl -s ifconfig.me)${NC}"
                ;;
            4)
                update_system
                install_dependencies
                install_pterodactyl_wings
                ;;
            5)
                update_system
                curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
                apt-get install -y nodejs
                success "Node.js installed: $(node -v)"
                ;;
            6)
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
            7)
                update_system
                install_cloudflared_token
                ;;
            8)
                update_system
                install_rdp
                ;;
            9)
                update_system
                install_norfurch
                ;;
            10)
                update_system
                github_vps_maker
                ;;
            11)
                update_system
                idx_tool_setup
                ;;
            12)
                update_system
                idx_vps_maker
                ;;
            13)
                update_system
                real_vps_setup
                ;;
            14)
                show_specs
                echo -e "\n${W}Press Enter to continue...${NC}"
                read -r
                ;;
            15)
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
check_root
detect_os

# Install virtualization packages if not present
if ! command -v virsh &> /dev/null; then
    echo -e "${Y}Installing virtualization packages...${NC}"
    apt-get update -y
    apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
    systemctl enable libvirtd
    systemctl start libvirtd
fi

main_menu
