#!/bin/bash
# =====================================================================
# YHDS VPN FULL MENU + PAYLOAD ALL-IN-ONE (FINAL VERSION)
# SSH / WS 80-443 / XRAY / TROJAN WS / UDP CUSTOM
# Menu 1–13 Full + Auto Payload
# Banner YHDSVPN Berwarna
# Set Domain + Semua Service Fix
# =====================================================================

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33;1m'; BLUE='\e[34;1m'; CYAN='\e[36;1m'; BOLD='\e[1m'; NC='\e[0m'

# =====================================================================
# BANNER WARNA YHDS VPN
# =====================================================================
banner() {
clear
echo -e "${CYAN}${BOLD}"
echo "__  ____  ______  _____    _    ______  _   __"
echo "\ \/ / / / / __ \/ ___/   | |  / / __ \/ | / /"
echo " \  / /_/ / / / /\__ \    | | / / /_/ /  |/ / "
echo " / / __  / /_/ /___/ /    | |/ / ____/ /|  /  "
echo "/_/_/ /_/_____//____/     |___/_/   /_/ |_/   "
echo -e "${NC}"

echo -e "${BLUE}Status Server:${NC}"
for s in udp-custom xray nginx trojan-go; do
    if systemctl is-active --quiet $s; then
        echo -e "${GREEN}$s : ON${NC}"
    else
        echo -e "${RED}$s : OFF${NC}"
    fi
done

echo -e "${YELLOW}${BOLD}========================================${NC}"
echo -e "${YELLOW}${BOLD}1) Create User (SSH/WS + UDP + Trojan)${NC}"
echo -e "${YELLOW}${BOLD}2) Hapus User${NC}"
echo -e "${YELLOW}${BOLD}3) Daftar User${NC}"
echo -e "${YELLOW}${BOLD}4) Create Trojan Manual${NC}"
echo -e "${YELLOW}${BOLD}5) Create Trial All Service${NC}"
echo -e "${YELLOW}${BOLD}6) Toggle ON/OFF Akun${NC}"
echo -e "${YELLOW}${BOLD}7) Dashboard Akun${NC}"
echo -e "${YELLOW}${BOLD}8) Bot Telegram${NC}"
echo -e "${YELLOW}${BOLD}9) Restart Semua Service${NC}"
echo -e "${YELLOW}${BOLD}10) Remove Script${NC}"
echo -e "${YELLOW}${BOLD}11) Create Manual Full + Payload${NC}"
echo -e "${YELLOW}${BOLD}12) Set Domain${NC}"
echo -e "${YELLOW}${BOLD}13) Keluar${NC}"
echo -e "${YELLOW}${BOLD}========================================${NC}"
}

# =====================================================================
# 1. AUTO CREATE USER (SSH + WS + UDP + TROJAN)
# =====================================================================
create_user_auto() {
clear
echo -e "${YELLOW}=== CREATE USER AUTO FULL ===${NC}"

read -rp "Username        : " user
read -rp "Password        : " pass
read -rp "Expired (hari)  : " expday
domain=$(cat /etc/domain)
exp=$(date -d "$expday days" +%Y-%m-%d)

# SSH WS 80/443
useradd -e "$exp" -s /bin/false -M "$user"
echo -e "$pass\n$pass" | passwd "$user" >/dev/null

# UDP
echo "$user $pass" >> /etc/udp-custom/users

# TROJAN
trojan_pass=$(uuidgen)
sed -i "/\"users\":/a\        {\"password\": \"$trojan_pass\", \"email\": \"$user\"}," /etc/trojan-go/config.json
systemctl restart trojan-go

clear
echo -e "${GREEN}Akun berhasil dibuat!${NC}"

# ================== PAYLOAD =====================
echo -e "${BLUE}===== SSH WS 80 =====${NC}"
echo -e "GET / HTTP/1.1\nHost: $domain\nUpgrade: websocket\nConnection: Upgrade"

echo -e "${BLUE}===== SSH WS 443 =====${NC}"
echo -e "GET wss://$domain/ HTTP/1.1\nHost: $domain\nUpgrade: websocket\nConnection: Upgrade"

echo -e "${BLUE}===== TROJAN WS =====${NC}"
echo "trojan://$trojan_pass@$domain:443?type=ws&host=$domain&path=/trojan-ws&sni=$domain#$user"

echo -e "${BLUE}===== UDP CUSTOM =====${NC}"
echo "$domain:1-65535 | USER: $user | PASS: $pass"

read -p "ENTER untuk kembali..."
}

# =====================================================================
# 2. HAPUS USER
# =====================================================================
hapus_user() {
clear
echo -e "${YELLOW}Masukkan username:${NC}"
read user
userdel -f $user
sed -i "/$user/d" /etc/udp-custom/users
echo -e "${GREEN}User dihapus.${NC}"
read -p "ENTER..."
}

# =====================================================================
# 3. LIST USER
# =====================================================================
list_user() {
clear
echo -e "${BLUE}=== DAFTAR USER ===${NC}"
awk -F: '$3>=1000 {print $1}' /etc/passwd
read -p "ENTER..."
}

# =====================================================================
# 4. CREATE TROJAN MANUAL
# =====================================================================
create_trojan_manual() {
clear
read -rp "Password: " pass
domain=$(cat /etc/domain)

echo -e "${GREEN}Link:${NC}"
echo "trojan://$pass@$domain:443?type=ws&path=/trojan-ws&host=$domain&sni=$domain"

read -p "ENTER..."
}

# =====================================================================
# 5. CREATE TRIAL
# =====================================================================
trial_all() {
user="trial$(openssl rand -hex 3)"
pass="123"
exp=$(date -d "1 day" +%Y-%m-%d)
domain=$(cat /etc/domain)

useradd -e "$exp" -M -s /bin/false $user
echo -e "$pass\n$pass" | passwd "$user" >/dev/null

clear
echo -e "${GREEN}=== Trial Dibuat ===${NC}"
echo "User : $user"
echo "Pass : $pass"
echo "Exp  : $exp"

read -p "ENTER..."
}

# =====================================================================
# 6. TOGGLE USER (LOCK/UNLOCK)
# =====================================================================
akun_toggle() {
clear
read -rp "Username: " user
if passwd -S $user | grep -q "L"; then
    usermod -U $user
    echo -e "${GREEN}Akun diaktifkan.${NC}"
else
    usermod -L $user
    echo -e "${RED}Akun dinonaktifkan.${NC}"
fi
read -p "ENTER..."
}

# =====================================================================
# 7. DASHBOARD USER
# =====================================================================
show_dashboard() {
clear
echo -e "${BLUE}=== AKUN AKTIF ===${NC}"
awk -F: '$3>=1000 {print $1}' /etc/passwd
read -p "ENTER..."
}

# =====================================================================
# 8. BOT TELEGRAM
# =====================================================================
install_bot() {
clear
echo "Bot Telegram template siap."
read -p "ENTER..."
}

# =====================================================================
# 9. RESTART ALL
# =====================================================================
restart_all() {
systemctl restart udp-custom xray nginx trojan-go
echo -e "${GREEN}Service direstart.${NC}"
read -p "ENTER..."
}

# =====================================================================
# 10. REMOVE SCRIPT
# =====================================================================
remove_script() {
rm -f /usr/bin/menu
echo "Script dihapus."
read -p "ENTER..."
}

# =====================================================================
# 11. CREATE MANUAL FULL + PAYLOAD
# =====================================================================
create_manual() {
clear
echo -e "${YELLOW}=== CREATE MANUAL FULL ===${NC}"

read -rp "Domain : " domain
read -rp "Username : " user
read -rp "Password : " pass
read -rp "Aktif (hari): " day
read -rp "Max Login : " max

exp=$(date -d "$day days" +%Y-%m-%d)

useradd -e "$exp" -s /bin/false -M "$user"
echo -e "$pass\n$pass" | passwd "$user" >/dev/null

mkdir -p /etc/limit
echo "$max" >/etc/limit/$user

trojan_pass=$(uuidgen)
uuidv=$(uuidgen)

clear
echo -e "${GREEN}Akun Manual Dibuat${NC}"

echo -e "${BLUE}===== SSH WS 80 =====${NC}"
echo -e "GET / HTTP/1.1\nHost: $domain\nUpgrade: websocket\nConnection: Upgrade"

echo -e "${BLUE}===== SSH WS 443 TLS =====${NC}"
echo -e "GET wss://$domain/ HTTP/1.1\nHost: $domain\nUpgrade: websocket\nConnection: Upgrade"

echo -e "${BLUE}===== TROJAN WS =====${NC}"
echo "trojan://$trojan_pass@$domain:443?type=ws&path=/trojan-ws&host=$domain&sni=$domain"

echo -e "${BLUE}===== UDP =====${NC}"
echo "$domain:1-65535 | USER: $user | PASS: $pass"

read -p "ENTER..."
}

# =====================================================================
# 12. SET DOMAIN (BARU)
# =====================================================================
set_domain() {
clear
read -rp "Masukkan domain baru: " newdomain
echo "$newdomain" >/etc/domain
systemctl restart nginx xray trojan-go
echo -e "${GREEN}Domain berhasil diset: $newdomain${NC}"
read -p "ENTER..."
}

# =====================================================================
# MAIN MENU 1–13
# =====================================================================
while true; do
    banner
    read -rp "Pilih menu [1-13]: " x
    case $x in
        1) create_user_auto ;;
        2) hapus_user ;;
        3) list_user ;;
        4) create_trojan_manual ;;
        5) trial_all ;;
        6) akun_toggle ;;
        7) show_dashboard ;;
        8) install_bot ;;
        9) restart_all ;;
        10) remove_script ;;
        11) create_manual ;;
        12) set_domain ;;
        13) exit ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
