# My Home Server

> **Self-Hosted di STB Bekas — Semua Layanan Berjalan di Docker**

Proyek ini mengubah **STB B860H (S905X)** dengan **eMMC rusak** menjadi server rumahan serbaguna.  
Karena eMMC rusak, sistem dan data sepenuhnya berjalan dari **SD Card**. Semua layanan dikemas dalam **Docker container** — bebas dependency conflict, mudah di-update.

[![Armbian](https://img.shields.io/badge/OS-Armbian-red)](https://www.armbian.com/)
[![Docker](https://img.shields.io/badge/runtime-Docker-2496ED)](https://www.docker.com/)
[![Flask](https://img.shields.io/badge/dashboard-Flask-black)](https://flask.palletsprojects.com/)
[![License](https://img.shields.io/badge/license-MIT-green)]()

---

## Daftar Isi

- [Spesifikasi Perangkat](#spesifikasi-perangkat)
- [Fitur Layanan](#fitur-layanan)
- [Cara Install (Lengkap)](#cara-install-lengkap)
- [Pertama Kali Akses](#pertama-kali-akses)
- [Struktur Folder](#struktur-folder)
- [Manajemen Sehari-hari](#manajemen-sehari-hari)
- [Cloudflare Tunnel](#cloudflare-tunnel)
- [Troubleshooting](#troubleshooting)
- [Donasi](#donasi)

---

## Spesifikasi Perangkat

| Komponen | Keterangan |
|----------|------------|
| **Device** | STB B860H v1 |
| **SoC** | Amlogic S905X (ARM Cortex-A53, 64-bit) |
| **RAM** | 1 GB DDR3 |
| **ROM** | 8 GB eMMC (**rusak — tidak dipakai**) |
| **Storage aktif** | SD Card (kelas 10 / A1 direkomendasikan) |
| **Koneksi** | LAN 100Mbps + Wi-Fi |
| **OS** | Armbian (Linux 6.x) |

### Optimasi Memori

| Fitur | Kapasitas | Fungsi |
|-------|-----------|--------|
| **ZRAM** | 512 MB | Kompresi memori — mengurangi tekanan RAM |
| **SWAP file** | 2 GB | Cadangan di SD Card untuk proses idle |
| **Swappiness** | 10 | Prioritaskan ZRAM, kurangi baca-tulis SD Card |

---

## Fitur Layanan

| # | Layanan | Akses | Container | Fungsi |
|---|---------|-------|-----------|--------|
| 1 | **Dashboard** | `http://IP:8080` | Python Flask (custom) | Monitor CPU, temperatur, RAM, ZRAM, SWAP, pemakaian SD Card, RX/TX jaringan secara real-time |
| 2 | **Blog** | `http://IP:8080/blog` | via Dashboard | Halaman catatan dan dokumentasi static |
| 3 | **FileBrowser** | `http://IP:8081` | `filebrowser/filebrowser` | Kelola, upload, download file via browser — folder: Document, Music, Pictures, Videos |
| 4 | **CCTV NVR** | `http://IP:8765` | `ccrisan/motioneye` | Rekaman kamera IP 24 jam. Detect motion, simpan otomatis ke `/storage/My Videos/NVR/` |
| 5 | **Terminal** | `http://IP:7681` | `tsl0922/ttyd` | Monitoring resource via BTOP langsung dari browser (login: admin / admin12345678) |
| 6 | **Cloudflare** | — | `cloudflare/cloudflared` | Tunnel — akses semua layanan dari luar tanpa IP publik |

Dashboard menyediakan **tombol navigasi** ke semua layanan, serta **pop-up donasi** yang menampilkan metode dukungan.

---

## Cara Install (Lengkap)

### Persiapan

1. STB B860H sudah terpasang **Armbian** dan boot dari SD Card
2. STB terhubung ke internet (via LAN)
3. Kamu punya akses **root** atau `sudo`

### Langkah 1: Clone repositori

Jalankan perintah berikut **di STB** (melalui SSH atau terminal langsung):

```bash
# Install git jika belum ada
apt-get update && apt-get install -y git

# Clone repositori
git clone https://github.com/username/my-home-server.git /opt/homeserver
cd /opt/homeserver
```

Atau jika ingin menggunakan versi yang sudah di-download:

```bash
# Copy folder dari komputer ke STB via SCP
scp -r homeserver root@192.168.x.x:/opt/
ssh root@192.168.x.x
cd /opt/homeserver
```

### Langkah 2: Jalankan installer

```bash
sudo bash scripts/install.sh
```

### Langkah 3: Ikuti proses instalasi

Installer akan bekerja secara otomatis. Berikut yang akan terjadi:

**Tahap 1 — Install Docker** (3-5 menit)
```
  [INFO]  Mengunduh script instalasi Docker...
  [INFO]  Menjalankan installer Docker...
  [ ✓ ]   Docker sudah terinstal (26.x.x)
```

Jika Docker sudah ada, tahap ini dilewati.

**Tahap 2 — Konfigurasi ZRAM, SWAP, Optimasi** (1-2 menit)
```
  [ ✓ ]   ZRAM 512M aktif prioritas tinggi
  [ ✓ ]   SWAP 1024MB aktif
  [ ✓ ]   Kernel parameters dioptimalkan
```

**Tahap 3 — Copy file project** (beberapa detik)
```
  [ ✓ ]   File project disalin ke /opt/homeserver
```

**Tahap 4 — Build & jalankan container** (5-10 menit, tergantung koneksi)
```
  [ ✓ ]   Membangun image dashboard (Flask)
  [ ✓ ]   Menarik image dari registry
  [ ✓ ]   User FileBrowser: admin / admin12345678
  [ ✓ ]   Menjalankan semua container
```

**Tahap 5 — Cloudflare Tunnel** (opsional, 2-3 menit)
```
  [?] Inginkan konfigurasi Cloudflare Tunnel? [y/N]:
```

Ketik `y` jika punya domain di Cloudflare.  
Masukkan domain, misal: `server.example.com`

```
  Masukkan domain Anda: server.example.com
  
  Browser akan terbuka. Login lalu pilih domain Anda.
  Tekan Enter setelah siap...
```

Setelah login, tunnel akan otomatis aktif.

**Tahap 6 — Status akhir**
```
  [RUNNING]  dashboard
  [RUNNING]  filebrowser
  [RUNNING]  motioneye
  [RUNNING]  cloudflared
  [RUNNING]  ttyd
```

### Langkah 4: Reboot

```bash
sudo reboot
```

### Langkah 5: Verifikasi setelah reboot

```bash
cd /opt/homeserver
docker compose ps
```

Semua service harus aktif. Jika ada yang merah, lanjut ke bagian [Troubleshooting](#troubleshooting).

---

## Pertama Kali Akses

Cari IP STB:

```bash
hostname -I
```

Buka browser di komputer/ponsel yang **satu jaringan** dengan STB:

| Layanan | Buka di Browser | Login |
|---------|----------------|-------|
| Dashboard | `http://192.168.x.x:8080` | — |
| Blog | `http://192.168.x.x:8080/blog` | — |
| FileBrowser | `http://192.168.x.x:8081` | `admin` / `admin12345678` |
| NVR CCTV | `http://192.168.x.x:8765` | Atur password saat pertama akses |
| Terminal | `http://192.168.x.x:7681` | `admin` / `admin12345678` |

> Ganti `192.168.x.x` dengan IP asli STB kamu.

### Akses dari luar (via Cloudflare)

Jika tunnel sudah aktif:
```
https://dashboard.server.example.com
https://files.server.example.com
https://nvr.server.example.com
https://status.server.example.com
```

---

## Struktur Folder

### Project (`/opt/homeserver/`)

```
/opt/homeserver/
├── docker-compose.yml           # ← Semua service dalam satu file
├── .env                         # Konfigurasi lingkungan (copy dari .env.example)
├── .env.example                 # Template .env
│
├── dashboard/                   # Custom container untuk monitoring
│   ├── Dockerfile               #   Build image Python + Flask
│   ├── app.py                   #   Backend monitoring (baca /proc, /sys dari host)
│   ├── requirements.txt         #   Dependencies Python
│   └── templates/index.html     #   Dashboard UI (HTML + CSS + JS)
│
├── blog/index.html              # Halaman blog static
│
├── configs/                     # Konfigurasi tiap service
│   ├── filebrowser.json         #   Konfigurasi FileBrowser
│   ├── filebrowser-data/        #   Database FileBrowser (auto-generated)
│   ├── cloudflared/             #   Credentials Cloudflare (auto-generated)
│   └── motioneye/               #   Konfigurasi motionEye
│       ├── motioneye.conf
│       └── camera-1.conf        #   Kamera IP 192.168.101.6
│
├── scripts/install.sh           # Installer (cukup jalankan sekali)
├── README.md                    # Dokumentasi ini
└── .gitignore
```

### Data (`/storage/`)

```
/storage/
├── My Document/         # Dokumen pribadi
├── My Music/            # Koleksi musik
├── My Pictures/         # Foto dan gambar
└── My Videos/
    └── NVR/             # Rekaman CCTV (otomatis dari motionEye)
```

---

## Manajemen Sehari-hari

Semua perintah dijalankan dari `/opt/homeserver/`:

```bash
cd /opt/homeserver
```

### Melihat status

```bash
docker compose ps
# NAME          STATUS         PORTS
# dashboard     Up 2 hours     0.0.0.0:8080->8080/tcp
# filebrowser   Up 2 hours     0.0.0.0:8081->80/tcp
# motioneye     Up 2 hours     0.0.0.0:8765->8765/tcp
# ttyd          Up 2 hours     0.0.0.0:7681->7681/tcp
# cloudflared   Up 2 hours
```

### Melihat log real-time

```bash
# Semua service
docker compose logs -f

# Satu service
docker compose logs -f dashboard
```

### Restart service

```bash
docker compose restart filebrowser
```

### Update semua image ke versi terbaru

```bash
docker compose pull
docker compose up -d
```

### Hentikan semua service

```bash
docker compose down
```

### Mulai lagi

```bash
docker compose up -d
```

### Hapus semua container + image (reset bersih)

```bash
docker compose down -v
docker system prune -a
```

---

## Cloudflare Tunnel

### Setup ulang

Jika belum di-setup saat instalasi, atau ingin ganti domain:

```bash
cd /opt/homeserver

# Login ke Cloudflare
docker compose run --rm cloudflared tunnel login

# Buat tunnel
docker compose run --rm cloudflared tunnel create homeserver

# Konfigurasi domain
# Edit configs/cloudflared/config.yml sesuai domain kamu
nano configs/cloudflared/config.yml
```

Contoh `config.yml`:
```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /home/nonroot/.cloudflared/YOUR_TUNNEL_ID.json
ingress:
  - hostname: dashboard.example.com
    service: http://dashboard:8080
  - hostname: files.example.com
    service: http://filebrowser:80
  - hostname: nvr.example.com
    service: http://motioneye:8765
  - hostname: status.example.com
    service: http://ttyd:7681
  - service: http_status:404
```

```bash
# Daftarkan DNS
docker compose run --rm cloudflared tunnel route dns homeserver dashboard.example.com
docker compose run --rm cloudflared tunnel route dns homeserver files.example.com
docker compose run --rm cloudflared tunnel route dns homeserver nvr.example.com
docker compose run --rm cloudflared tunnel route dns homeserver status.example.com

# Jalankan
docker compose up -d cloudflared
```

### Nonaktifkan Cloudflare

```bash
cd /opt/homeserver
docker compose stop cloudflared
docker compose rm cloudflared
```

Edit `docker-compose.yml`, hapus atau komen bagian `cloudflared`.

---

## Troubleshooting

### 1. Container crash loop

Cek log untuk tahu penyebabnya:

```bash
docker compose logs --tail=50 nama_service
```

Contoh output:
```
Error: /usr/bin/python3: No such file or directory
```

Itu artinya container gagal menemukan Python3 — kemungkinan image tidak cocok.  
Hapus image lama dan build ulang:

```bash
docker compose down
docker compose build --no-cache dashboard
docker compose up -d
```

### 2. MotionEye tidak bisa akses kamera

Pastikan kamera IP 192.168.101.6 bisa dijangkau dari STB:

```bash
ping 192.168.101.6
```

Jika tidak reachable, cek koneksi jaringan.  
Jika reachable, sesuaikan konfigurasi kamera:

```bash
nano /opt/homeserver/configs/motioneye/camera-1.conf
# Ubah netcam_url, netcam_user, netcam_pass sesuai kamera
docker compose restart motioneye
```

### 3. FileBrowser tidak bisa login

Database mungkin belum terinisialisasi. Jalankan ulang init:

```bash
docker compose run --rm filebrowser filebrowser config init --database=/database/filebrowser.db
docker compose run --rm filebrowser filebrowser users add admin admin12345678 --perm.admin --database=/database/filebrowser.db
```

### 4. Dashboard menampilkan "N/A" atau data kosong

Dashboard membaca /proc dan /sys dari host melalui volume mount.  
Pastikan volume mount di `docker-compose.yml` masih sesuai:

```yaml
volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/host/root:ro
```

Restart dashboard:

```bash
docker compose restart dashboard
```

### 5. Semua container mati setelah reboot

Docker daemon mungkin tidak auto-start:

```bash
systemctl enable docker
systemctl start docker
cd /opt/homeserver && docker compose up -d
```

### 6. "No space left on device" di SD Card

Hapus image Docker yang tidak dipakai:

```bash
docker system prune -a
```

Pindahkan data NVR lama atau hapus rekaman yang tidak perlu:

```bash
du -sh /storage/My\ Videos/NVR/
rm -rf /storage/My\ Videos/NVR/*.mp4
```

### 7. Perintah `docker compose` tidak ditemukan

```bash
# Install plugin
apt-get update && apt-get install -y docker-compose-plugin

# Atau pakai sintaks lama
docker-compose up -d
```

---

## Donasi

Proyek ini dikembangkan secara sukarela. Jika bermanfaat, dukungan Anda sangat berarti:

| Metode | Detail |
|--------|--------|
| **DANA** | `085323073037` (a.n. Budi Joko) |
| **Mandiri** | `1310014031126` (a.n. Budi Joko) |
| **BNI** | `2027537451` (a.n. Budi Joko) |
| **QRIS** | Scan via DANA (lihat gambar QR di Dashboard) |
| **Konfirmasi** | [Klik di sini](https://wa.me/6285323073037?text=Halo%20kak%2C%20saya%20mau%20konfirmasi%20donasi%20untuk%20My%20Home%20Server) |

Tombol donasi juga tersedia di Dashboard (pojok kanan navigasi).

---

## Lisensi

Proyek ini dilisensikan di bawah **MIT License** — bebas digunakan, dimodifikasi, dan didistribusikan untuk keperluan pribadi atau pembelajaran.

---

*Dibuat dengan penuh dedikasi untuk komunitas self-hosting Indonesia.*
