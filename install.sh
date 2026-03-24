#!/usr/bin/env bash
# ==========================================================
# GOSTDTGAMER CLOUDFLARED SIMPLE INSTALLER
# ==========================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Cloudflared Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Install cloudflared
echo -e "${YELLOW}Installing cloudflared...${NC}"
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
apt-get update -y
apt-get install -y cloudflared

echo -e "${GREEN}✓ Cloudflared installed: $(cloudflared version)${NC}"
echo ""

# Get token
echo -e "${YELLOW}Enter your Cloudflare Tunnel Token:${NC}"
echo -e "${BLUE}(Get from: Cloudflare Dashboard → Zero Trust → Networks → Tunnels)${NC}"
echo -ne "${GREEN}Token: ${NC}"
read TOKEN

if [[ -z "$TOKEN" ]]; then
    echo -e "${RED}No token provided. Exiting.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Starting tunnel with your token...${NC}"
echo -e "${GREEN}Press Ctrl+C to stop the tunnel${NC}"
echo ""

# Run the tunnel with the token
cloudflared tunnel --token "$TOKEN" run
