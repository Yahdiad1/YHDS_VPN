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

  # jalankan script creatuser asli
  /etc/YHDS/system/creatuser.sh manual "$USERNAME" "$PASSWORD" "$EXPIRE" "$MAX"

  echo -e "${GREEN}User $USERNAME berhasil dibuat!${NC}"

  # Ambil IP publik
  IP=$(curl -s https://ipinfo.io/ip)

  echo ""
  echo -e "${YELLOW}========== PAYLOAD SSH / WEBSOCKET ==========${NC}"
  echo "ssh://${USERNAME}:${PASSWORD}@${IP}:22"
  echo "ws://${USERNAME}:${PASSWORD}@${IP}:443"
  echo ""

  echo -e "${YELLOW}========== PAYLOAD TROJAN ==========${NC}"
  echo "trojan://${PASSWORD}@${IP}:443#${USERNAME}"
  echo "trojan://${PASSWORD}@${IP}:80#${USERNAME}"
  echo ""

  echo -e "${YELLOW}========== PAYLOAD UDP CUSTOM ==========${NC}"
  echo "${IP}:1-65535@${USERNAME}:${PASSWORD}"
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
  echo -e "${YELLOW} 4) Create Trojan${NC}"
  echo -e "${YELLOW} 5) Create Trial${NC}"
  echo -e "${YELLOW} 6) Toggle ON/OFF Akun${NC}"
  echo -e "${YELLOW} 7) Dashboard Status${NC}"
  echo -e "${YELLOW} 8) Install Bot Telegram${NC}"
  echo -e "${YELLOW} 9) Restart Semua Service${NC}"
  echo -e "${YELLOW}10) Uninstall Script${NC}"
  echo -e "${YELLOW}11) Keluar${NC}"
  echo -e "${BLUE}========================================${NC}"

  read -p "Pilih menu [1-11]: " opt
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
          systemctl stop udp-custom >/dev/null 2>&1
          systemctl disable udp-custom >/dev/null 2>&1
          rm -rf /etc/YHDS /root/udp /usr/local/bin/menu
          echo -e "${RED}Semua script dihapus!${NC}"
          exit 0
        fi
       ;;
    11) echo "Keluar dari menu"; exit 0 ;;
    *) echo "Pilihan tidak valid"; sleep 1 ;;
  esac
done
