## Budijoi Home Server V2.0 Stable
```
Part 1
├── Root Check
├── Armbian Check
├── Logging
├── Error Handler
├── System Update
├── Detect Root Filesystem
├── Detect Available Storage
├── User Select Storage
├── Minimum Storage Check (8 GB)
├── Filesystem Detection
├── Format Confirmation
├── Mount /mnt/storage
├── Backup /etc/fstab
├── Create Folder Structure
└── Generate README.txt
```

## Struktur Storage Final
```
/mnt/storage
│
├── web
│   ├── index.php
│   ├── assets
│   └── uploads
│
├── backup
│
├── My Documents
├── My Music
├── My Pictures
├── My Videos
│
├── README.txt
└── swapfile
```

## Standar Kualitas V2

* ✅ Support Storage :
  * SD Card.
  * USB Flashdisk.
  * USB SSD.
  * USB HDD.
* ✅ Menampilkan semua storage yang tersedia.
* ✅ User memilih storage sendiri.
* ✅ Tidak pernah memformat storage tanpa konfirmasi.
* ✅ Backup fstab sebelum modifikasi.
* ✅ Validasi mount berhasil.
* ✅ Logging ke :
`/root/budijoi-install.log`

```
Part 2
├── Swap Configuration
├── Swap Recommendation
├── Create Swapfile
├── ZRAM Installation
├── ZRAM Configuration
├── vm.swappiness=10
├── vm.vfs_cache_pressure=50
├── Journald Limit
└── Validation
```

Output nanti kira-kira:
```
====================================
 SWAP CONFIGURATION
====================================

Storage Size : 32 GB
Recommended : 1 GB

1) 512 MB
2) 1 GB
3) 2 GB

Select:
```
Kalau semua berjalan lancar:
```
✓ Swapfile Created
✓ ZRAM Enabled
✓ System Optimized
```
## Roadmap

✅ Part 1 (Locked Design)
```
Root Check
Armbian Check
Logging
Error Handler
System Update
Detect Root Filesystem
Detect Available Storage
User Select Storage
Minimum Storage Check (8 GB)
Filesystem Detection
Format Confirmation
Mount /mnt/storage
Backup fstab
Create Folder Structure
Generate README.txt
```
🔜 Part 2
```
Swap Recommendation
Swap Selection
Create Swapfile
Install ZRAM
Configure ZRAM
vm.swappiness=10
vm.vfs_cache_pressure=50
Journald Limit 100MB
Validation
```
🔜 Part 3
```
Install NGINX
Install PHP-FPM
Install MariaDB
Configure Web Root
Permissions
```
🔜 Part 4
```
Install FileBrowser
Configure Service
Create Admin User
Point Root ke /mnt/storage
```
🔜 Part 5
```
Install UFW
Install Fail2Ban
Firewall Rules
```
🔜 Part 6
```
Deploy Dashboard
Final Summary
Show Local IP
Show Login Credentials
```

## Target Akhir
```
Dashboard:
http://192.168.x.x

FileBrowser:
http://192.168.x.x:8080

Storage:
/mnt/storage

Web Root:
/mnt/storage/web

Username:
admin

Password:
admin12345678
```

