#!/bin/bash
# install.sh — YHDS-VPN Full installer (Cloudflare DNS + Certbot DNS challenge -> FULL SSL)
# Supports Ubuntu 20.04, Debian 11
set -euo pipefail
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'; BLUE='\e[34m'; NC='\e[0m'

# ========== CONFIG DEFAULT (ubah sebelum upload jika perlu) ==========
DOMAIN_ROOT="yhds.my.id"
DOMAIN_WWW="www.yhds.my.id"
DOMAIN_SSH="ssh.yhds.my.id"
DOMAIN_UDP="udp.yhds.my.id"
DOMAIN_XRAY="xray.yhds.my.id"
DOMAIN_TROJAN="trojan.yhds.my.id"
LE_EMAIL="admin@${DOMAIN_ROOT}"
# =====================================================================

echo -e "${GREEN}YHDS-VPN Full Installer (fixed awks)${NC}"
. /etc/os-release 2>/dev/null || true
echo "Detected OS: ${NAME:-unknown} ${VERSION:-}"

read -p "Continue installer? (y/N): " cont
if [[ "${cont,,}" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt update -y
apt upgrade -y

# =====================
# FIX AWK – install gawk if missing
# =====================
echo "Checking AWK..."
if ! command -v awk >/dev/null 2>&1; then
  echo "AWK not found — installing gawk..."
  apt update -y
  apt install -y gawk
else
  echo "AWK present: $(awk --version 2>/dev/null | head -n1 || true)"
fi

# essential packages
apt install -y wget curl unzip jq git socat cron nginx openssl ca-certificates \
 python3 python3-pip python3-certbot python3-certbot-dns-cloudflare \
 figlet lolcat bc sed coreutils

# create folders
mkdir -p /etc/YHDS /etc/YHDS/system /root/.secrets/certbot /root/udp /var/log/xray

# ---------- Ask Cloudflare token ----------
echo
echo "If you want automatic DNS & Certbot DNS challenge, prepare Cloudflare API token (Zone:Read, DNS:Edit)."
read -p "Use Cloudflare API token? (y/N): " use_cf
CF_API_TOKEN=""
CF_ZONE_ID=""
if [[ "${use_cf,,}" == "y" ]]; then
  read -p "Enter Cloudflare API token: " CF_API_TOKEN
  CF_AUTH_HDR="Authorization: Bearer ${CF_API_TOKEN}"
  ZONE_NAME="${DOMAIN_ROOT#*.}"
  CF_ZONE_ID="$(curl -s -X GET \"https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}\" -H \"${CF_AUTH_HDR}\" -H \"Content-Type: application/json\" | jq -r '.result[0].id // empty')"
  if [[ -z "$CF_ZONE_ID" ]]; then
    echo -e "${YELLOW}Warning: Could not auto-detect CF Zone ID for ${ZONE_NAME}.${NC}"
    CF_ZONE_ID=""
  else
    echo -e "${GREEN}Cloudflare Zone ID detected: ${CF_ZONE_ID}${NC}"
  fi
fi

cf_create_a(){
  local name="$1"; local proxied="$2"
  if [[ -z "$CF_API_TOKEN" || -z "$CF_ZONE_ID" ]]; then
    echo -e "${YELLOW}Skipping CF create for ${name}.${DOMAIN_ROOT}${NC}"; return 1
  fi
  local fqdn="${name}.${DOMAIN_ROOT}"
  local exists
  exists=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${fqdn}" -H "${CF_AUTH_HDR}" -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
  if [[ -n "$exists" ]]; then
    echo "Updating ${fqdn} -> ${VPS_IP} (proxied=${proxied})"
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${exists}" -H "${CF_AUTH_HDR}" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"${fqdn}\",\"content\":\"${VPS_IP}\",\"ttl\":120,\"proxied\":${proxied}}" >/dev/null
  else
    echo "Creating ${fqdn} -> ${VPS_IP} (proxied=${proxied})"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" -H "${CF_AUTH_HDR}" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"${fqdn}\",\"content\":\"${VPS_IP}\",\"ttl\":120,\"proxied\":${proxied}}" >/dev/null
  fi
  return 0
}

# detect public IP
VPS_IP="$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')"
echo -e "${BLUE}VPS public IP detected: ${VPS_IP}${NC}"

# create DNS records (if token provided)
if [[ -n "$CF_API_TOKEN" && -n "$CF_ZONE_ID" ]]; then
  echo "Creating/updating DNS records on Cloudflare..."
  cf_create_a "@" true || true
  cf_create_a "www" true || true
  cf_create_a "yhds" true || true || true
  cf_create_a "xray" true || true || true
  cf_create_a "trojan" true || true || true
  cf_create_a "ssh" false || true
  cf_create_a "udp" false || true
  sleep 2
fi

# ---------------- Install Xray ----------------
echo -e "${GREEN}Installing Xray...${NC}"
bash -c "$(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1 || echo -e "${YELLOW}Xray installer returned warnings (continue)${NC}"

cat > /etc/xray/config.json <<XCONF
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [{ "id": "00000000-0000-0000-0000-000000000000" }], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/xray", "headers": { "Host": "'"${DOMAIN_ROOT}"'" } } }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [{ "id": "11111111-1111-1111-1111-111111111111" }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess", "headers": { "Host": "'"${DOMAIN_ROOT}"'" } } }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} } ]
}
XCONF

systemctl daemon-reload || true
systemctl enable xray >/dev/null 2>&1 || true
systemctl restart xray || echo -e "${YELLOW}xray restart may have issues${NC}"

# ---------------- Install trojan-go ----------------
echo -e "${GREEN}Installing Trojan-Go...${NC}"
TGZ_URL="https://github.com/p4gefau1t/trojan-go/releases/latest/download/trojan-go-linux-amd64.zip"
TMPZIP="/tmp/trojan-go.zip"
if wget -qO "$TMPZIP" "$TGZ_URL"; then
  unzip -o "$TMPZIP" -d /usr/local/bin >/dev/null 2>&1 || true
  chmod +x /usr/local/bin/trojan-go || true
  rm -f "$TMPZIP"
fi

cat > /etc/trojan-go/config.json <<TCONF
{
  "run_type": "server",
  "local_addr": "127.0.0.1",
  "local_port": 10002,
  "password": ["YHDS-TG-DEFAULT-PASS"],
  "websocket": { "enabled": true, "path": "/trojan", "host": "${DOMAIN_ROOT}" },
  "ssl": { "cert": "/etc/letsencrypt/live/${DOMAIN_ROOT}/fullchain.pem", "key": "/etc/letsencrypt/live/${DOMAIN_ROOT}/privkey.pem" }
}
TCONF

cat > /etc/systemd/system/trojan-go.service <<TSRV
[Unit]
Description=trojan-go
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=always
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
TSRV

systemctl daemon-reload
systemctl enable trojan-go >/dev/null 2>&1 || true
systemctl restart trojan-go || true

# ---------------- Nginx site (placeholder; updated after cert) ----------------
cat > /etc/nginx/sites-available/yhds.conf <<'NGCONF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;
    location / { return 301 https://$host$request_uri; }
}
server {
    listen 443 ssl http2;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location /xray {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location = / { try_files /index.html =404; }
}
NGCONF

sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN_ROOT//\//\\/}/g" /etc/nginx/sites-available/yhds.conf
ln -sf /etc/nginx/sites-available/yhds.conf /etc/nginx/sites-enabled/yhds.conf
nginx -t || true
systemctl restart nginx || true

# ---------------- UDP custom ----------------
echo -e "${GREEN}Installing UDP custom binary...${NC}"
GITHUB_RAW="https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main"
wget -q "$GITHUB_RAW/udp-custom-linux-amd64" -O /root/udp/udp-custom || echo -e "${YELLOW}Warning: failed to download udp-custom${NC}"
chmod +x /root/udp/udp-custom || true

cat > /root/udp/config.json <<UCFG
{
  "listen": "0.0.0.0",
  "start_port": 20000,
  "end_port": 30000,
  "max_clients": 1000,
  "threads": 4,
  "mode": "auto"
}
UCFG
chmod 644 /root/udp/config.json

cat > /etc/systemd/system/udp-custom.service <<UDPSRV
[Unit]
Description=YHDS UDP Custom
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom server -c /root/udp/config.json
Restart=always
RestartSec=3s
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
UDPSRV

systemctl daemon-reload
systemctl enable udp-custom >/dev/null 2>&1 || true
systemctl restart udp-custom || true

# ---------------- Certbot DNS Cloudflare (Let's Encrypt) ----------------
if [[ -n "$CF_API_TOKEN" ]]; then
  echo -e "${GREEN}Creating Cloudflare credentials for certbot...${NC}"
  mkdir -p /root/.secrets/certbot
  cat > /root/.secrets/certbot/cloudflare.ini <<CFINI
dns_cloudflare_api_token = ${CF_API_TOKEN}
CFINI
  chmod 600 /root/.secrets/certbot/cloudflare.ini

  echo -e "${GREEN}Requesting Let's Encrypt certificates via DNS challenge for: ${DOMAIN_ROOT}, ${DOMAIN_WWW}, ${DOMAIN_SSH}, ${DOMAIN_UDP}${NC}"
  certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/certbot/cloudflare.ini \
    --non-interactive --agree-tos -m "${LE_EMAIL}" -d "${DOMAIN_ROOT}" -d "${DOMAIN_WWW}" -d "${DOMAIN_SSH}" -d "${DOMAIN_UDP}" || {
      echo -e "${YELLOW}Certbot failed to issue certs. Please check DNS records and token permissions.${NC}"
    }

  if [[ -f /etc/letsencrypt/live/${DOMAIN_ROOT}/fullchain.pem ]]; then
    echo -e "${GREEN}Certificates obtained. Restarting nginx & trojan-go...${NC}"
    systemctl restart nginx || true
    systemctl restart trojan-go || true
  fi
else
  echo -e "${YELLOW}No Cloudflare token provided -> skipping certbot. You can later add origin cert or issue cert manually.${NC}"
fi

# ---------------- Save domain config file ----------------
cat > /etc/YHDS/domain.conf <<DCONF
${DOMAIN_ROOT}
${DOMAIN_WWW}
${DOMAIN_SSH}
${DOMAIN_UDP}
DCONF
chmod 644 /etc/YHDS/domain.conf

# ---------------- Create menu & helpers (install menu.sh & setdomain.sh) ----------------

# write menu.sh and setdomain.sh into /usr/local/bin for convenience
cat > /usr/local/bin/menu.sh <<'MENU'
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

  echo ""
  echo -e "${YELLOW}========== PAYLOAD SSH / WEBSOCKET ==========${NC}"
  echo "ssh://${USERNAME}:${PASSWORD}@${DOMAIN_SSH}:22"
  echo "wss://${USERNAME}:${PASSWORD}@${DOMAIN_SSH}:443"
  echo ""
  echo -e "${YELLOW}========== PAYLOAD TROJAN ==========${NC}"
  echo "trojan://${PASSWORD}@${DOMAIN_ROOT}:443#${USERNAME}"
  echo ""
  echo -e "${YELLOW}========== PAYLOAD UDP CUSTOM ==========${NC}"
  echo "${DOMAIN_UDP}:1-65535@${USERNAME}:${PASSWORD}"
  echo ""
  read -n 1 -s -r -p "Tekan Enter untuk kembali ke menu..."
}

setting_domain() {
  clear
  echo "=== Setting Domain (MODE A - snakeoil kept, update configs only) ==="
  read -p "Masukkan domain root (example: yhds.my.id): " DROOT
  read -p "Masukkan domain www (example: www.yhds.my.id): " DWWW
  read -p "Masukkan domain ssh (example: ssh.yhds.my.id): " DSSH
  read -p "Masukkan domain udp (example: udp.yhds.my.id): " DUDP

  mkdir -p /etc/YHDS
  echo "${DROOT}" > /etc/YHDS/domain.conf
  echo "${DWWW}" >> /etc/YHDS/domain.conf
  echo "${DSSH}" >> /etc/YHDS/domain.conf
  echo "${DUDP}" >> /etc/YHDS/domain.conf

  # update common.sh domain vars if exist
  if [ -f /etc/YHDS/system/common.sh ]; then
    sed -i "s/^DOMAIN_ROOT=.*/DOMAIN_ROOT=\"${DROOT}\"/" /etc/YHDS/system/common.sh 2>/dev/null || true
    sed -i "s/^DOMAIN_WWW=.*/DOMAIN_WWW=\"${DWWW}\"/" /etc/YHDS/system/common.sh 2>/dev/null || true
    sed -i "s/^DOMAIN_SSH=.*/DOMAIN_SSH=\"${DSSH}\"/" /etc/YHDS/system/common.sh 2>/dev/null || true
    sed -i "s/^DOMAIN_UDP=.*/DOMAIN_UDP=\"${DUDP}\"/" /etc/YHDS/system/common.sh 2>/dev/null || true
  fi

  # update nginx server_name
  sed -i "s/server_name .*/server_name ${DROOT} ${DWWW};/" /etc/nginx/sites-available/yhds.conf || true

  # update trojan host in config
  if [ -f /etc/trojan-go/config.json ] && command -v jq >/dev/null 2>&1; then
    jq --arg h "${DROOT}" '.websocket.host=$h' /etc/trojan-go/config.json > /etc/trojan-go/config.json.tmp && mv /etc/trojan-go/config.json.tmp /etc/trojan-go/config.json || true
  else
    sed -i "s/\"host\": \".*\"/\"host\": \"${DROOT}\"/g" /etc/trojan-go/config.json 2>/dev/null || true
  fi

  # update xray host headers
  if [ -f /etc/xray/config.json ]; then
    sed -i "s/\"Host\": \".*\"/\"Host\": \"${DROOT}\"/g" /etc/xray/config.json || true
  fi

  systemctl restart nginx || true
  systemctl restart xray || true
  systemctl restart trojan-go || true
  systemctl restart udp-custom || true

  echo -e "${GREEN}Domain updated and services restarted. Saved to /etc/YHDS/domain.conf${NC}"
  read -n 1 -s -r -p "Tekan Enter untuk kembali ke menu..."
}

while true; do
  clear
  figlet -f slant "YHDS VPN" | lolcat 2>/dev/null || echo -e "=== YHDS VPN ==="
  echo -e "Status Server:"
  status
  echo ""
  echo -e " 1) Create User (manual + payload)"
  echo -e " 2) Hapus User"
  echo -e " 3) Daftar User"
  echo -e " 4) Create Trojan"
  echo -e " 5) Create Trial"
  echo -e " 6) Toggle ON/OFF Akun"
  echo -e " 7) Dashboard Status"
  echo -e " 8) Install Bot Telegram"
  echo -e " 9) Restart Semua Service"
  echo -e "10) Uninstall Script"
  echo -e "11) Keluar"
  echo -e "12) Setting Domain"
  read -p "Pilih menu [1-12]: " opt
  case "$opt" in
    1) create_user_payload ;;
    2) /etc/YHDS/system/DelUser.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    3) /etc/YHDS/system/Userlist.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    4) /etc/YHDS/system/CreateTrojan.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    5) /etc/YHDS/system/CreateTrial.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    6) /etc/YHDS/system/ToggleUser.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    7) /etc/YHDS/system/DashboardStatus.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    8) /etc/YHDS/system/InstallBot.sh; read -n 1 -s -r -p "Press any key to return..." ;;
    9)
      echo "Restarting services..."
      for s in udp-custom xray nginx trojan-go; do systemctl restart $s >/dev/null 2>&1; done
      echo -e "${GREEN}Selesai restart!${NC}"
      read -n 1 -s -r -p "Press any key to return..."
      ;;
    10)
      read -p "Yakin hapus semua script YHDS? (y/n): " YN
      if [[ "$YN" == "y" ]]; then
        systemctl stop udp-custom >/dev/null 2>&1 || true
        systemctl disable udp-custom >/dev/null 2>&1 || true
        rm -rf /etc/YHDS /root/udp /usr/local/bin/menu.sh
        echo -e "${RED}Semua script dihapus!${NC}"
        exit 0
      fi
      ;;
    11) echo "Keluar dari menu"; exit 0 ;;
    12) setting_domain ;;
    *) echo "Pilihan tidak valid"; sleep 1 ;;
  esac
done
MENU
chmod +x /usr/local/bin/menu.sh

# set domain helper
cat > /usr/local/bin/setdomain.sh <<'SETD'
#!/bin/bash
read -p "Domain root (yhds.my.id): " DROOT
read -p "Domain www (www.yhds.my.id): " DWWW
read -p "Domain ssh (ssh.yhds.my.id): " DSSH
read -p "Domain udp (udp.yhds.my.id): " DUDP
mkdir -p /etc/YHDS
echo "${DROOT}" > /etc/YHDS/domain.conf
echo "${DWWW}" >> /etc/YHDS/domain.conf
echo "${DSSH}" >> /etc/YHDS/domain.conf
echo "${DUDP}" >> /etc/YHDS/domain.conf
echo "Domains saved to /etc/YHDS/domain.conf"
systemctl restart nginx xray trojan-go udp-custom || true
SETD
chmod +x /usr/local/bin/setdomain.sh

# simple common.sh for other scripts
cat > /etc/YHDS/system/common.sh <<'COMMON'
#!/bin/bash
IP="$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')"
DOMAIN_ROOT="yhds.my.id"
DOMAIN_WWW="www.yhds.my.id"
DOMAIN_SSH="ssh.yhds.my.id"
DOMAIN_UDP="udp.yhds.my.id"
print_payload() {
  USER="$1"; PASS="$2"
  echo "================ PAYLOAD ================"
  echo "SSH WS TLS   : ${DOMAIN_SSH}:443@${USER}:${PASS}"
  echo "VMESS WS     : path /vmess host ${DOMAIN_ROOT}"
  echo "VLESS WS     : path /xray host ${DOMAIN_ROOT}"
  echo "TROJAN       : trojan://${PASS}@${DOMAIN_ROOT}:443#${USER}"
  echo "UDP CUSTOM   : ${DOMAIN_UDP}:1-65535@${USER}:${PASS}"
  echo "========================================="
}
send_tele() { MSG="$1"; if [ -f /etc/YHDS/telegram.env ]; then source /etc/YHDS/telegram.env; curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d parse_mode="Markdown" -d text="${MSG}" >/dev/null 2>&1 || true; fi }
get_services_status_md() { SVC="udp-custom xray nginx trojan-go"; OUT=""; for s in $SVC; do if systemctl is-active --quiet $s; then OUT="${OUT}\n• ${s}: ✅ ON"; else OUT="${OUT}\n• ${s}: ❌ OFF"; fi; done; echo -e "$OUT"; }
COMMON
chmod +x /etc/YHDS/system/common.sh

# creatuser basic (compatibility)
cat > /etc/YHDS/system/creatuser.sh <<'CU'
#!/bin/bash
set -euo pipefail
source /etc/YHDS/system/common.sh || true
if [[ "$1" == "manual" ]]; then
  USER="$2"; PASS="$3"; DAYS="$4"; MAX="$5"
else
  read -p "Username: " USER
  read -p "Password: " PASS
  read -p "Expired (days): " DAYS
fi
EXPIRE=$(date -d "+${DAYS} days" +"%Y-%m-%d")
useradd -M -N -s /bin/false "$USER" 2>/dev/null || true
echo "${USER}:${PASS}" | chpasswd || true
mkdir -p /etc/YHDS/system
echo "${USER}|${PASS}|${EXPIRE}|ON" >> /etc/YHDS/system/ssh-users.txt
echo "${USER}|${PASS}|${EXPIRE}|ON" >> /etc/YHDS/system/udp-users.txt
echo "${USER}|${PASS}|${EXPIRE}|ON" >> /etc/YHDS/system/trojan-users.txt
print_payload "$USER" "$PASS"
CU
chmod +x /etc/YHDS/system/creatuser.sh

# autostart menu on root login
if ! grep -q "/usr/local/bin/menu.sh" /root/.bashrc 2>/dev/null; then
  echo "/usr/local/bin/menu.sh" >> /root/.bashrc
fi

# final
clear
figlet -f slant "YHDS VPN" | lolcat 2>/dev/null || true
echo -e "${GREEN}Install complete!${NC}"
echo "Run '/usr/local/bin/menu.sh' or logout/login to auto-start menu."
echo "Domain config: /etc/YHDS/domain.conf"
echo "If certbot failed, re-run certbot with Cloudflare credentials at /root/.secrets/certbot/cloudflare.ini"
