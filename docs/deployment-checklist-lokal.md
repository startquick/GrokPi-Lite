# Deployment Checklist Lokal (Windows/PowerShell)

Panduan ini menggunakan **Docker sebagai metode utama** — konsisten dengan deployment VPS.
Tidak perlu Go toolchain di Windows; semua build terjadi di dalam container.

---

## Setup Awal (Sekali Saja)

**1. Masuk ke folder project**

```powershell
cd "E:\GrokPi Lite"
```

**2. Siapkan config lokal**

Salin template default:

```powershell
Copy-Item .\config.defaults.toml .\config.toml
```

Edit `config.toml`, minimal ubah bagian ini:

```toml
[app]
app_key = "ganti-dengan-key-admin-sendiri"  # WAJIB diubah dari default
host = "0.0.0.0"
port = 8080
```

> [!IMPORTANT]
> **Jangan biarkan `app_key` tetap `QUICKstart012345+`** — container akan menolak start jika masih memakai nilai default ini.

**3. Siapkan file `.env` lokal**

Buat file `.env` di root project (jika belum ada):

```powershell
@"
COMPOSE_FILE=docker-compose.yml:docker-compose.local.yml
"@ | Set-Content .\.env
```

File ini memberitahu Docker Compose untuk menggabungkan kedua file compose secara otomatis,
sehingga kamu **tidak perlu menulis `-f` flags** setiap kali.

> [!NOTE]
> File `.env` dan `docker-compose.local.yml` ada di `.gitignore` — tidak akan ikut di-commit.

**4. Buat direktori runtime**

```powershell
New-Item -ItemType Directory -Force -Path .\data, .\logs
```

---

## Menjalankan Service

**5. Jalankan service (perintah utama)**

```powershell
docker compose up -d --build
```

Atau via Makefile:

```powershell
make docker-up
```

Perintah ini akan:
- Build binary Go di dalam container (tidak perlu Go di Windows)
- Menjalankan FlareSolverr dan GrokPi sebagai service teregistrasi
- Semua service berjalan di background (`-d`)

**6. Cek status service**

```powershell
docker compose ps
# atau
make docker-ps
```

Ekspektasi: kedua service (`flaresolverr` dan `grokpi`) menunjukkan status `healthy`.

**7. Cek health endpoint**

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

**8. Lihat log realtime**

```powershell
docker compose logs -f grokpi
# atau
make docker-logs
```

---

## Admin & Token Management

**9. Akses Admin UI (via browser)**

GrokPi menyediakan halaman admin berbasis web yang built-in. Setelah service berjalan, buka browser dan akses:

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
> Admin UI di-*embed* langsung ke dalam binary, sehingga tersedia otomatis tanpa perlu setup tambahan.

**10. Alternatif: CLI script (tanpa browser)**

Sesuai aturan arsitektur repo ini, jangan kelola admin dengan `curl` manual. Pakai script interaktif Windows:

```powershell
.\scripts\windows\grokpi_admin.ps1
```

Dari situ biasanya alurnya:
- Login pakai `app_key` yang telah dibuat di langkah 2
- Import token Grok SSO
- Buat client API key dengan awalan `sk-...`
- Lihat stats/token status

---

## Menggunakan API

**11. Test endpoint secara lokal**

```powershell
$headers = @{
  Authorization = "Bearer sk-xxxxx"
  "Content-Type" = "application/json"
}

$body = @{
  model = "grok-4.1-fast"
  messages = @(
    @{ role = "user"; content = "Halo, jawab singkat." }
  )
  stream = $false
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Uri "http://127.0.0.1:8080/v1/chat/completions" `
  -Method Post `
  -Headers $headers `
  -Body $body
```

Test endpoint Anthropic-compatible:

```powershell
$headers = @{
  "x-api-key" = "sk-xxxxx"
  "Content-Type" = "application/json"
}

$body = @{
  model = "grok-4.1-fast"
  messages = @(
    @{ role = "user"; content = "Halo dari endpoint messages." }
  )
  max_tokens = 256
  stream = $false
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Uri "http://127.0.0.1:8080/v1/messages" `
  -Method Post `
  -Headers $headers `
  -Body $body
```

Lihat model list:

```powershell
Invoke-RestMethod `
  -Uri "http://127.0.0.1:8080/v1/models" `
  -Headers @{ Authorization = "Bearer sk-xxxxx" }
```

---

## Update Kode

**11. Update setelah ada perubahan kode**

```powershell
git pull
docker compose up -d --build
# atau
make docker-up
```

Perintah `--build` akan rebuild image secara otomatis. Tidak perlu `make build` manual.

---

## Perintah Docker yang Berguna

| Perintah | Keterangan |
|---|---|
| `make docker-up` | Jalankan semua service (build + start) |
| `make docker-down` | Hentikan dan hapus semua container |
| `make docker-logs` | Ikuti log GrokPi secara realtime |
| `make docker-ps` | Lihat status semua container |
| `make docker-restart` | Restart container GrokPi saja |
| `make docker-shell` | Masuk ke shell dalam container GrokPi |

---

## Hal yang Jangan Dilakukan

> [!CAUTION]
> - Jangan jalankan `make clean` sembarangan — akan menghapus folder database `data/`.
> - Jangan kelola token admin dan API Key menggunakan perintah manual `curl`; selalu gunakan `./scripts/windows/grokpi_admin.ps1` atau Admin UI browser.
> - Jangan edit `docker-compose.yml` untuk kebutuhan lokal saja — gunakan `docker-compose.local.yml` sebagai override.
> - **Jangan jalankan service dengan `make run`, `make dev`, atau `./bin/grokpi.exe` langsung** — Docker adalah satu-satunya metode deployment yang didukung. Cara native binary hanya untuk keperluan pengembangan Go tingkat lanjut.
