#!/usr/bin/env bash

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_kvm(){
if egrep -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
echo "KVM: SUPPORTED"
else
echo "KVM: NOT SUPPORTED"
fi
}

banner(){
clear
echo -e "${CYAN}"
echo "████████████████████████████████████████████"
echo "        CODEHUB CLOUD VPS MANAGER"
echo "████████████████████████████████████████████"
echo -e "${NC}"
check_kvm
echo ""
}

install_lxd(){
apt update -y
apt install lxd -y
lxd init --auto
}

select_os(){
echo "Choose OS:"
echo "1) Ubuntu 22.04"
echo "2) Debian 12"
echo "3) Alpine"
read -p "OS Choice: " os

case $os in
1) IMAGE="images:ubuntu/22.04" ;;
2) IMAGE="images:debian/12" ;;
3) IMAGE="images:alpine/3.18" ;;
*) echo "Invalid OS"; return ;;
esac
}

create_vps(){

select_os

read -p "VPS Name: " NAME
read -p "RAM (MB): " RAM
read -p "CPU cores: " CPU
read -p "Disk size (GB): " DISK
read -p "Open Port: " PORT

echo "Creating VPS..."

lxc launch $IMAGE $NAME

lxc config set $NAME limits.memory ${RAM}MB
lxc config set $NAME limits.cpu $CPU

lxc config device add $NAME root disk path=/ pool=default size=${DISK}GB

IP=$(lxc list $NAME -c 4 | tail -n1)

echo "VPS Created!"
echo "IP: $IP"

read -p "Start VPS now? (y/n): " start
if [ "$start" = "y" ]; then
lxc start $NAME
fi
}

list_vps(){
lxc list
}

delete_vps(){
read -p "VPS Name to delete: " NAME
lxc delete $NAME --force
}

while true
do
banner

echo "VPS MANAGEMENT"
echo "1) Install VPS System (LXD)"
echo "2) Create VPS"
echo "3) List VPS"
echo "4) Delete VPS"
echo "5) System Info"
echo "0) Exit"

read -p "Command: " choice

case $choice in
1) install_lxd ;;
2) create_vps ;;
3) list_vps ;;
4) delete_vps ;;
5) lscpu && free -h && df -h ;;
0) exit ;;
*) echo "Invalid option" ;;
esac

read -p "Press enter to continue..."
done
