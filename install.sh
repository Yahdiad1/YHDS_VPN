#!/bin/bash
# =====================================
# FULL INSTALLER YHDS VPN (UDP + Xray + Nginx + Trojan + Menu Full Color + Payload)
# =====================================

# -----------------------------
# Update dan install tools
# -----------------------------
apt update -y
apt upgrade -y
apt install lolcat figlet neofetch screenfetch unzip curl wget ruby -y
gem install lolcat >/dev/null 2>&1 || true

# -----------------------------
# Disable IPv6 supaya UDP lebih stabil
# -----------------------------
echo "Menonaktifkan IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# -----------------------------
# Hapus folder lama dan buat folder baru
# -----------------------------
rm -rf /root/udp
mkdir -p /root/udp

# -----------------------------
# Banner Installer YHDS VPN
# -----------------------------
clear
figlet -f slant "YHDS VPN" | lolcat
echo -e "\e[36m   === Selamat datang di YHDS VPN Installer ===\e[0m"
sleep 3

# -----------------------------
# Set timezone Sri Lanka GMT+5:30
# -----------------------------
ln -fs /usr/share/zoneinfo/Asia/Colombo /etc/localtime
echo "Timezone diubah ke GMT+5:30 (Sri Lanka)"

# -----------------------------
# Install Xray
# -----------------------------
echo "Install Xray..."
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1

# -----------------------------
# Install Nginx
# -----------------------------
echo "Install Nginx..."
apt install nginx -y
systemctl enable nginx
systemctl start nginx

# -----------------------------
# Install Trojan
# -----------------------------
echo "Install Trojan..."
bash -c "$(curl -sL https://raw.githubusercontent.com/p4gefau1t/trojan-install/master/trojan.sh)" >/dev/null 2>&1

# -----------------------------
# Download UDP Custom dari GitHub
# -----------------------------
GITHUB_RAW="https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main"
wget "$GITHUB_RAW/udp-custom-linux-amd64" -O /root/udp/udp-custom
chmod +x /root/udp/udp-custom
wget "$GITHUB_RAW/config.json" -O /root/udp/config.json
chmod 644 /root/udp/config.json

# -----------------------------
# Buat systemd service UDP Custom
# -----------------------------
cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=YHDS VPN UDP Custom

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF

# -----------------------------
# Download skrip tambahan menu
# -----------------------------
mkdir -p /etc/YHDS
cd /etc/YHDS
wget "$GITHUB_RAW/system.zip"
unzip system.zip
cd system
mv menu /usr/local/bin
chmod +x menu creatuser.sh Adduser.sh DelUser.sh Userlist.sh ToggleUser.sh DashboardStatus.sh InstallBot.sh RemoveScript.sh torrent.sh CreateTrial.sh CreateTrojan.sh
cd /etc/YHDS
rm system.zip

# -----------------------------
# Menu utama full color + payload otomatis
# -----------------------------
cat << 'EOM' > /usr/local/bin/menu
#!/bin/bash
RED='\e[31m'; GREEN='\e[32m'; BLUE='\e[34m'
YELLOW='\e[33m'; CYAN='\e[36m'; NC='\e[0m'

status() {
  for service in udp-custom xray nginx trojan-go; do
    if systemctl is-active --quiet $service; then
      echo -e " ${CYAN}$service${NC} : ${GREEN}ON${NC}"
    else
      echo -e " ${CYAN}$service${NC} : ${RED}OFF${NC}"
    fi
  done
}

create_user_payload() {
  read -p "Nama user: " USERNAME
  read -p "Password: " PASSWORD
  read -p "Expired (hari): " EXPIRE
  read -p "Max login simultan: " MAX
  /etc/YHDS/system/creatuser.sh manual "$USERNAME" "$PASSWORD" "$EXPIRE" "$MAX"
  echo -e "${GREEN}User $USERNAME berhasil dibuat!${NC}"

  # ==============================
  # Tampilkan payload otomatis
  # ==============================
  IP=$(curl -s https://ipinfo.io/ip)
  echo ""
  echo -e "${YELLOW}Payload SSH/WS:${NC}"
  echo "ssh://${USERNAME}:${PASSWORD}@${IP}:22"
  echo "ws://${USERNAME}:${PASSWORD}@${IP}:443"
  echo ""
  echo -e "${YELLOW}Payload Trojan:${NC}"
  echo "trojan://${PASSWORD}@${IP}:443#${USERNAME}"
  echo "trojan://${PASSWORD}@${IP}:80#${USERNAME}"
  echo ""
  read -n 1 -s -r -p "Tekan Enter untuk kembali ke menu..."
}

while true; do
  clear
  figlet -f slant "YHDS VPN" | lolcat 2>/dev/null || echo -e "${CYAN}=== YHDS VPN ===${NC}"
  echo -e "${YELLOW}Status Server:${NC}"
  status
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${YELLOW} 1) Create User (manual + payload)${NC}"
  echo -e "${YELLOW} 2) Hapus User${NC}"
  echo -e "${YELLOW} 3) Daftar User${NC}"
  echo -e "${YELLOW} 4) Create Trojan (port 443/80)${NC}"
  echo -e "${YELLOW} 5) Create Trial (SSH/UDP/Trojan/Xray)${NC}"
  echo -e "${YELLOW} 6) Toggle ON/OFF Akun${NC}"
  echo -e "${YELLOW} 7) Dashboard Status${NC}"
  echo -e "${YELLOW} 8) Install Bot Telegram Notifikasi${NC}"
  echo -e "${YELLOW} 9) Restart Semua Service${NC}"
  echo -e "${YELLOW}10) Uninstall / Remove Script${NC}"
  echo -e "${YELLOW}11) Keluar${NC}"
  echo -e "${BLUE}========================================${NC}"

  read -p "Pilih menu [1-11]: " opt
  case "$opt" in
    1) create_user_payload ;;
    2) /etc/YHDS/system/DelUser.sh; read -n 1 -s -r -p "Press any key to return...";;
    3) /etc/YHDS/system/Userlist.sh; read -n 1 -s -r -p "Press any key to return...";;
    4) /etc/YHDS/system/CreateTrojan.sh; read -n 1 -s -r -p "Press any key to return...";;
    5) /etc/YHDS/system/CreateTrial.sh; read -n 1 -s -r -p "Press any key to return...";;
    6) /etc/YHDS/system/ToggleUser.sh; read -n 1 -s -r -p "Press any key to return...";;
    7) /etc/YHDS/system/DashboardStatus.sh; read -n 1 -s -r -p "Press any key to return...";;
    8) /etc/YHDS/system/InstallBot.sh; read -n 1 -s -r -p "Press any key to return...";;
    9)
       echo "Restarting services..."
       for s in udp-custom xray nginx trojan-go; do
         systemctl restart $s >/dev/null 2>&1
       done
       echo -e "${GREEN}Selesai restart!${NC}"
       read -n 1 -s -r -p "Press any key to return..."
       ;;
    10)
       read -p "Yakin hapus semua script YHDS? (y/n): " YN
       if [[ "$YN" == "y" ]]; then
         systemctl stop udp-custom >/dev/null 2>&1
         systemctl disable udp-custom >/dev/null 2>&1
         rm -rf /etc/YHDS /root/udp /usr/local/bin/menu
         echo -e "${RED}Semua script dihapus!${NC}"
         exit 0
       fi
       ;;
    11) echo "Keluar dari menu"; exit 0;;
    *) echo "Pilihan tidak valid"; sleep 1;;
  esac
done
EOM

chmod +x /usr/local/bin/menu

# -----------------------------
# Jalankan menu otomatis saat login
# -----------------------------
if ! grep -q "/usr/local/bin/menu" /root/.bashrc; then
    echo "/usr/local/bin/menu" >> /root/.bashrc
fi

# -----------------------------
# Start dan enable service UDP Custom
# -----------------------------
systemctl daemon-reload
systemctl start udp-custom
systemctl enable udp-custom

clear
figlet -f slant "YHDS VPN" | lolcat
echo "=========================================="
echo "YHDS VPN berhasil diinstall!"
echo "UDP, Xray, Nginx, Trojan siap digunakan"
echo "IPv6 dinonaktifkan, UDP lebih stabil"
echo "Menu utama full color siap pakai"
echo "Menu akan otomatis muncul setelah close atau login kembali"
echo "Github: https://github.com/Yahdiad1/Udp-custom"
echo "=========================================="
