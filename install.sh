#!/usr/bin/env bash

# COLORS
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

# SYSTEM INFO
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
RAM=$(free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2}')
DISK=$(df / | awk 'NR==2{print $5}')

# BANNER
banner(){
clear
echo -e "${CYAN}"
echo "════════════════════════════════════════════"
echo "        CODEHUB CLOUD CONTROL PANEL"
echo "════════════════════════════════════════════"
echo -e "${NC}"
echo "CPU: $CPU% | RAM: $RAM | Disk: $DISK"
echo ""
}

# INSTALL DOCKER
install_docker(){
echo "Installing Docker..."
apt update -y
apt install docker.io -y
systemctl enable docker
}

# INSTALL LXD VPS SYSTEM
install_lxd(){
echo "Installing LXD..."
apt install lxd -y
lxd init --auto
}

# CREATE VPS
create_vps(){
read -p "VPS Name: " name
lxc launch ubuntu:22.04 $name
echo "VPS Created!"
}

# TOOLS MENU
tools_menu(){
while true
do
clear
echo "SERVER UTILITIES & TOOLS"
echo ""
echo "1) System Info"
echo "2) Install Tailscale"
echo "3) Install Zerotier"
echo "4) Install RDP"
echo "0) Back"

read -p "Select Tool: " tool

case $tool in
1) neofetch ;;
2) curl -fsSL https://tailscale.com/install.sh | sh ;;
3) curl -s https://install.zerotier.com | bash ;;
4) apt install xfce4 xrdp -y ;;
0) break ;;
*) echo "Invalid option" ;;
esac

read -p "Press Enter..."
done
}

# MAIN MENU
main_menu(){
while true
do
banner

echo "VIRTUALIZATION & NODES"
echo "1) Install Docker"
echo "2) Install LXD"
echo "3) Create VPS"
echo "4) Tools"
echo "0) Exit"

read -p "Command: " choice

case $choice in
1) install_docker ;;
2) install_lxd ;;
3) create_vps ;;
4) tools_menu ;;
0) exit ;;
*) echo "Invalid option" ;;
esac

read -p "Press Enter..."
done
}

main_menu
