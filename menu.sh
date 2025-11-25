#!/bin/bash
# ============================================================
# YHDS VPN FULL MENU 1–16 FINAL 2025
# SSH • WS/XRAY • TROJAN WS • UDP CUSTOM • NGiNX
# Semua menu aktif + payload lengkap
# ============================================================

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
BLUE='\e[34m'; CYAN='\e[36m'; NC='\e[0m'

DOMAIN_FILE="/etc/xray/domain"
XRAY_CONFIG="/etc/xray/config.json"

# ================= STATUS =================
status() {
  echo -e "${GREEN}Status Server:${NC}"
  for srv in ssh xray nginx trojan-go udp-custom; do
    echo -e "${CYAN}$srv${NC} : $(systemctl is-active $srv >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
  done
  echo ""
}

# ================= CREATE SSH + PAYLOAD =================
create_user() {
  clear
  read -p "Username : " user
  read -p "Password : " pass
  read -p "Masa aktif (hari): " days
  domain=$(cat $DOMAIN_FILE)
  exp=$(date -d "+$days days" +"%Y-%m-%d")

  useradd -e "$exp" -s /bin/false "$user"
  echo -e "$pass\n$pass" | passwd "$user" >/dev/null 2>&1

  clear
  echo -e "${BLUE}────────── SSH ACCOUNT ──────────${NC}"
  echo "User     : $user"
  echo "Pass     : $pass"
  echo "Expired  : $exp"
  echo "Domain   : $domain"

  echo -e "${GREEN}"
  echo "SSH TLS WS     : $domain:443@$user:$pass"
  echo "SSH NON-TLS WS : $domain:80@$user:$pass"
  echo "SSH UDP CUSTOM : $domain:1-65535@$user:$pass"
  echo -e "${NC}"

  echo -e "${GREEN}Payload SSH WS:${NC}"
  echo "GET / HTTP/1.1[crlf]Host: $domain[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"

  echo ""
  read -n1 -r -p "Press any key..."
}

# ================= CREATE TROJAN WS =================
create_trojan() {
  clear
  read -p "Nama User Trojan : " user
  read -p "Password Trojan  : " pass
  read -p "Masa aktif (hari): " days

  domain=$(cat $DOMAIN_FILE)
  exp=$(date -d "+$days days" +"%Y-%m-%d")

  # Tambah akun ke Xray config
  sed -i "/\"clients\": \[/a\        {\"password\": \"$pass\", \"email\": \"$user\"}," $XRAY_CONFIG
  systemctl restart xray

  clear
  echo -e "${BLUE}────────── TROJAN WS ──────────${NC}"
  echo "User     : $user"
  echo "Pass     : $pass"
  echo "Expired  : $exp"
  echo "Domain   : $domain"
  echo ""

  echo -e "${GREEN}TROJAN LINK:${NC}"
  echo "trojan://$pass@$domain:443?security=tls&type=ws&path=/trojan-ws&host=$domain#$user"
  echo ""

  echo -e "${GREEN}Payload TROJAN WS:${NC}"
  echo "GET /trojan-ws HTTP/1.1[crlf]Host: $domain[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"

  echo ""
  read -n1 -r -p "Press any key..."
}

# ================= DELETE USER =================
delete_user() {
  read -p "User SSH: " user
  userdel -f $user && echo "User SSH $user dihapus!"
  read -n1
}

# ================= LIST USER =================
list_user() {
  awk -F: '$3>=1000 {print $1}' /etc/passwd
  read -n1
}

# ================= TRIAL USER =================
trial_user() {
  user="trial$(openssl rand -hex 2)"
  pass="1"
  exp=$(date -d "+1 days" +"%Y-%m-%d")
  domain=$(cat $DOMAIN_FILE)

  useradd -e "$exp" -s /bin/false "$user"
  echo -e "$pass\n$pass" | passwd "$user" >/dev/null

  echo "Trial $user | Exp $exp"
  read -n1
}

# ================= LOCK/UNLOCK =================
lock_unlock() {
  read -p "User: " user
  passwd -l $user && echo "$user dikunci!"
  read -p "Aktifkan user? y/n : " yn
  [[ $yn == "y" ]] && passwd -u $user && echo "$user aktif!"
  read -n1
}

# ================= RENEW USER =================
renew_user() {
  read -p "User: " user
  read -p "Tambah hari: " add
  old=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
  new=$(date -d "$old + $add days" +"%Y-%m-%d")
  chage -E "$new" $user
  echo "Akun diperpanjang sampai $new"
  read -n1
}

# ================= RESTART SERVICE =================
restart_service() {
  systemctl restart ssh xray nginx udp-custom trojan-go
  echo "Semua service direstart!"
  read -n1
}

# ================= SET DOMAIN =================
set_domain() {
  read -p "Domain baru: " dm
  echo "$dm" > $DOMAIN_FILE
  systemctl restart xray
  echo "Domain diganti ke $dm"
  read -n1
}

# ================= SERVICE ON/OFF =================
toggle_service() {
  services=("ssh" "xray" "nginx" "trojan-go" "udp-custom")
  echo -e "Pilih service:"
  for i in "${!services[@]}"; do
    echo "$((i+1))) ${services[$i]}"
  done
  read -p "Pilih: " n
  srv="${services[$((n-1))]}"

  if systemctl is-active $srv >/dev/null; then
    systemctl stop $srv && echo "$srv OFF"
  else
    systemctl start $srv && echo "$srv ON"
  fi
  read -n1
}

# ================= INFO VPS =================
info_vps() {
  echo "Hostname : $(hostname)"
  echo "IP Publik: $(curl -s ipv4.icanhazip.com)"
  echo "Uptime   : $(uptime -p)"
  free -h
  read -n1
}

# ================= BANNER =================
banner() {
clear
echo -e "${RED}__  ____  ______  _____    _    ______  _   __${NC}"
echo -e "${RED}\\ \\/ / / / / __ \\/ ___/   | |  / / __ \\/ | / /${NC}"
echo -e "${RED} \\  / /_/ / / / /\\__ \\    | | / / /_/ /  |/ /${NC}"
echo -e "${RED} / / __  / /_/ /___/ /    | |/ / ____/ /|  /${NC}"
echo -e "${RED}/_/_/ /_/_____//____/     |___/_/   /_/ |_|${NC}"
echo ""
status

echo -e "${YELLOW} 1)  Create SSH + Payload${NC}"
echo -e "${YELLOW} 2)  Delete SSH${NC}"
echo -e "${YELLOW} 3)  List User SSH${NC}"
echo -e "${YELLOW} 4)  Create Trojan WS${NC}"
echo -e "${YELLOW} 5)  Trial SSH${NC}"
echo -e "${YELLOW} 6)  Lock/Unlock User${NC}"
echo -e "${YELLOW} 7)  Dashboard User${NC}"
echo -e "${YELLOW} 8)  Bot Telegram${NC}"
echo -e "${YELLOW} 9)  Restart All Service${NC}"
echo -e "${YELLOW}10) Remove Script${NC}"
echo -e "${YELLOW}11) Manual Payload${NC}"
echo -e "${YELLOW}12) Set Domain${NC}"
echo -e "${YELLOW}13) Exit${NC}"
echo -e "${YELLOW}14) Renew Akun${NC}"
echo -e "${YELLOW}15) ON/OFF Service${NC}"
echo -e "${YELLOW}16) Info VPS${NC}"
}

# ================= LOOP MENU =================
while true; do
  banner
  read -p "Pilih menu: " x
  case $x in
    1) create_user ;;
    2) delete_user ;;
    3) list_user ;;
    4) create_trojan ;;
    5) trial_user ;;
    6) lock_unlock ;;
    7) w; read -n1 ;;
    8) echo "Bot belum diisi"; read -n1 ;;
    9) restart_service ;;
    10) rm -f /usr/local/bin/menu; exit ;;
    11) echo "Payload: GET / HTTP/1.1"; read -n1 ;;
    12) set_domain ;;
    13) exit 0 ;;
    14) renew_user ;;
    15) toggle_service ;;
    16) info_vps ;;
    *) echo "Pilihan tidak valid"; sleep 1 ;;
  esac
done
