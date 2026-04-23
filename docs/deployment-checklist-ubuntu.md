# Checklist Deployment Final ke VPS Ubuntu

Dokumen ini adalah checklist praktis yang bisa diikuti langkah demi langkah untuk membawa GrokPi Lite dari repository lokal ke VPS Ubuntu yang siap dipakai di internet dengan reverse proxy HTTPS.

Gunakan checklist ini bersama panduan lengkap di `docs/deployment.md`.

## 1. Persiapan VPS

1. Login ke VPS sebagai `root`.
```bash
ssh root@IP_VPS
```

2. Update sistem.
```bash
apt-get update && apt-get upgrade -y
```

3. Buat user deploy non-root.
```bash
adduser grokdeploy
usermod -aG sudo grokdeploy
```

4. Pindah ke user deploy.
```bash
su - grokdeploy
```

## 2. Hardening Dasar

1. Install dan aktifkan UFW.
```bash
sudo apt-get install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 8080/tcp
sudo ufw deny 8191/tcp
sudo ufw enable
sudo ufw status
```

2. Pastikan hanya port `22`, `80`, dan `443` yang terbuka ke publik.

## 3. Install Dependensi

1. Install paket dasar.
```bash
sudo apt-get install -y ca-certificates curl gnupg lsb-release git make
```

2. Install Docker dan Docker Compose plugin.
```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

3. Logout lalu login ulang agar grup `docker` aktif.
```bash
exit
ssh grokdeploy@IP_VPS
docker --version
docker compose version
```

4. Install Go 1.24+ jika binary akan dibuild di VPS.
```bash
sudo rm -rf /usr/local/go
curl -fsSL "https://go.dev/dl/go1.24.1.linux-amd64.tar.gz" -o /tmp/go.tar.gz
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version
```

## 4. Ambil Source Code

1. Clone repository.
```bash
cd ~
git clone https://github.com/startquick/GrokPi-Lite.git
cd GrokPi-Lite
```

2. Verifikasi file penting ada.
```bash
ls
ls docs
ls scripts/linux
```

## 5. Siapkan Konfigurasi Produksi

1. Salin template config.
```bash
cp config.defaults.toml config.toml
```

2. Edit `config.toml`.
```bash
nano config.toml
```

3. Wajib pastikan hal berikut:
- `app.app_key` diganti dengan secret baru yang kuat
- `db_driver` dan `db_path` sesuai kebutuhan
- `proxy.*` diisi jika memang memakai FlareSolverr/proxy
- jangan memakai nilai default `QUICKstart012345+`

4. Siapkan direktori runtime.
```bash
mkdir -p data logs
sudo chown -R 1000:1000 data logs
```

## 6. Jalankan Container

1. Jalankan service (`--build` langsung trigger multi-stage build di dalam Docker).
```bash
docker compose up -d --build
```

3. Cek status container.
```bash
docker compose ps
docker compose logs --tail=100 grokpi
docker compose logs --tail=100 flaresolverr
```

4. Cek health internal.
```bash
curl -s http://127.0.0.1:8080/health
```

## 7. Verifikasi Network Exposure

1. Pastikan backend hanya bind localhost.
```bash
ss -tulpn | grep 8080
```

2. Pastikan FlareSolverr tidak dipublish ke host.
```bash
ss -tulpn | grep 8191
```

Ekspektasi:
- `8080` hanya muncul di `127.0.0.1`
- `8191` tidak muncul sebagai port host publik

## 8. Setup Reverse Proxy HTTPS dengan Caddy

1. Install Caddy.
```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
```

2. Arahkan domain ke IP VPS di DNS provider.

3. Edit Caddyfile.
```bash
sudo nano /etc/caddy/Caddyfile
```

4. Isi minimal:
```text
api.domainanda.com {
    reverse_proxy 127.0.0.1:8080
}
```

5. Restart dan cek Caddy.
```bash
sudo systemctl restart caddy
sudo systemctl status caddy --no-pager
curl -I https://api.domainanda.com/health
```

## 9. Konfigurasi Admin dan API Key

### Opsi A: Admin UI via Browser (Direkomendasikan)

GrokPi menyediakan halaman admin berbasis web yang built-in. Setelah Caddy aktif, buka browser dan akses:

```
https://api.domainanda.com/admin/access
```

Atau jika belum ada domain (akses langsung dari VPS):

```
http://127.0.0.1:8080/admin/access
```

Login dengan `app_key` yang sudah kamu set di `config.toml`. Dari dashboard ini kamu bisa:
- **Tokens** — import, lihat status, hapus, dan refresh token Grok SSO
- **API Keys** — buat dan kelola client key `sk-...`
- **Stats** — lihat quota, usage log, dan token pool
- **Config** — edit runtime config tanpa restart
- **Cache** — kelola cache file video/image

> [!NOTE]
> Admin UI di-*embed* langsung ke dalam binary, sehingga tersedia otomatis tanpa setup tambahan.

### Opsi B: CLI Script (via SSH)

1. Jalankan admin script.
```bash
cd ~/GrokPi-Lite
chmod +x ./scripts/linux/grokpi_admin.sh
./scripts/linux/grokpi_admin.sh
```

2. Lakukan langkah berikut:
- login admin dengan `app_key`
- import token Grok SSO
- buat API key client `sk-...`

## 10. Smoke Test API

1. Test daftar model.
```bash
curl -s https://api.domainanda.com/v1/models \
  -H "Authorization: Bearer API_KEY_ANDA"
```

2. Test endpoint OpenAI-compatible.
```bash
curl -s https://api.domainanda.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer API_KEY_ANDA" \
  -d '{
    "model": "grok-4.1-fast",
    "messages": [{"role":"user","content":"Halo dari VPS"}]
  }'
```

3. Test endpoint Anthropic-compatible.
```bash
curl -s https://api.domainanda.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: API_KEY_ANDA" \
  -d '{
    "model": "grok-4.1-fast",
    "max_tokens": 256,
    "messages": [{"role":"user","content":"Halo dari endpoint messages"}]
  }'
```

## 11. Post-Deploy Smoke Test

Setelah container, reverse proxy, dan admin key siap, jalankan smoke test ringkas ini dari VPS. Ganti `APP_KEY` dan `API_KEY_ANDA` dengan nilai yang benar.

```bash
APP_KEY='app-key-admin-anda'
API_KEY='sk-anda'
BASE_URL='http://127.0.0.1:8080'

curl -fsS "$BASE_URL/health"
curl -fsS "$BASE_URL/admin/verify" -H "Authorization: Bearer $APP_KEY"
curl -fsS "$BASE_URL/v1/models" -H "Authorization: Bearer $API_KEY"
curl -fsS "$BASE_URL/admin/tokens?page_size=10" -H "Authorization: Bearer $APP_KEY"
```

Alternatif kalau `make` tersedia di VPS:

```bash
make smoke BASE_URL=http://127.0.0.1:8080 APP_KEY="$APP_KEY" API_KEY="$API_KEY"
```

Ekspektasi:
- `/health` mengembalikan status `ok`
- `/admin/verify` mengembalikan `{"status":"ok"}`
- `/v1/models` mengembalikan daftar model
- `/admin/tokens` mengembalikan daftar token admin tanpa error auth

## 12. Backup Awal

Setelah sistem sehat, buat backup awal.
```bash
cd ~/GrokPi-Lite
tar czf grokpi-backup-$(date +%F).tar.gz config.toml data/
```

## 13. Checklist Final Sebelum Dianggap Live

- `app_key` bukan default
- `docker compose ps` menunjukkan service sehat
- `curl http://127.0.0.1:8080/health` sukses di VPS
- `curl -I https://domain/health` sukses dari luar
- port `8080` tidak terbuka publik
- port `8191` tidak terbuka publik
- admin script bisa login
- `/v1/chat/completions` berhasil
- `/v1/messages` berhasil
- backup awal sudah dibuat

## 14. Update Aman Setelah Live

Gunakan alur update yang tidak destruktif:
```bash
cd ~/GrokPi-Lite
git pull
docker compose build --no-cache grokpi
docker compose up -d
```

Opsi `--no-cache` memastikan image Docker membuang state lama dan membungkus ulang pembaruan file terbaru (termasuk komponen frontend/UI). Anda tidak perlu menjalankan `make build` manual karena semuanya dikompilasi (otomatis rebuild) dengan kode terbaru di dalam container.

Jika ada perubahan lokal penting pada `config.toml` atau file deploy lain, backup dulu dan selesaikan konflik Git secara manual.
