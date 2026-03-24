install_cloudflared() {
    echo -e "${YELLOW}Installing Cloudflared...${NC}"
    
    # Add cloudflare gpg key
    mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
    
    # Add repository
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    
    # Install cloudflared
    apt-get update -y
    apt-get install -y cloudflared
    
    echo -e "${GREEN}✓ Cloudflared installed: $(cloudflared version)${NC}"
    
    # Ask for token
    echo ""
    echo -e "${YELLOW}Enter your Cloudflare Tunnel Token:${NC}"
    echo -ne "${GREEN}► Token: ${NC}"
    read CLOUDFLARE_TOKEN
    
    if [[ -n "$CLOUDFLARE_TOKEN" ]]; then
        # Save token
        mkdir -p /root/.cloudflared
        echo "$CLOUDFLARE_TOKEN" > /root/.cloudflared/token
        
        # Create and start service
        cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/cloudflared tunnel --token $(cat /root/.cloudflared/token)
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable cloudflared
        systemctl start cloudflared
        
        echo -e "${GREEN}✓ Tunnel started!${NC}"
    else
        echo -e "${YELLOW}No token provided. You can set it up later with:${NC}"
        echo "cloudflared tunnel --token YOUR_TOKEN run"
    fi
}
