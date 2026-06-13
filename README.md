# My Home Server 🖥️

**Self-Hosted di STB B860H (S905X) — Docker Edition**

STB dengan **eMMC rusak** diubah menjadi server rumahan serbaguna. Semua layanan berjalan di **Docker container**, data disimpan di **SD Card**.

---

## 📋 Spesifikasi

| Komponen | Detail |
|----------|--------|
| **Device** | STB B860H v1 |
| **SoC** | Amlogic S905X (ARM Cortex-A53) |
| **RAM** | 1 GB + ZRAM 512MB + SWAP 2GB |
| **Storage** | SD Card |
| **OS** | Armbian + Docker |

---

## ✨ Layanan

| Layanan | Port | Container | Fungsi |
|---------|------|-----------|--------|
| **Dashboard** | `:8080` | Flask (custom) | Monitor CPU, RAM, ZRAM, SWAP, disk, network |
| **Blog** | `/blog` | via Dashboard | Catatan static |
| **FileBrowser** | `:8081` | `filebrowser/filebrowser` | Manajemen file web |
| **CCTV NVR** | `:8765` | `ccrisan/motioneye` | Rekam kamera IP 24 jam |
| **Cloudflare** | — | `cloudflare/cloudflared` | Tunnel akses dari luar |
| **Terminal** | `:7681` | `tsl0922/ttyd` | BTOP monitoring via browser |

---

## 🚀 Instalasi

### 1. Copy project ke STB
```bash
scp -r homeserver/ root@IP_STB:/root/
ssh root@IP_STB
```

### 2. Jalankan installer
```bash
cd /root/homeserver
sudo bash scripts/install.sh
```

### 3. Tunggu selesai (~15-25 menit)
Installer akan otomatis:
- Install Docker + Docker Compose
- Konfigurasi ZRAM 512MB + SWAP 2GB
- Optimasi kernel untuk S905X
- Bangun & jalankan semua container
- Setup Cloudflare Tunnel (opsional)

### 4. Reboot (direkomendasikan)
```bash
sudo reboot
```

---

## 📁 Struktur Project

```
/opt/homeserver/
├── docker-compose.yml         # Semua service
├── .env                       # Konfigurasi (dari .env.example)
├── .env.example               # Template konfigurasi
├── dashboard/                 # Custom Flask container
│   ├── Dockerfile
│   ├── app.py                 # Monitoring backend
│   ├── requirements.txt
│   └── templates/index.html   # Dashboard UI
├── blog/index.html            # Blog static
├── configs/
│   ├── filebrowser.json       # FileBrowser config
│   ├── filebrowser-data/      # Database (auto-generated)
│   ├── cloudflared/           # Cloudflare credentials
│   └── motioneye/
│       ├── motioneye.conf     # motionEye config
│       └── camera-1.conf      # Kamera config
└── scripts/install.sh         # Installer
```

Penyimpanan data di `/storage/`:
```
/storage/
├── My Document/
├── My Music/
├── My Pictures/
├── My Videos/
│   └── NVR/          # Rekaman CCTV
```

---

## 🔧 Manajemen

```bash
# Masuk direktori
cd /opt/homeserver

# Lihat status container
docker compose ps

# Log real-time
docker compose logs -f

# Restart satu service
docker compose restart dashboard

# Update semua image
docker compose pull && docker compose up -d

# Hentikan semua
docker compose down
```

### Login default
| Layanan | User | Password |
|---------|------|----------|
| FileBrowser | admin | moch1234 |
| motionEye | admin | moch1234 |
| TTYD | admin | moch1234 |

---

## ☁️ Cloudflare Tunnel

Saat instalasi, akan ditanya domain. Jika diisi, tunnel otomatis diatur:

```
https://dashboard.domain-anda.com
https://files.domain-anda.com
https://nvr.domain-anda.com
https://status.domain-anda.com
```

Konfigurasi ulang manual:
```bash
docker compose run --rm cloudflared tunnel login
docker compose up -d cloudflared
```

---

## ❤️ Donasi

| Metode | Detail |
|--------|--------|
| **DANA** | 085323073037 (Budi Joko) |
| **Mandiri** | 1310014031126 (Budi Joko) |
| **BNI** | 2027537451 (Budi Joko) |
| **QRIS** | Scan via DANA |
| **Konfirmasi** | [WhatsApp](https://wa.me/6285323073037) |

---
