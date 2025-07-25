Simple WordPress Automation Scripts
Skrip otomasi sederhana untuk instalasi dan penghapusan WordPress di Linux dengan dukungan Apache/Nginx dan MySQL/PostgreSQL.
📋 Fitur
Script Instalasi (install.sh)

✅ Instalasi otomatis WordPress dengan konfigurasi lengkap
✅ Pilihan web server: Apache atau Nginx
✅ Pilihan database: MySQL/MariaDB atau PostgreSQL
✅ Konfigurasi keamanan dasar (security headers, file permissions)
✅ Instalasi WP-CLI untuk manajemen WordPress
✅ Generate password otomatis yang aman
✅ Konfigurasi virtual host/server block otomatis
✅ Penyimpanan konfigurasi untuk removal nantinya

Script Removal (remove.sh)

✅ Penghapusan lengkap instalasi WordPress
✅ Backup otomatis sebelum penghapusan (opsional)
✅ Penghapusan database dan user
✅ Pembersihan konfigurasi web server
✅ Penghapusan SSL certificate (opsional)
✅ Mode interaktif untuk memilih site yang akan dihapus
✅ Mode direct dengan nama domain

🛠️ Persyaratan Sistem

OS: Ubuntu 18.04+ atau Debian 9+
Privileges: Root access
Koneksi: Internet untuk download paket dan WordPress
RAM: Minimal 512MB (direkomendasikan 1GB+)
Storage: Minimal 1GB ruang kosong

📁 Struktur Direktori
automation/
├── install.sh          # Script instalasi WordPress
├── remove.sh           # Script penghapusan WordPress
└── README.md           # Dokumentasi ini
🚀 Cara Penggunaan
Instalasi WordPress
bash# Download script
wget https://raw.githubusercontent.com/your-repo/install.sh
chmod +x install.sh

# Jalankan sebagai root
sudo ./install.sh
Proses Instalasi:

Input Konfigurasi: Script akan menanyakan:

Nama domain (contoh: example.com)
Pilihan web server (Apache/Nginx)
Pilihan database (MySQL/PostgreSQL)
Kredensial database (auto-generate atau manual)
Kredensial admin WordPress (auto-generate atau manual)
Path instalasi (default: /var/www/domain)


Proses Otomatis: Script akan:

Update sistem dan install paket yang diperlukan
Konfigurasi web server dan database
Download dan setup WordPress
Konfigurasi keamanan dasar
Install dan konfigurasi WP-CLI
Selesaikan instalasi WordPress


Output: Setelah selesai, Anda akan mendapat:

URL situs dan admin panel
Username dan password admin
Informasi database
Lokasi file konfigurasi



Penghapusan WordPress
Mode Interaktif (Rekomendasi)
bashsudo ./remove.sh
Mode Direct (dengan nama domain)
bashsudo ./remove.sh example.com
Proses Penghapusan:

Pilih Site: Dalam mode interaktif, pilih site yang akan dihapus
Konfirmasi: Ketik 'DELETE' untuk konfirmasi
Backup: Pilih apakah ingin backup sebelum penghapusan
Penghapusan: Script akan menghapus:

File WordPress
Database dan user
Konfigurasi web server
SSL certificate (opsional)
Log files dan cron jobs
File konfigurasi