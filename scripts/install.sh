#!/bin/bash
# ============================================================
#  MY HOME SERVER v3.0 (Docker Edition)
#  Installer untuk STB B860H (S905X) - Armbian + SDCARD
# ============================================================

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOMESERVER_DIR="/opt/homeserver"
SWAP_FILE="/swapfile"
ZRAM_SIZE="${ZRAM_SIZE:-512M}"
SWAP_SIZE="${SWAP_SIZE:-2048}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'

FAILED=0

section() {
  echo ""
  echo -e "${BLUE}  ════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  [${WHITE}$1${BLUE}]${WHITE} $2${NC}"
  echo -e "${BLUE}  ════════════════════════════════════════════════${NC}"
  echo ""
}
info()  { echo -e "${CYAN}  [INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}  [ ✓ ]${NC}  $1"; }
warn()  { echo -e "${YELLOW}  [!]${NC}  $1"; }
err()   { echo -e "${RED}  [✗]${NC}  $1"; FAILED=1; }
run()   { step "$1..."; shift; "$@" && ok "$1" || err "$1"; return $?; }
step()  { echo -e "${MAGENTA}  -->${NC}  $1"; }
confirm() { echo ""; echo -e -n "${YELLOW}  [?]${NC} $1 [y/N]: "; read -r resp; [[ "$resp" =~ ^[Yy] ]]; }
get_ip() { hostname -I 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; }

banner() {
  clear
  echo ""
  echo -e "${CYAN}  ╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}  ║${WHITE}      MY HOME SERVER v${VERSION} (Docker)      ${CYAN}║${NC}"
  echo -e "${CYAN}  ║${NC}  ${YELLOW}B860H | S905X | Armbian${NC}              ${CYAN}║${NC}"
  echo -e "${CYAN}  ╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

check_root() {
  [[ $EUID -ne 0 ]] && { err "Jalankan: sudo bash install.sh"; exit 1; }
}

# ============================================================
# MAIN
# ============================================================

banner

cat <<DESC
  ${WHITE}Akan menginstall:${NC}
  ${GREEN}1.${NC} Docker + Docker Compose
  ${GREEN}2.${NC} ZRAM 512MB + SWAP 2GB + Optimasi S905X
  ${GREEN}3.${NC} Dashboard Flask (port 8080)
  ${GREEN}4.${NC} FileBrowser (port 8081)
  ${GREEN}5.${NC} CCTV NVR motionEye (port 8765)
  ${GREEN}6.${NC} Cloudflare Tunnel
  ${GREEN}7.${NC} TTYD + BTOP (port 7681)
  ${GREEN}8.${NC} Blog + Donasi

  ${YELLOW}Perkiraan waktu: 15-25 menit (tergantung koneksi)${NC}
DESC

confirm "Mulai instalasi?" || { info "Dibatalkan."; exit 0; }
check_root

# =================== 1. DOCKER ===================
section "1" "INSTALASI DOCKER"

if command -v docker &>/dev/null; then
  ok "Docker sudah terinstal ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
  run "Mengunduh script instalasi Docker" curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  run "Menjalankan installer Docker" bash /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
fi

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
  warn "Docker Compose plugin belum ada, install via apt..."
  apt-get install -y docker-compose-plugin 2>/dev/null || true
fi

# Wait for Docker to be ready
for i in $(seq 1 10); do
  docker ps &>/dev/null && break
  sleep 2
done

docker ps &>/dev/null && ok "Docker daemon berjalan" || err "Docker daemon tidak merespon"

# =================== 2. ZRAM ===================
section "2" "ZRAM + SWAP + OPTIMASI"

if [ -e /sys/block/zram0 ]; then
  swapoff /dev/zram0 2>/dev/null || true
  echo "$ZRAM_SIZE" > /sys/block/zram0/disksize 2>/dev/null
  mkswap /dev/zram0 2>/dev/null
  swapon -p 100 /dev/zram0 2>/dev/null
  ok "ZRAM ${ZRAM_SIZE} aktif prioritas tinggi"

  cat > /etc/systemd/system/zram-config.service << 'EOF'
[Unit]
Description=ZRAM
After=local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo 512M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0"
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload && systemctl enable zram-config.service 2>/dev/null
else
  warn "ZRAM tidak tersedia"
fi

if ! swapon --show 2>/dev/null | grep -v zram | grep -q /swapfile; then
  run "Membuat SWAP file ${SWAP_SIZE}MB" dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE" status=progress
  chmod 600 "$SWAP_FILE"
  mkswap "$SWAP_FILE"
  swapon "$SWAP_FILE"
  grep -q "$SWAP_FILE" /etc/fstab 2>/dev/null || echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
  ok "SWAP ${SWAP_SIZE}MB aktif"
fi

cat > /etc/sysctl.d/99-homeserver.conf << 'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.min_free_kbytes=16384
vm.page-cluster=0
kernel.nmi_watchdog=0
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
SYSCTL
sysctl -p /etc/sysctl.d/99-homeserver.conf 2>/dev/null
ok "Kernel parameters dioptimalkan"

# =================== 3. SETUP PROJECT ===================
section "3" "MENYALIN FILE PROJECT"

mkdir -p "$HOMESERVER_DIR"
mkdir -p "/storage/My Document" "/storage/My Music" "/storage/My Pictures" "/storage/My Videos" "/storage/My Videos/NVR"

rsync -a --delete "$SCRIPT_DIR/" "$HOMESERVER_DIR/" 2>/dev/null || cp -r "$SCRIPT_DIR/"* "$HOMESERVER_DIR/" 2>/dev/null
ok "File project disalin ke $HOMESERVER_DIR"

cd "$HOMESERVER_DIR" || { err "Gagal masuk direktori"; exit 1; }

# =================== 4. BUILD & START ===================
section "4" "MEMBANGUN & MENJALANKAN CONTAINER"

if [ -f .env.example ] && [ ! -f .env ]; then
  cp .env.example .env
  ok ".env dibuat dari .env.example (sesuaikan jika perlu)"
fi

run "Membangun image dashboard (Flask)" docker compose build dashboard

run "Menarik image dari registry" docker compose pull

# Initialize FileBrowser database
info "Inisialisasi FileBrowser user..."
mkdir -p /opt/homeserver/configs/filebrowser-data
if [ ! -f /opt/homeserver/configs/filebrowser-data/filebrowser.db ]; then
  docker run --rm \
    -v /opt/homeserver/configs/filebrowser-data:/database \
    filebrowser/filebrowser \
    filebrowser config init --database=/database/filebrowser.db 2>/dev/null
  docker run --rm \
    -v /opt/homeserver/configs/filebrowser-data:/database \
    filebrowser/filebrowser \
    filebrowser users add admin moch1234 --perm.admin --database=/database/filebrowser.db 2>/dev/null
  ok "User FileBrowser: admin / moch1234"
fi

run "Menjalankan semua container" docker compose up -d

sleep 5

# =================== 5. CLOUDFLARE TUNNEL ===================
section "5" "CLOUDFLARE TUNNEL (OPSIONAL)"

if confirm "Ingin konfigurasi Cloudflare Tunnel?"; then
  echo -e -n "  ${WHITE}Domain Anda (contoh: server.example.com): ${NC}"
  read -r DOMAIN
  if [ -n "$DOMAIN" ]; then
    sed -i "s/CLOUDFLARE_DOMAIN=.*/CLOUDFLARE_DOMAIN=$DOMAIN/" "$HOMESERVER_DIR/.env"
    mkdir -p "$HOMESERVER_DIR/configs/cloudflared"
    info "Jalankan autentikasi Cloudflare..."
    echo -e "  ${YELLOW}Browser akan terbuka. Login lalu pilih domain Anda.${NC}"
    echo ""
    read -p "  Tekan Enter setelah siap..."
    docker run --rm -it \
      -v "$HOMESERVER_DIR/configs/cloudflared:/home/nonroot/.cloudflared" \
      cloudflare/cloudflared tunnel login
    if [ -f "$HOMESERVER_DIR/configs/cloudflared/cert.pem" ]; then
      ok "Autentikasi berhasil!"
      docker run --rm \
        -v "$HOMESERVER_DIR/configs/cloudflared:/home/nonroot/.cloudflared" \
        cloudflare/cloudflared tunnel create homeserver
      TUN_ID=$(ls "$HOMESERVER_DIR/configs/cloudflared"/*.json 2>/dev/null | head -1 | xargs basename | sed 's/\.json//')
      if [ -n "$TUN_ID" ]; then
        cat > "$HOMESERVER_DIR/configs/cloudflared/config.yml" << TUNCFG
tunnel: ${TUN_ID}
credentials-file: /home/nonroot/.cloudflared/${TUN_ID}.json
ingress:
  - hostname: dashboard.${DOMAIN}
    service: http://dashboard:8080
  - hostname: files.${DOMAIN}
    service: http://filebrowser:80
  - hostname: nvr.${DOMAIN}
    service: http://motioneye:8765
  - hostname: status.${DOMAIN}
    service: http://ttyd:7681
  - service: http_status:404
TUNCFG
        docker run --rm \
          -v "$HOMESERVER_DIR/configs/cloudflared:/home/nonroot/.cloudflared" \
          cloudflare/cloudflared tunnel route dns homeserver "dashboard.${DOMAIN}"
        docker run --rm \
          -v "$HOMESERVER_DIR/configs/cloudflared:/home/nonroot/.cloudflared" \
          cloudflare/cloudflared tunnel route dns homeserver "files.${DOMAIN}"
        docker run --rm \
          -v "$HOMESERVER_DIR/configs/cloudflared:/home/nonroot/.cloudflared" \
          cloudflare/cloudflared tunnel route dns homeserver "nvr.${DOMAIN}"
        docker run --rm \
          -v "$HOMESERVER_DIR/configs/cloudflared:/home/nonroot/.cloudflared" \
          cloudflare/cloudflared tunnel route dns homeserver "status.${DOMAIN}"
        ok "DNS records dibuat"
        docker compose up -d cloudflared
        ok "Cloudflare Tunnel berjalan!"
      fi
    else
      err "Autentikasi gagal. Jalankan manual nanti."
    fi
  fi
else
  info "Cloudflare dilewati"
fi

# =================== 6. FIX NAVIGATION IP ===================
IP=$(get_ip)
if [ -n "$IP" ]; then
  sed -i "s/IP_SERVER/$IP/g" "$HOMESERVER_DIR/dashboard/templates/index.html"
  ok "IP $IP terpasang di navigasi dashboard"
fi

# =================== 7. STATUS ===================
section "STATUS" "CEK LAYANAN"

sleep 3
echo ""
for svc in dashboard filebrowser motioneye cloudflared ttyd; do
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi "$svc"; then
    echo -e "  ${GREEN}[RUNNING]${NC} $svc"
  else
    echo -e "  ${RED}[STOPPED]${NC} $svc"
    echo "  Log:"
    docker compose logs --tail=5 "$svc" 2>/dev/null | while read line; do echo "    $line"; done
  fi
done

# =================== SUMMARY ===================
section "SELESAI" "INSTALASI SELESAI!"

IP=$(get_ip)
[ -z "$IP" ] && IP="(cek hostname -I)"

echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║        INSTALASI SELESAI!        ${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${WHITE}Akses layanan:${NC}"
echo -e "  ${CYAN}  Dashboard :${NC} http://${IP}:8080"
echo -e "  ${CYAN}  Blog      :${NC} http://${IP}:8080/blog"
echo -e "  ${CYAN}  FileBrowser:${NC} http://${IP}:8081 (admin / moch1234)"
echo -e "  ${CYAN}  NVR CCTV  :${NC} http://${IP}:8765 (admin / moch1234)"
echo -e "  ${CYAN}  Terminal  :${NC} http://${IP}:7681 (admin / moch1234)"
echo ""
echo -e "  ${YELLOW}Manajemen:${NC}"
echo -e "  cd $HOMESERVER_DIR && docker compose ps"
echo -e "  cd $HOMESERVER_DIR && docker compose logs -f"
echo ""
[ "$FAILED" -eq 1 ] && echo -e "  ${YELLOW}Ada komponen gagal. Cek log di atas.${NC}"
echo ""
confirm "Reboot sekarang?" && reboot || warn "Jangan lupa reboot nanti"
