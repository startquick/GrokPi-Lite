# Deployment Checklist Lokal (Windows/PowerShell)

Untuk pakai GrokPi ini di lokal lewat PowerShell, ikuti urutan ini.

**1. Masuk ke folder project**

```powershell
cd "E:\GrokPi Lite"
```

**2. Siapkan config lokal**

Kalau belum punya `config.toml`, buat dari template:

```powershell
Copy-Item .\config.defaults.toml .\config.toml
```

Lalu edit `config.toml` dan minimal ubah bagian ini:

```toml
[app]
app_key = "ganti-dengan-key-admin-sendiri"
host = "127.0.0.1"
port = 8080
```

Yang biasanya perlu kamu isi juga:
- token Grok/SSO nanti di-import lewat admin script
- `proxy.*` kalau kamu memang pakai proxy / FlareSolverr
- `db_driver = "sqlite"` sudah aman untuk lokal

> [!IMPORTANT]
> **Catatan penting:**
> - jangan biarkan `app_key` tetap default
> - config runtime bisa dioverride melalui DB, jadi kalau ada setting terasa “tidak berubah”, kemungkinan sudah tersimpan di konfigurasi admin (DB).

**3. Build binary**

```powershell
make build
```

Kalau alat `make` tidak tersedia di komputermu, alternatifnya:

```powershell
go build -o .\bin\grokpi.exe .\cmd\grokpi
```

**4. Jalankan server**

Paling mudah:

```powershell
make run
```

Kalau `make` tidak tersedia:

```powershell
.\bin\grokpi.exe -config .\config.toml
```

Kalau berhasil, service biasanya hidup di:

```text
http://127.0.0.1:8080
```

Cek health:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

**5. Login admin dan kelola token/API key**

Sesuai aturan arsitektur repo ini, jangan kelola admin dengan `curl` manual. Pakai script interaktif Windows:

```powershell
.\scripts\windows\grokpi_admin.ps1
```

Dari situ biasanya alurnya:
- login pakai `app_key` yang telah dibuat di langkah 2
- import token Grok SSO
- buat client API key dengan awalan `sk-...`
- lihat stats/token status

**6. Pakai API secara lokal**

Setelah punya API key client, test endpoint OpenAI-compatible:

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

**7. Jalankan test lokal**

Supaya cache Go tidak terkena *permission issue* (jika direktori default terisolasi):

```powershell
$env:GOCACHE = "E:\GrokPi Lite\.gocache"
go test ./...
go vet ./...
```

**8. Peringatan: Menjalankan menggunakan Docker secara lokal**

> [!WARNING]
> Repo GrokPi Lite mewajibkan *binary host* sudah harus di-build **sebelum** membangun image container Docker.

Oleh karena `Dockerfile.local` mengharapkan path `bin/grokpi`, jalankan hal berikut ini ini sebelum membangun container:

```powershell
make build
docker compose up --build
```

**9. Hal yang jangan dilakukan**

> [!CAUTION]
> - jangan jalankan perintah `make clean` sembarangan, karena akan ikut menghapus isi folder database `data/`.
> - jangan pernah mencoba me-*manage* token admin dan API Key menggunakan perintah manual `curl`; selalu gunakan `.\scripts\windows\grokpi_admin.ps1`.
