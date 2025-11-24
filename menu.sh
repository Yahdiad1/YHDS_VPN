#!/bin/bash
# =====================================================================
# YHDS VPN FULL MENU + PAYLOAD ALL-IN-ONE (FINAL VERSION)
# SSH / WS 80-443 / XRAY / TROJAN WS / UDP CUSTOM
# Menu 1–17 Full + Payload (manual create) + Renew Account
# =====================================================================

set -euo pipefail
IFS=$'\n\t'

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33;1m'; BLUE='\e[34;1m'; CYAN='\e[36;1m'; BOLD='\e[1m'; NC='\e[0m'

DOMAIN_FILE="/etc/domain"
UDP_USERS_FILE="/etc/udp-custom/users"
LIMIT_DIR="/etc/limit"
TROJAN_CONFIG="/etc/trojan-go/config.json"
XRAY_USERS_DIR="/etc/xray/users"   # best-effort path for xray per-user files (optional)
TROJAN_USER_DIR="/etc/trojan"      # optional per-user trojan metadata path
ACCOUNTS_EXPORT_DIR="/etc/akun"    # directory to export/save account txt

# Ensure required files/dirs
mkdir -p "$(dirname "$UDP_USERS_FILE")" "$LIMIT_DIR" "$XRAY_USERS_DIR" "$TROJAN_USER_DIR" "$ACCOUNTS_EXPORT_DIR"
touch "$UDP_USERS_FILE"
chmod 640 "$UDP_USERS_FILE" || true

# =====================================================================
# BANNER
# =====================================================================
banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "YHDS VPN MENU"
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
    echo -e "${YELLOW}${BOLD}1) Create User (Manual SSH/WS + UDP + Trojan)${NC}"
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
    echo -e "${YELLOW}${BOLD}14) Renew Akun (general)${NC}"
    echo -e "${YELLOW}${BOLD}15) Renew SSH (chage)${NC}"
    echo -e "${YELLOW}${BOLD}16) Renew Xray (user file)${NC}"
    echo -e "${YELLOW}${BOLD}17) Renew Trojan (per-user file)${NC}"
    echo -e "${YELLOW}${BOLD}========================================${NC}"
}

# Helper: get domain
get_domain() {
    if [ -s "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE"
    else
        echo "example.com"
    fi
}

# Helper: export account summary to file (optional)
export_account() {
    local user="$1"
    local content="$2"
    local file="$ACCOUNTS_EXPORT_DIR/${user}_$(date +%Y%m%d%H%M%S).txt"
    printf "%s\n" "$content" > "$file"
    chmod 600 "$file" || true
}

# Safe add trojan user (best-effort)
trojan_add_user() {
    local pass="$1"
    local email="$2"
    if [ ! -f "$TROJAN_CONFIG" ]; then
        # config not present, skip quietly
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq --arg pass "$pass" --arg email "$email" '.users += [{ "password": $pass, "email": $email }]' "$TROJAN_CONFIG" > "$tmp" && mv "$tmp" "$TROJAN_CONFIG"
    else
        cp "$TROJAN_CONFIG" "$TROJAN_CONFIG.bak.$(date +%s)" || true
        sed -i "/\"users\":/a\        {\"password\": \"$pass\", \"email\": \"$email\"}," "$TROJAN_CONFIG" || true
    fi
    systemctl restart trojan-go || true
}

# Safe remove trojan user by email
trojan_remove_user() {
    local email="$1"
    if [ ! -f "$TROJAN_CONFIG" ]; then return 0; fi
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq --arg email "$email" '.users |= map(select(.email != $email))' "$TROJAN_CONFIG" > "$tmp" && mv "$tmp" "$TROJAN_CONFIG"
    else
        cp "$TROJAN_CONFIG" "$TROJAN_CONFIG.bak.$(date +%s)" || true
        sed -i "/\"email\": \"$email\"/,+1d" "$TROJAN_CONFIG" || true
    fi
    systemctl restart trojan-go || true
}

# =====================================================================
# 1. CREATE USER MANUAL (SSH + WS + UDP + TROJAN)
# =====================================================================
create_user_auto() {
    clear
    echo -e "${YELLOW}=== CREATE USER MANUAL FULL ===${NC}"

    read -rp "Username        : " user
    read -rp "Password        : " pass
    read -rp "Expired (hari)  : " expday
    read -rp "Max Login       : " max

    if [[ -z "$user" || -z "$pass" ]]; then
        echo -e "${RED}Username and password cannot be empty.${NC}"
        read -p "ENTER..."
        return
    fi

    domain=$(get_domain)
    exp=$(date -d "$expday days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

    # ===== create system user (no shell) =====
    useradd -e "$exp" -s /usr/sbin/nologin -M "$user" || true
    printf "%s\n%s\n" "$pass" "$pass" | passwd "$user" >/dev/null 2>&1 || true

    # ===== LIMIT LOGIN =====
    echo "$max" > "$LIMIT_DIR/$user"

    # ===== UDP =====
    printf "%s %s\n" "$user" "$pass" >> "$UDP_USERS_FILE"

    # ===== TROJAN =====
    trojan_pass=$(uuidgen)
    trojan_add_user "$trojan_pass" "$user"

    # (optional) save a small trojan/user metadata file
    printf "user: %s\npass: %s\nexp: %s\n" "$user" "$trojan_pass" "$exp" > "$TROJAN_USER_DIR/$user" 2>/dev/null || true

    clear
    echo -e "${GREEN}Akun berhasil dibuat!${NC}"

    # ================== PAYLOAD BARU =====================
    out=$(cat <<EOF
━━━━━━━━━━━━━━━━━━ INFORMATION ACCOUNT SSH ━━━━━━━━━━━━━━━━━━
Username       : $user
Password       : $pass
Limit IP       : $max Device
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Domain         : $domain
OpenSSH        : 22
Dropbear       : 109, 143
SSL/TLS        : 443
SSH WS TLS     : 443
SSH WS NoneTLS : 80
SSH UDP Custom : 1-65535
OHP SSH        : 8686
OHP OVPN       : 8787
OVPN TCP       : 1194
OVPN UDP       : 2200
BadVPN UDP     : 7100,7200,7300
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSH WS TLS:
$domain:443@$user:$pass

SSH WS NONE TLS:
$domain:80@$user:$pass

SSH UDP CUSTOM:
$domain:1-65535@$user:$pass

━━━━━━━━━━━━━━━━ PAYLOAD SSH WS ━━━━━━━━━━━━━━━━━
GET / HTTP/1.1[crlf]
Host: $domain[crlf]
Connection: Upgrade[crlf]
User-Agent: [ua][crlf]
Upgrade: websocket[crlf][crlf]

━━━━━━━━━━━━━━━━ PAYLOAD ENHANCED ━━━━━━━━━━━━━━━━
PATCH / HTTP/1.1[crlf]
Host: $domain[crlf]
Host: bug.com[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
User-Agent: [ua][crlf][crlf]
HTTP/enhanced 200 Ok[crlf]

━━━━━━━━━━━━━━━━ PAYLOAD SPECIAL ━━━━━━━━━━━━━━━━━
GET / HTTP/1.1[crlf]
Host: [host][crlf][crlf][split]
CF-RAY / HTTP/1.1[crlf]
Host: $domain[crlf]
Connection: Keep-Alive[crlf]
Upgrade: websocket[crlf][crlf]

━━━━━━━━━━━━━━━━ CONFIG OPENVPN ━━━━━━━━━━━━━━━━━
https://$domain:81/

Active   : $expday Days
Created  : $(date +%d\ %b,\ %Y)
Expired  : $exp
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
)
    printf "%s\n" "$out"
    export_account "$user" "$out"

    read -p "ENTER untuk kembali..."
}

# =====================================================================
# 2. HAPUS USER
# =====================================================================
hapus_user() {
    clear
    echo -e "${YELLOW}Masukkan username:${NC}"
    read user
    if id "$user" >/dev/null 2>&1; then
        userdel -f "$user" || true
        sed -i "/^$user[[:space:]]/d" "$UDP_USERS_FILE" || true
        [ -f "$LIMIT_DIR/$user" ] && rm -f "$LIMIT_DIR/$user"
        [ -f "$TROJAN_USER_DIR/$user" ] && rm -f "$TROJAN_USER_DIR/$user"
        trojan_remove_user "$user"
        echo -e "${GREEN}User dihapus.${NC}"
    else
        echo -e "${RED}User tidak ditemukan.${NC}"
    fi
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
    domain=$(get_domain)

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

    useradd -e "$exp" -M -s /usr/sbin/nologin "$user" || true
    printf "%s\n%s\n" "$pass" "$pass" | passwd "$user" >/dev/null 2>&1 || true

    printf "${GREEN}=== Trial Dibuat ===${NC}\n"
    printf "User : %s\nPass : %s\nExp  : %s\n" "$user" "$pass" "$exp"

    read -p "ENTER..."
}

# =====================================================================
# 6. TOGGLE USER (LOCK/UNLOCK)
# =====================================================================
akun_toggle() {
    clear
    read -rp "Username: " user
    if ! id "$user" >/dev/null 2>&1; then
        echo -e "${RED}User tidak ditemukan.${NC}"
        read -p "ENTER..."
        return
    fi
    if passwd -S "$user" 2>/dev/null | grep -q " L "; then
        usermod -U "$user"
        echo -e "${GREEN}Akun diaktifkan.${NC}"
    else
        usermod -L "$user"
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
    awk -F: '$3>=1000 {print $1}' /etc/passwd | while read -r u; do
        last_login=$(lastlog -u "$u" | awk 'NR==2{print $4,$5,$6,$7}')
        printf "%-15s LastLogin: %s\n" "$u" "${last_login:-never}"
    done
    read -p "ENTER..."
}

# =====================================================================
# 8. BOT TELEGRAM (placeholder)
# =====================================================================
install_bot() {
    clear
    echo "Bot Telegram template siap. (implementasi manual)"
    read -p "ENTER..."
}

# =====================================================================
# 9. RESTART ALL
# =====================================================================
restart_all() {
    for s in udp-custom xray nginx trojan-go; do
        if systemctl list-unit-files | grep -q "^$s"; then
            systemctl restart "$s" || echo "Restart $s gagal"
        fi
    done
    echo -e "${GREEN}Service direstart.${NC}"
    read -p "ENTER..."
}

# =====================================================================
# 10. REMOVE SCRIPT
# =====================================================================
remove_script() {
    rm -f /usr/bin/menu || true
    echo "Script dihapus (jika ada di /usr/bin/menu)."
    read -p "ENTER..."
}

# =====================================================================
# 11. CREATE MANUAL FULL + PAYLOAD (domain input)
# =====================================================================
create_manual() {
    clear
    echo -e "${YELLOW}=== CREATE MANUAL FULL ===${NC}"

    read -rp "Domain : " domain
    read -rp "Username : " user
    read -rp "Password : " pass
    read -rp "Aktif (hari): " day
    read -rp "Max Login : " max

    exp=$(date -d "$day days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

    useradd -e "$exp" -s /usr/sbin/nologin -M "$user" || true
    printf "%s\n%s\n" "$pass" "$pass" | passwd "$user" >/dev/null 2>&1 || true

    mkdir -p "$LIMIT_DIR"
    echo "$max" > "$LIMIT_DIR/$user"

    trojan_pass=$(uuidgen)
    trojan_add_user "$trojan_pass" "$user"
    printf "user: %s\npass: %s\nexp: %s\n" "$user" "$trojan_pass" "$exp" > "$TROJAN_USER_DIR/$user" 2>/dev/null || true

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

    # export summary
    summary="User: $user\nPass: $pass\nDomain: $domain\nExp: $exp\nTrojanPass: $trojan_pass"
    export_account "$user" "$summary"

    read -p "ENTER..."
}

# =====================================================================
# 12. SET DOMAIN (BARU)
# =====================================================================
set_domain() {
    clear
    read -rp "Masukkan domain baru: " newdomain
    if [[ -z "$newdomain" ]]; then
        echo -e "${RED}Domain tidak boleh kosong${NC}"
        read -p "ENTER..."
        return
    fi
    printf "%s\n" "$newdomain" > "$DOMAIN_FILE"
    for s in nginx xray trojan-go; do
        if systemctl list-unit-files | grep -q "^$s"; then
            systemctl restart "$s" || true
        fi
    done
    echo -e "${GREEN}Domain berhasil diset: $newdomain${NC}"
    read -p "ENTER..."
}

# =====================================================================
# 14. RENEW AKUN (general)
#    - Extend account expiry using usermod -e (date)
# =====================================================================
renew_account() {
    clear
    echo -e "${YELLOW}=== RENEW AKUN SSH / WS / UDP / TROJAN (General) ===${NC}"
    read -rp "Username: " user
    if ! id "$user" >/dev/null 2>&1; then
        echo -e "${RED}User tidak ditemukan!${NC}"
        read -p "ENTER..."
        return
    fi
    old_exp=$(chage -l "$user" | awk -F": " '/Account expires/ {print $2}')
    echo -e "${CYAN}Expired saat ini: $old_exp${NC}"
    read -rp "Tambah hari berapa? : " add
    if ! [[ "$add" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Masukkan angka hari yang valid.${NC}"
        read -p "ENTER..."
        return
    fi
    new_exp=$(date -d "+$add days" +%Y-%m-%d)
    usermod -e "$new_exp" "$user"
    echo -e "${GREEN}=== RENEW BERHASIL ===${NC}"
    echo -e "User     : $user"
    echo -e "Expired  : $new_exp"
    read -p "ENTER..."
}

# =====================================================================
# 15. Renew SSH using chage/usermod (specifically)
# =====================================================================
renew_ssh() {
    clear
    echo "==== RENEW SSH (chage/usermod) ===="
    read -rp "Username : " user
    read -rp "Tambah hari : " days

    if ! id "$user" >/dev/null 2>&1; then
        echo "User tidak ditemukan!"
        read -n 1 -s -r -p "Tekan enter..."
        return
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Masukkan angka yang valid."
        read -n 1 -s -r -p "Tekan enter..."
        return
    fi

    new_exp=$(date -d "+$days days" +%Y-%m-%d)
    usermod -e "$new_exp" "$user"
    echo "Akun $user berhasil diperpanjang sampai $new_exp"
    read -n 1 -s -r -p "Tekan enter..."
}

# =====================================================================
# 16. Renew Xray (best-effort: edit per-user file under $XRAY_USERS_DIR)
# =====================================================================
renew_xray() {
    clear
    echo "==== RENEW XRAY (best-effort) ===="
    read -rp "Nama user (file nama di $XRAY_USERS_DIR) : " user
    read -rp "Tambah hari : " days

    file="$XRAY_USERS_DIR/$user"
    if [ ! -f "$file" ]; then
        echo "File user xray tidak ditemukan di $XRAY_USERS_DIR"
        read -n 1 -s -r -p "Tekan enter..."
        return
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Masukkan angka hari yang valid."
        read -n 1 -s -r -p "Tekan enter..."
        return
    fi

    # try to parse existing expiry (assumes a line like: Exp: YYYY-MM-DD)
    EXP=$(grep -i '^Exp:' "$file" | awk -F': ' '{print $2}' || true)
    if [[ -z "$EXP" ]]; then
        # if not present, set from today
        OLD_DATE=$(date +%Y-%m-%d)
    else
        OLD_DATE="$EXP"
    fi
    NEWEXP=$(date -d "$OLD_DATE +$days days" +%Y-%m-%d)
    # replace or append Exp:
    if grep -qi '^Exp:' "$file"; then
        sed -i "s/^Exp:.*/Exp: $NEWEXP/" "$file" || true
    else
        echo "Exp: $NEWEXP" >> "$file"
    fi
    systemctl restart xray || true
    echo "User $user berhasil di renew sampai $NEWEXP"
    read -n 1 -s -r -p "Tekan enter..."
}

# =====================================================================
# 17. Renew Trojan (best-effort: edit per-user file under $TROJAN_USER_DIR)
# =====================================================================
renew_trojan() {
    clear
    echo "==== RENEW TROJAN (best-effort) ===="
    read -rp "User : " user
    read -rp "Tambah hari : " days

    file="$TROJAN_USER_DIR/$user"
    if [ ! -f "$file" ]; then
        echo "File metadata trojan tidak ditemukan di $TROJAN_USER_DIR"
        read -n 1 -s -r -p "Tekan enter..."
        return
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Masukkan angka hari yang valid."
        read -n 1 -s -r -p "Tekan enter..."
        return
    fi

    EXP=$(grep -i '^exp:' "$file" | awk -F': ' '{print $2}' || true)
    if [[ -z "$EXP" ]]; then
        OLD_DATE=$(date +%Y-%m-%d)
    else
        OLD_DATE="$EXP"
    fi
    NEWEXP=$(date -d "$OLD_DATE +$days days" +%Y-%m-%d)
    if grep -qi '^exp:' "$file"; then
        sed -i "s/^exp:.*/exp: $NEWEXP/" "$file" || true
    else
        echo "exp: $NEWEXP" >> "$file"
    fi
    systemctl restart trojan-go || true
    echo "Akun $user trojan berhasil diperpanjang sampai $NEWEXP"
    read -n 1 -s -r -p "Tekan enter..."
}

# =====================================================================
# MAIN MENU 1–17
# =====================================================================
while true; do
    banner
    read -rp "Pilih menu [1-17]: " x
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
        13) exit 0 ;;
        14) renew_account ;;
        15) renew_ssh ;;
        16) renew_xray ;;
        17) renew_trojan ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
