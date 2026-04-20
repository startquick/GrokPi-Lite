# Grokpi — Panduan Self-Hosted

Grokpi adalah gateway OpenAI-compatible untuk beban kerja chat, gambar, dan video menggunakan Grok.
Panduan ini berfokus pada self-hosting di server atau VPS milik sendiri.

## 1. Fitur Utama

- Endpoint Dual-Format: Mendukung protokol **OpenAI-compatible** (`/v1/chat/completions`) dan **Anthropic-compatible** (`/v1/messages`).
- Endpoint Admin API untuk token pool, API key, riwayat penggunaan, pengaturan, dan cache
- Binary Go tunggal API-only (Headless) tanpa beban resource Frontend/UI
- Mekanisme pintar pemulihan Cloudflare (*CF Challenge Bypass*) dengan *circuit breaker* otomatis
- Peringatan proaktif status upstream xAI via notifikasi Telegram Webhook
- SQLite sebagai default, PostgreSQL sebagai opsi
- Dukungan deployment via Docker Compose

## 2. Kebutuhan Sistem & Deployment

Panduan lengkap mengenai spesifikasi VPS, instalasi dependensi (Docker, Go, Make), hingga perintah eksekusi dan *deployment* kini tersedia di dokumen terpisah agar lebih rapi.

Checklist praktis Ubuntu VPS juga tersedia di:

`docs/deployment-checklist-ubuntu.md`

👉 **[Baca Panduan Deployment Lengkap di Sini](docs/deployment.md)**



## 5. Konfigurasi Awal via Admin API (Headless)

Karena versi ini tidak memiliki UI (Web Panel), semua manajemen dilakukan via API Console.

Kami telah menyediakan script interaktif untuk mempermudah konfigurasi awal tanpa perlu mengingat perintah *curl*.

**Untuk pengguna Windows:**
Buka PowerShell, masuk ke direktori proyek, lalu jalankan:
```powershell
.\scripts\windows\grokpi_admin.ps1
```

**Untuk pengguna Linux / macOS:**
Buka terminal, masuk ke direktori proyek, berikan izin eksekusi jika perlu, lalu jalankan:
```bash
chmod +x ./scripts/linux/grokpi_admin.sh
./scripts/linux/grokpi_admin.sh
```

Menu interaktif akan muncul. Ikuti instruksi di layar untuk:
1. Menambahkan Token Upstream Grok (Anda bisa menempelkan banyak set token sekaligus dipisah dengan koma).
2. Membuat API Key (Gunakan ini di App seperti AnythingLLM/Dify Anda).

*API Key inilah yang nanti akan dipakai untuk request ke endpoint `/v1/chat/completions` atau didaftarkan pada LLM Apps seperti AnythingLLM, Dify, dll.*

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
# Opsional - Peringkat Cloudflare Gagal
telegram_bot_token = ""
telegram_chat_id = ""
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

### 7.3 Chat Completion (Format Anthropic / Claude)

```bash
curl -s http://127.0.0.1:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: API_KEY_ANDA" \
  -d '{
    "model": "grok-3",
    "max_tokens": 1024,
    "system": "Anda adalah asisten cerdas.",
    "messages": [
      {"role": "user", "content": "Halo dari Grokpi dengan format Anthropic API"}
    ]
  }'
```

### 7.4 Generasi Gambar

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

### 7.5 Generasi Video

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

