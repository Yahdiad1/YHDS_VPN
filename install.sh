#!/bin/bash
# ============================================================
# YHDS VPN FULL INSTALLER 2025 — UDP SUPER STABLE
# SSH • WS/XRAY • TROJAN • UDP CUSTOM 1-65535 • Nginx
# ============================================================

set -euo pipefail

# -------------------------------
# Warna
# -------------------------------
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'

# -------------------------------
# Variabel
# -------------------------------
UDP_DIR="/root/udp"
SYSTEMD_FILE="/etc/systemd/system/udp-custom.service"
MENU_FILE="/usr/local/bin/menu"
MENU_REPO="https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu.sh"
UDP_BIN_URL="https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/udp-custom-linux-amd64"

mkdir -p "$UDP_DIR"

# -------------------------------
# Update sistem
# -------------------------------
echo -e "${GREEN}Updating system...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip screen bzip2 gzip figlet lolcat nginx ufw

# -------------------------------
# Matikan IPv6
# -------------------------------
echo -e "${YELLOW}Disabling IPv6...${NC}"
cat << EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
sysctl -p

# -------------------------------
# Kernel Tuning — SUPER STABLE UDP
# -------------------------------
echo -e "${YELLOW}Applying Kernel Optimizations...${NC}"
cat << EOF > /etc/sysctl.d/99-udp-tuning.conf
net.core.rmem_max = 26214400
net.core.wmem_max = 26214400
net.core.rmem_default = 26214400
net.core.wmem_default = 26214400
net.core.netdev_max_backlog = 50000
net.core.optmem_max = 81920
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.ip_local_port_range = 1 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
EOF
sysctl --system

# -------------------------------
# Install Xray
# -------------------------------
echo -e "${GREEN}Installing Xray...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1

systemctl enable xray
systemctl restart xray

# -------------------------------
# Install Nginx
# -------------------------------
echo -e "${GREEN}Installing Nginx...${NC}"
systemctl enable nginx
systemctl restart nginx

# -------------------------------
# Install UDP-Custom (Binary)
# -------------------------------
echo -e "${GREEN}Installing UDP Custom...${NC}"
wget -q "$UDP_BIN_URL" -O "$UDP_DIR/udp-custom"
chmod +x "$UDP_DIR/udp-custom"

# -------------------------------
# Config UDP SUPER STABLE
# -------------------------------
echo -e "${GREEN}Applying Stable Config...${NC}"
cat << EOF > $UDP_DIR/config.json
{
  "listen": ":1-65535",
  "protocol": "udp",
  "mtu": 1350,
  "buffer_size": 2097152,
  "max_clients": 5000,
  "timeout": 60,
  "log_level": "info"
}
EOF

# -------------------------------
# Systemd Service
# -------------------------------
cat << EOF > "$SYSTEMD_FILE"
[Unit]
Description=YHDS UDP Custom
After=network.target

[Service]
Type=simple
ExecStart=$UDP_DIR/udp-custom server
Restart=always
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

# -------------------------------
# Firewall
# -------------------------------
echo -e "${YELLOW}Configuring Firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 22,80,443/tcp
ufw --force enable

# -------------------------------
# Install Menu Baru (Fix 1–20)
# -------------------------------
echo -e "${GREEN}Installing YHDS New Menu...${NC}"
wget -q -O "$MENU_FILE" "$MENU_REPO"
chmod +x "$MENU_FILE"

# Auto-run menu
sed -i '/menu/d' /root/.bashrc
echo "/usr/local/bin/menu" >> /root/.bashrc

# -------------------------------
# Selesai
# -------------------------------
clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}        INSTALLATION COMPLETED!               ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "${BLUE}Command: ${YELLOW}menu${NC}"
echo -e "${BLUE}UDP Super Stable aktif 1–65535${NC}"
echo -e "${BLUE}Menu Baru 1–20 sudah terpasang${NC}"
