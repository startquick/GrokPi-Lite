# MasantoID API Reference

Dokumen ini merangkum API yang relevan untuk frontend Studio (Prompt Lab, Image, Video) berdasarkan implementasi server saat ini.

## 1. Base URL dan Auth

| Item | Nilai |
| --- | --- |
| Base URL lokal | `http://127.0.0.1:8080` |
| Health endpoint | `GET /health` atau `GET /healthz` (tanpa auth) |
| API endpoint utama | Prefix `/v1/*` |
| Auth untuk `/v1/*` | Header `Authorization: Bearer <API_KEY>` |
| Error auth umum | `401 invalid_api_key`, `429 rate_limit_exceeded`, `429 daily_limit_exceeded` |

Contoh header:

```http
Authorization: Bearer gf-xxxxxxxxxxxxxxxx
Content-Type: application/json
```

## 2. Endpoint Ringkas

| Method | Path | Auth | Fungsi |
| --- | --- | --- | --- |
| GET | `/health` | Tidak | Cek status server |
| GET | `/v1/models` | API key | Ambil model yang tersedia untuk key tersebut |
| POST | `/v1/chat/completions` | API key | Chat, image generate/edit, video generate (tergantung model) |
| GET | `/api/files/video/{name}` | Tidak | Ambil file video cache dari URL hasil generate |

Catatan:
- Tidak ada endpoint terpisah khusus image/video. Media generation dipanggil lewat `POST /v1/chat/completions` menggunakan model media.
- URL video hasil generate biasanya sudah dalam bentuk URL absolut ke `/api/files/video/{name}`.

## 3. Model Yang Tersedia (Live Saat Ini)

Berikut hasil `GET /v1/models` pada environment ini saat dokumen dibuat:

| Model ID | Kategori |
| --- | --- |
| `grok-3` | Chat |
| `grok-3-mini` | Chat |
| `grok-3-thinking` | Chat |
| `grok-4` | Chat |
| `grok-4-mini` | Chat |
| `grok-4-thinking` | Chat |
| `grok-4-heavy` | Chat |
| `grok-4.1-fast` | Chat |
| `grok-4.1-mini` | Chat |
| `grok-4.1-thinking` | Chat |
| `grok-4.1-expert` | Chat |
| `grok-4.20-beta` | Chat |
| `grok-imagine-1.0` | Image generate |
| `grok-imagine-1.0-fast` | Image generate (fast defaults) |
| `grok-imagine-1.0-edit` | Image edit |
| `grok-imagine-1.0-video` | Video generate |

Catatan penting:
- Daftar ini dinamis mengikuti konfigurasi `token.basic_models` dan `token.super_models`.
- Jika API key punya `model_whitelist`, hasil akhirnya bisa lebih sedikit.

## 4. GET /v1/models

### Request

```http
GET /v1/models HTTP/1.1
Authorization: Bearer gf-xxxxxxxxxxxxxxxx
```

### Response sukses

```json
{
  "object": "list",
  "data": [
    {
      "id": "grok-imagine-1.0-video",
      "object": "model",
      "created": 1709251200,
      "owned_by": "xai"
    }
  ]
}
```

## 5. POST /v1/chat/completions (Endpoint Utama)

## 5.1 Field Request Umum

| Field | Tipe | Wajib | Default | Keterangan |
| --- | --- | --- | --- | --- |
| `model` | string | Ya | - | Model target |
| `messages` | array | Ya | - | Riwayat percakapan / multimodal blocks |
| `stream` | bool | Tidak | Mengikuti config `app.stream` | `true` untuk SSE stream |
| `temperature` | number | Tidak | `0.8` | Range `0` s.d. `2` |
| `top_p` | number | Tidak | `0.95` | Range `0` s.d. `1` |
| `max_tokens` | int | Tidak | - | Batas output token untuk chat |
| `reasoning_effort` | string | Tidak | - | `none|minimal|low|medium|high|xhigh` |
| `tools` | array | Tidak | - | Tool definitions untuk tool-calling |
| `tool_choice` | string/object | Tidak | - | `auto|required|none` atau object function |
| `parallel_tool_calls` | bool | Tidak | `true` | Paralel tool calls |
| `image_config` | object | Tidak | Tergantung model | Dipakai model image |
| `video_config` | object | Tidak | Tergantung model | Dipakai model video |

Validasi penting:
- `model` wajib ada.
- `messages` tidak boleh kosong.
- `message.content` tidak boleh null/kosong.

## 5.2 Format messages (text + image)

### A. Bentuk text sederhana

```json
{
  "role": "user",
  "content": "Buatkan poster neon cyberpunk"
}
```

### B. Bentuk multimodal blocks (disarankan untuk image edit/video reference)

```json
{
  "role": "user",
  "content": [
    { "type": "text", "text": "Ubah gaya jadi cinematic" },
    { "type": "image_url", "image_url": { "url": "data:image/png;base64,...." } }
  ]
}
```

Rule block yang diterima pada role `user`:

| `type` | Keterangan |
| --- | --- |
| `text` | Teks prompt |
| `image_url` | URL gambar / data URI base64 |
| `input_audio` | Input audio (format block validasi tersedia) |
| `file` | File input (format block validasi tersedia) |

Untuk role selain `user`, konten block yang didukung adalah `text`.

## 6. Image API via Chat Completions

Gunakan model:
- `grok-imagine-1.0`
- `grok-imagine-1.0-fast`
- `grok-imagine-1.0-edit`

### 6.1 image_config

| Field | Tipe | Default | Batasan |
| --- | --- | --- | --- |
| `n` | int | `1` | `1` s.d. `10` |
| `size` | string | `1024x1024` | Hanya nilai yang diizinkan (lihat tabel size) |
| `response_format` | string | `b64_json` | Saat ini dinormalisasi paksa ke `b64_json` |
| `enable_nsfw` | bool | mengikuti sistem | Flag opsional NSFW |

### 6.2 Size Image yang Diizinkan

| Size |
| --- |
| `1024x1024` |
| `1024x1792` |
| `1792x1024` |
| `1280x720` |
| `720x1280` |

Catatan stream untuk image:
- Jika `stream=true`, maka `image_config.n` hanya boleh `1` atau `2`.

### 6.3 Khusus model edit

Model `grok-imagine-1.0-edit` membutuhkan minimal 1 gambar dari block `image_url` di messages user.

## 6.4 Contoh request image generate

```json
{
  "model": "grok-imagine-1.0",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": "A minimalist product photo of a smart watch on white background"
    }
  ],
  "image_config": {
    "n": 1,
    "size": "1024x1024",
    "response_format": "b64_json"
  }
}
```

## 6.5 Contoh request image edit

```json
{
  "model": "grok-imagine-1.0-edit",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "Make this image warmer and cinematic" },
        { "type": "image_url", "image_url": { "url": "data:image/png;base64,...." } }
      ]
    }
  ],
  "image_config": {
    "n": 1,
    "size": "1792x1024"
  }
}
```

## 7. Video API via Chat Completions

Gunakan model:
- `grok-imagine-1.0-video`

### 7.1 video_config

| Field | Tipe | Default | Batasan |
| --- | --- | --- | --- |
| `aspect_ratio` | string | `3:2` | Lihat nilai valid di bawah |
| `video_length` | int | `6` | `6` s.d. `30` detik |
| `resolution_name` | string | `480p` | `480p` atau `720p` |
| `preset` | string | `custom` | `custom|fun|normal|spicy` |

### 7.2 Aspect Ratio yang Diterima

Bisa pakai ratio atau alias size berikut:

| Input diterima | Dinormalisasi menjadi |
| --- | --- |
| `16:9` atau `1280x720` | `16:9` |
| `9:16` atau `720x1280` | `9:16` |
| `3:2` atau `1792x1024` | `3:2` |
| `2:3` atau `1024x1792` | `2:3` |
| `1:1` atau `1024x1024` | `1:1` |

### 7.3 Mapping Resolution + Ratio ke Size Internal

Server menghitung size internal dari rumus:
- tinggi = `480` untuk `480p`
- tinggi = `720` untuk `720p`
- lebar = `tinggi * rasio_w / rasio_h` (integer)

| resolution_name | aspect_ratio | size internal |
| --- | --- | --- |
| `480p` | `16:9` | `853x480` |
| `480p` | `9:16` | `270x480` |
| `480p` | `3:2` | `720x480` |
| `480p` | `2:3` | `320x480` |
| `480p` | `1:1` | `480x480` |
| `720p` | `16:9` | `1280x720` |
| `720p` | `9:16` | `405x720` |
| `720p` | `3:2` | `1080x720` |
| `720p` | `2:3` | `480x720` |
| `720p` | `1:1` | `720x720` |

### 7.4 Preset yang Didukung

| Preset |
| --- |
| `custom` |
| `fun` |
| `normal` |
| `spicy` |

### 7.5 Reference image untuk video

Jika ada block `image_url` pada message user, server menggunakan gambar pertama sebagai `reference_image`.

### 7.6 Contoh request video

```json
{
  "model": "grok-imagine-1.0-video",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "A cinematic drone shot over tropical island at sunrise" }
      ]
    }
  ],
  "video_config": {
    "aspect_ratio": "16:9",
    "video_length": 10,
    "resolution_name": "720p",
    "preset": "normal"
  }
}
```

## 8. Response Format

### 8.1 Non-stream (`stream=false`)

Response shape OpenAI-compatible:

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1710000000,
  "model": "grok-imagine-1.0-video",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "[video](http://127.0.0.1:8080/api/files/video/xxx.mp4)"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 0,
    "completion_tokens": 0,
    "total_tokens": 0
  }
}
```

Catatan output media:
- Image biasanya dikembalikan sebagai markdown image dengan data URI base64.
- Video dikembalikan sebagai markdown link `[video](...)`.

### 8.2 Stream (`stream=true`)

- Content-Type: SSE
- Format: `chat.completion.chunk`
- Akhir stream: `data: [DONE]`

## 9. Error Codes Penting

| HTTP | code | Kapan terjadi |
| --- | --- | --- |
| 400 | `invalid_json` | JSON request rusak |
| 400 | `missing_model` | field `model` kosong |
| 400 | `invalid_messages` | messages kosong/tidak valid |
| 400 | `invalid_temperature` | di luar `0..2` |
| 400 | `invalid_top_p` | di luar `0..1` |
| 400 | `invalid_image_config` | image_config tidak valid |
| 400 | `invalid_video_config` | video_config tidak valid |
| 400 | `missing_prompt` | prompt kosong untuk image/video |
| 400 | `missing_image` | image edit tanpa image_url |
| 401 | `invalid_api_key` | API key kosong/tidak valid/inactive/expired |
| 403 | `model_not_allowed` | model tidak masuk whitelist API key |
| 403 | `media_generation_disabled` | fitur media dimatikan admin |
| 404 | `model_not_found` | model tidak ada di config model pool |
| 429 | `rate_limit_exceeded` | limit per menit API key terlampaui |
| 429 | `daily_limit_exceeded` | kuota harian API key habis |

## 10. Catatan Integrasi Frontend Studio

- Selalu panggil `GET /v1/models` saat app load untuk sinkron model real-time.
- Untuk tab video, filter model `grok-imagine-1.0-video`.
- Untuk tab image, gunakan `grok-imagine-1.0`, `grok-imagine-1.0-fast`, `grok-imagine-1.0-edit`.
- Simpan API key per user/session, jangan hardcode di source frontend.
- Tampilkan pesan error berdasarkan `error.code` agar UX lebih jelas.
