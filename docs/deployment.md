# Panduan Deployment GrokPi Lite - Production Ready

Panduan ini disusun secara komprehensif mulai dari nol (server baru), pengamanan dasar (hardening), hingga siap digunakan di tahap produksi dengan custom domain (HTTPS).

Untuk alur ringkas yang bisa diikuti langkah demi langkah, gunakan juga checklist terpisah:

- [Checklist Deployment Final ke VPS Ubuntu](deployment-checklist-ubuntu.md)

## 1. Persyaratan Server Minimal

GrokPi dibangun menggunakan bahasa Go yang sangat ringan dan tidak memerlukan banyak *resource*. Berikut adalah rekomendasi VPS (Virtual Private Server) yang Anda butuhkan:

*   **Operating System**: Ubuntu 22.04 LTS atau 24.04 LTS (Debian 12 juga didukung).
*   **CPU**: Minimal 1 vCPU.
*   **RAM**: Minimal 1 GB (Idealnya 2 GB).
*   **Storage**: 10 GB SSD.
*   **Akses**: IPv4 Publik.

---

## 2. Persiapan Server Dari Nol (Init & Hardening)

Saat pertama kali menyewa VPS, Anda biasanya akan mendapatkan kredensial login sebagai `root`. Menjalankan aplikasi langsung sebagai `root` sangat berbahaya. Ikuti langkah di bawah untuk menyiapkan fondasi yang aman.

### 2.1. Login Pertama & Update Sistem
Akses server menggunakan Terminal / PowerShell:
```bash
ssh root@IP_SERVER_ANDA
```
Segera perbarui sistem:
```bash
apt-get update && apt-get upgrade -y
```

### 2.2. Membuat User Baru
Kita akan menjalankan aplikasi menggunakan user standar dengan hak akses admin (sudo).
```bash
# Membuat user baru bernama "grokdeploy" (Anda bebas mengubah namanya)
adduser grokdeploy

# Menambahkan user ke dalam grup sudo agar bisa mengeksekusi perintah admin
usermod -aG sudo grokdeploy
```

### 2.3. Menambahkan Swap (Penting untuk RAM 1GB / 2GB)
Menambahkan Swap akan menyelamatkan server dari *crash/Out of Memory* saat ada lonjakan data.
```bash
# Membuat file swap sebesar 2GB
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Menjadikan swap permanen setiap server restart
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
```

### 2.4. Keamanan Dasar: UFW (Firewall)
Pastikan hanya port yang benar-benar kita gunakan (SSH, HTTP, HTTPS) yang bisa diakses dunia luar.
```bash
# Instal ufw jika belum ada (Ubuntu biasanya sudah bawaan)
apt-get install ufw -y

# Buka akses OpenSSH sebelum menyalakan firewall agar tidak terkunci!
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw deny 8080/tcp
ufw deny 8191/tcp

# Aktifkan firewall
ufw enable
```
Ketik `y` dan tekan Enter untuk mengaktifkan.

### 2.5. Switch ke User Baru
Tutup koneksi root atau *switch* langsung ke user yang baru Anda daftarkan:
```bash
su - grokdeploy
```
*(Seluruh langkah di bawah ini akan dijalankan sebagai user `grokdeploy`)*

---

## 3. Instalasi Dependensi (Docker & Go)

### 3.1. Install *Requirement Tools*
```bash
sudo apt-get install -y ca-certificates curl gnupg lsb-release git make
```

### 3.2. Install Docker & Docker Compose
GrokPi menggunakan Docker untuk mengkarantina dependensi (seperti proxy/flaresolverr jika digunakan).
```bash
# Tambahkan repo key Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Masukkan Docker ke sources.list
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
# Install Engine
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Masukkan user grokdeploy ke grup docker agar tidak perlu `sudo` saat docker-compose
sudo usermod -aG docker $USER
```
**PENTING**: *Logout* dan *Login* kembali ke server SSH via `ssh grokdeploy@IP_SERVER_ANDA` agar konfigurasi grup docker teraplikasi.

### 3.3. Install Golang 1.24+ (Untuk Build API)
```bash
sudo rm -rf /usr/local/go
curl -fsSL "https://go.dev/dl/go1.24.1.linux-amd64.tar.gz" -o /tmp/go.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```
Cek versi (pastikan muncul v1.24.x): `go version`.

---

## 4. Instalasi GrokPi Lite

Sekarang Anda sudah siap mengatur mesin inti.

### 4.1. Clone Repositori
```bash
# Pindah ke direktori utama user
cd ~
git clone https://github.com/startquick/GrokPi-Lite.git
cd GrokPi-Lite
```

### 4.2. Setup Konfigurasi `config.toml`
Salin template bawaan:
```bash
cp config.defaults.toml config.toml
nano config.toml
```
Pastikan Anda **mengganti** `app_key` dengan kata sandi admin yang aman dan sulit ditebak. *(Contoh: `app_key = "P4ssw0rd$S4ng@tKu4t!"`)*. Setelah diedit, save (Ctrl+O, Enter, Ctrl+X).

### 4.3. Build Golang & Jalankan Docker
Docker script pada repo kita membutuhkan file *binary* sistem Linux yang sudah dicompile, oleh karena itu *build* dahulu:

```bash
# 1. Kompilasi app Goken
make build

# 2. Buat folder database dan tetapkan hak ases agar docker write-able
mkdir -p data logs
sudo chown -R 1000:1000 data logs

# 3. Jalankan Kontainer (service hanya bind ke localhost)
docker compose up -d --build
```
Lakukan tes ringan apakah server berjalan di internal: `curl -s http://127.0.0.1:8080/health`.

---

## 5. Custom Domain (Reverse Proxy & SSL HTTPS)

Agar *client* dapat mengkoneksikan server Anda via SSL (`https://api.domainanda.com`), Anda dapat menggunakan Caddy Server. Caddy jauh lebih disarankan ketimbang NGINX karena akan secara *otomatis* menerbitkan dan merotasi sertifikat SSL secara gratis!

### 5.1. Persiapan Domain (A Record)
Masuk ke pengaturan Cloudflare / Provider DNS Domain Anda:
- Buat tipe **A Record** (Misal: `api.namadomain.com`)
- Target **IP Address**: Isi dengan IP VPS Anda.
- **PENTING JIKA PAKAI CLOUDFLARE**: Pastikan status awan/cloud berwarna abu-abu (*Proxy Status: DNS Only*) saat instalasi perdana Caddy.

### 5.2. Install Caddy Server
Jalankan satu-satu perintah di bawah ini:
```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install caddy
```

### 5.3. Hubungkan Caddy dengan GrokPi
Buka file Caddyfile bawaan sistem:
```bash
sudo nano /etc/caddy/Caddyfile
```
Kosongkan semua isi file tersebut (atau hapus yang tidak penting), dan masukkan blok kode di bawah ini. Ganti `api.namadomain.com` dengan domain Anda yang asli:

```text
api.namadomain.com {
    reverse_proxy 127.0.0.1:8080
}
```
Simpan file (Ctrl+O, Enter, Ctrl+X), lalu *restart* service:
```bash
sudo systemctl restart caddy
```
Caddy akan memakan waktu sekitar ~10 detik untuk memesan sertifikat dari Let's Encrypt / ZeroSSL.

Selamat! Server GrokPi Lite Anda kini live di public network via `https://api.namadomain.com`!

Catatan penting:
- `docker-compose.yml` hanya bind GrokPi ke `127.0.0.1:8080`, jadi akses publik harus melalui Caddy.
- FlareSolverr tidak dipublish ke host dan hanya tersedia di internal Docker network.
- Container akan gagal start jika `config.toml` belum dimount atau masih memakai `app_key` default.

---

## 6. Operasional Harian (Maintenance)

Seluruh token, api keys, dan quota Grok disimpan secara transparan di `/data/grokpi.db` dengan driver SQLite.

### 6.1. Pengaturan Token Admin (CLI via SSH)
Kapanpun Anda butuh menambah/menghapus token x.com, atau menerbitkan API Keys untuk user *client*, gunakan skrip bawaan:
```bash
cd ~/GrokPi-Lite
chmod +x ./scripts/linux/grokpi_admin.sh
./scripts/linux/grokpi_admin.sh
```

### 6.2. Cadangkan Database (Backup)
Melakukan backup sangat mudah, cukup gabungkan konfigurasi dan folder data menjadi satu archive:
```bash
cd ~/GrokPi-Lite
tar czf grokpi-backup-$(date +%F).tar.gz config.toml data/
```

### 6.3. Update Aplikasi Utama
Bila Anda mendapat notifikasi pembaruan di Github:
```bash
cd ~/GrokPi-Lite
git pull
make build
docker compose up -d --build
```
Jika Anda menyimpan perubahan lokal pada `config.toml` atau file deploy lain, backup dulu sebelum update dan selesaikan konflik Git secara manual. Hindari perintah destruktif yang membuang perubahan server.
