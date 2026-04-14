# Grokpi — Panduan Self-Hosted

Grokpi adalah gateway OpenAI-compatible untuk beban kerja chat, gambar, dan video menggunakan Grok.
Panduan ini berfokus pada self-hosting di server atau VPS milik sendiri.

## 1. Fitur Utama

- Endpoint OpenAI-compatible (`/v1/models`, `/v1/chat/completions`)
- Admin console untuk token pool, API key, riwayat penggunaan, pengaturan, dan cache
- Binary Go tunggal dengan web app yang sudah tertanam (embedded)
- SQLite sebagai default, PostgreSQL sebagai opsi
- Dukungan deployment via Docker Compose

## 2. Kebutuhan Sistem

- Server atau VPS Linux (Ubuntu 22.04+ direkomendasikan)
- Docker + Docker Compose plugin
- Go 1.24+ dan Node.js 22+ (diperlukan untuk build `bin/grokpi` dari `Dockerfile.local`)
- `make` (opsional tapi direkomendasikan)
- Minimal 2 vCPU / 2 GB RAM untuk penggunaan ringan
- Port terbuka: `8080` (atau gunakan reverse-proxy ke 80/443)

Opsional:

- Domain name + sertifikat TLS
- FlareSolverr dan konfigurasi proxy (hanya jika rute upstream memerlukannya)

### 2.1 Instalasi Lengkap (Ubuntu 22.04/24.04)

Jalankan langkah-langkah berikut jika Anda baru pertama kali setup server.

1. Perbarui paket sistem:

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

2. Instal alat dasar:

```bash
sudo apt-get install -y ca-certificates curl gnupg lsb-release git make
```

3. Instal Docker Engine + Docker Compose plugin (dari repo resmi Docker):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

4. (Direkomendasikan) Izinkan user saat ini menjalankan Docker tanpa `sudo`:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

5. Instal Node.js 22 LTS:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

6. Instal Go (sesuaikan dengan versi di `go.mod`, saat ini 1.24.1+):

```bash
GO_VERSION="1.24.1"
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin
```

7. Verifikasi semua alat sudah terinstal:

```bash
docker --version
docker compose version
node --version
npm --version
go version
make --version
```

Jika Docker masih memerlukan `sudo` setelah langkah 4, logout lalu login kembali.

### 2.2 Instalasi Lengkap (Debian 12)

Gunakan bagian ini jika server Anda menjalankan Debian 12 (bookworm).

1. Perbarui paket sistem:

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

2. Instal alat dasar:

```bash
sudo apt-get install -y ca-certificates curl gnupg lsb-release git make
```

3. Instal Docker Engine + Docker Compose plugin (dari repo resmi Docker):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

4. (Direkomendasikan) Izinkan user saat ini menjalankan Docker tanpa `sudo`:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

5. Instal Node.js 22 LTS:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

6. Instal Go (sesuaikan dengan versi di `go.mod`, saat ini 1.24.1+):

```bash
GO_VERSION="1.24.1"
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin
```

7. Verifikasi semua alat sudah terinstal:

```bash
docker --version
docker compose version
node --version
npm --version
go version
make --version
```

Jika Docker masih memerlukan `sudo` setelah langkah 4, logout lalu login kembali.

## 3. Clone Project dari GitHub ke VPS

Langkah ini dilakukan **sekali** saat pertama kali setup VPS.

### 3.1 Buat SSH Key di VPS (jika belum ada)

```bash
ssh-keygen -t ed25519 -C "email@anda.com"
# Tekan Enter untuk semua prompt (atau isi passphrase jika diinginkan)
cat ~/.ssh/id_ed25519.pub
```

Salin output public key tersebut, lalu tambahkan ke GitHub:
**GitHub → Settings → SSH and GPG keys → New SSH key**

### 3.2 Clone Repository

Setelah SSH key ditambahkan, jalankan perintah berikut:

```bash
# Buat direktori kerja
mkdir -p ~/apps
cd ~/apps

# Clone via SSH (direkomendasikan untuk repo private)
git clone git@github.com:startquick/groki-unlimited.git grokpi
cd grokpi
```

Atau jika menggunakan HTTPS (memerlukan Personal Access Token untuk repo private):

```bash
# Buat Personal Access Token di: GitHub → Settings → Developer settings → Personal access tokens
git clone https://github.com/startquick/groki-unlimited.git grokpi
cd grokpi
# Masukkan username dan token saat diminta
```

### 3.3 Verifikasi Clone Berhasil

```bash
ls -la
git log --oneline -3
```

Setelah clone berhasil, lanjut ke bagian berikutnya untuk build dan deploy.

## 4. Menjalankan dengan Docker Compose

```bash
cd grokpi
cp config.defaults.toml config.toml
# Ubah app_key di config.toml dengan password admin yang kuat

# Build binary yang dibutuhkan Dockerfile.local (COPY bin/grokpi ...)
# Pilihan A (direkomendasikan):
make build
# Pilihan B (jika make tidak tersedia):
# cd web && npm ci && npm run build && cd ..
# go build -o bin/grokpi ./cmd/grokpi

# Pastikan direktori yang di-mount bisa ditulis oleh user container (uid 1000)
mkdir -p data logs
sudo chown -R 1000:1000 data logs

docker compose up -d --build
curl -s http://127.0.0.1:8080/health
```

Buka browser dan akses:

- `http://IP_SERVER_ANDA:8080/login`

## 5. Konfigurasi Awal di Admin Console

1. Login menggunakan `app_key`.
2. Tambahkan upstream token di menu Token Management.
3. Buat API key di menu API Keys.
4. Coba panggil `/v1/models` menggunakan API key yang baru dibuat.
5. Uji permintaan chat, gambar, dan video.

## 6. Contoh Konfigurasi Minimal

```toml
[app]
app_key = "GANTI_DENGAN_PASSWORD_KUAT"
host = "0.0.0.0"
port = 8080

db_driver = "sqlite"
db_path = "data/grokpi.db"

log_level = "info"
log_json = false

[proxy]
base_proxy_url = ""
asset_proxy_url = ""
enabled = false
```

Catatan penting:

- `app_key` yang kosong akan memblokir akses admin.
- Jangan bagikan file `config.toml` ke publik.
- Untuk deployment publik, gunakan reverse proxy dengan TLS.

## 7. Contoh Penggunaan API

### 7.1 Daftar Model

```bash
curl -s http://127.0.0.1:8080/v1/models \
  -H "Authorization: Bearer API_KEY_ANDA"
```

### 7.2 Chat Completion

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer API_KEY_ANDA" \
  -d '{
    "model": "grok-3-mini",
    "messages": [
      {"role": "user", "content": "Halo dari Grokpi self-hosted"}
    ]
  }'
```

### 7.3 Generasi Gambar

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer API_KEY_ANDA" \
  -d '{
    "model": "grok-imagine-1.0",
    "messages": [
      {"role":"user","content":"Danau pegunungan saat matahari terbit"}
    ],
    "image_config": {
      "aspect_ratio": "16:9"
    }
  }'
```

### 7.4 Generasi Video

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer API_KEY_ANDA" \
  -d '{
    "model": "grok-imagine-1.0-video",
    "messages": [
      {"role":"user","content":"Pengambilan gambar drone sinematik di atas sawah hijau"}
    ],
    "video_config": {
      "aspect_ratio": "16:9",
      "video_length": 8,
      "resolution_name": "480p",
      "preset": "normal"
    }
  }'
```

## 8. Checklist Produksi VPS

- Gunakan reverse proxy (Nginx/Caddy/Traefik) di depan Grokpi
- Aktifkan HTTPS (Let's Encrypt)
- Batasi akses ke endpoint admin jika memungkinkan
- Rotasi API key secara berkala
- Backup direktori `data/` dan file `config.toml`
- Pantau log container dan atur restart policy

## 9. Konfigurasi Reverse Proxy dengan Domain

Grokpi berjalan di `127.0.0.1:8080`. Agar bisa diakses via domain dengan HTTPS, gunakan reverse proxy di depannya.

### 9.1 Menggunakan Nginx

1. Instal Nginx dan Certbot:

```bash
sudo apt-get install -y nginx certbot python3-certbot-nginx
```

2. Buat file konfigurasi Nginx:

```bash
sudo nano /etc/nginx/sites-available/grokpi
```

Isi dengan konfigurasi berikut (ganti `api.domainanda.com`):

```nginx
server {
    listen 80;
    server_name api.domainanda.com;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```

3. Aktifkan konfigurasi dan muat ulang Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/grokpi /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

4. Pasang sertifikat TLS otomatis dengan Let's Encrypt:

```bash
sudo certbot --nginx -d api.domainanda.com
```

Certbot akan otomatis memperbarui konfigurasi Nginx dengan HTTPS. Setelah selesai, Grokpi dapat diakses via `https://api.domainanda.com`.

### 9.2 Menggunakan Caddy (lebih mudah)

Caddy menangani TLS secara otomatis tanpa perlu Certbot.

1. Instal Caddy:

```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install caddy
```

2. Edit Caddyfile:

```bash
sudo nano /etc/caddy/Caddyfile
```

Isi dengan konfigurasi berikut (ganti `api.domainanda.com`):

```caddyfile
api.domainanda.com {
    reverse_proxy 127.0.0.1:8080 {
        header_up X-Real-IP {remote_host}
        transport http {
            read_buffer  4096
        }
    }
    # Perpanjang timeout untuk streaming dan video
    request_body {
        max_size 20MB
    }
    timeouts {
        read_body   30s
        read_header 10s
        write        5m
        idle         5m
    }
}
```

3. Muat ulang Caddy:

```bash
sudo systemctl reload caddy
```

Caddy akan otomatis mendapatkan dan memperbarui sertifikat TLS dari Let's Encrypt. Tidak perlu konfigurasi tambahan.

### 9.3 Verifikasi

```bash
# Pastikan Grokpi merespons via domain
curl -s https://api.domainanda.com/health

# Cek sertifikat TLS
curl -sv https://api.domainanda.com/health 2>&1 | grep -E 'SSL|subject|expire'
```

## 10. Memperbarui Grokpi

```bash
git pull
# Tinjau perubahan config.defaults.toml jika ada

# Build ulang binary setelah pembaruan kode
make build
# atau jalankan perintah build manual dari bagian 4


docker compose up -d --build
curl -s http://127.0.0.1:8080/health
```

## 11. Backup dan Restore

Backup:

```bash
tar czf grokpi-backup-$(date +%F).tar.gz config.toml data/
```

Restore:

```bash
tar xzf grokpi-backup-YYYY-MM-DD.tar.gz
# Lalu restart container
docker compose up -d --build
```

## 12. Masalah Umum

- `failed to solve ... "/bin/grokpi": not found` saat `docker compose up --build`:
  - Build binary terlebih dahulu (`make build` atau perintah manual di bagian 4).
- `failed to open database ... sqlite ... out of memory (14)` di log container:
  - Biasanya masalah permission volume. Jalankan `mkdir -p data logs && sudo chown -R 1000:1000 data logs`.
- `401` saat login admin:
  - Periksa nilai `app_key` di `config.toml`.
- `401 invalid_api_key` pada `/v1/*`:
  - Gunakan API key dari Admin → API Keys, bukan password admin.
- Tidak ada model yang tersedia:
  - Tambahkan dan aktifkan upstream token yang valid.
- Port `8080` sudah digunakan:
  - Hentikan container/proses lama atau ubah port mapping.

---

Panduan langkah demi langkah yang lebih detail (Ubuntu + Nginx + TLS + systemd + jadwal backup otomatis) dapat ditambahkan jika diperlukan.
