# WordPress Automation Scripts

Skrip otomasi sederhana untuk instalasi dan penghapusan WordPress di Linux dengan dukungan **Apache/Nginx** dan **MySQL/PostgreSQL**.

---

## 📋 Fitur

### 🔧 Script Instalasi (`install.sh`)
- ✅ Instalasi otomatis WordPress dengan konfigurasi lengkap  
- ✅ Pilihan web server: **Apache** atau **Nginx**  
- ✅ Pilihan database: **MySQL/MariaDB** atau **PostgreSQL**  
- ✅ Konfigurasi keamanan dasar (security headers, file permissions)  
- ✅ Instalasi **WP-CLI** untuk manajemen WordPress  
- ✅ Generate password otomatis yang aman  
- ✅ Konfigurasi virtual host/server block otomatis  
- ✅ Penyimpanan konfigurasi untuk keperluan `remove.sh`  

### 🧹 Script Penghapusan (`remove.sh`)
- ✅ Penghapusan lengkap instalasi WordPress  
- ✅ Backup otomatis sebelum penghapusan *(opsional)*  
- ✅ Penghapusan database dan user  
- ✅ Pembersihan konfigurasi web server  
- ✅ Penghapusan SSL certificate *(opsional)*  
- ✅ Mode interaktif untuk memilih site yang akan dihapus  
- ✅ Mode langsung dengan nama domain  

---

## 🛠️ Persyaratan Sistem

| Komponen     | Detail                              |
|--------------|-------------------------------------|
| **OS**       | Ubuntu 18.04+ atau Debian 9+        |
| **Hak Akses**| Root access                         |
| **Koneksi**  | Diperlukan untuk mengunduh paket    |
| **RAM**      | Minimal 512MB (disarankan 1GB+)     |
| **Storage**  | Minimal 1GB ruang kosong            |

---

## 📁 Struktur Direktori
automation/
├── install.sh # Script instalasi WordPress
├── remove.sh # Script penghapusan WordPress
└── README.md # Dokumentasi


---

## 🚀 Cara Penggunaan

### 📥 Instalasi WordPress

```bash
# Unduh script
wget https://raw.githubusercontent.com/your-repo/install.sh
chmod +x install.sh

# Jalankan sebagai root
sudo ./install.sh
