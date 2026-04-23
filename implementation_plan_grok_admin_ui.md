# Redesign Admin Access UI — Grok-Inspired Dashboard

## Latar Belakang

Admin UI saat ini (`admin_access.html`, 804 baris) menggunakan **light theme with warm tones** (cream/beige `#f5f1e8`) — fungsional tapi terasa outdated dibanding Grok.com yang menggunakan design language modern, dark-first, minimalis.

### Kondisi Saat Ini vs Target

| Aspek | Saat Ini | Target (Grok-style) |
|---|---|---|
| Theme | Light (cream/warm) | **Dark-first** (pure black `#000`) + light mode toggle |
| Background | `#f5f1e8` radial gradient | `#000000` → `#0a0a0a` subtle |
| Surface/Cards | `#fffaf1` warm panel | `#141414` dark card, `#1a1a1a` elevated |
| Accent | Teal `#005f73` | White CTAs on dark, subtle gray accents |
| Buttons | Rounded pill, teal fill | **Pill-shaped**, white-on-black primary + ghost variants |
| Border radius | 14px panels, 999px buttons | `16-24px` panels, `999px` pills |
| Typography | Inter + DM Mono | Inter (primary) + JetBrains Mono (code) |
| Navigation | Tabs (Tokens / API Keys) | **Sidebar** with icon + label, collapsible |
| Layout | Single scrolling page | Sidebar + content area, page-based navigation |
| Stats cards | 3 basic stats | Rich overview dashboard with 6+ metrics |
| Usage/Config | Tidak ada di UI | **Halaman baru**: Usage logs, Config editor, Cache manager |

---

## Constraint Arsitektur

> [!IMPORTANT]
> **Single embedded HTML file** — Admin UI di-embed ke binary via `//go:embed admin_access.html`. Tidak ada perubahan pada Go code yang diperlukan — cukup replace isi file HTML. Semua CSS, JS, dan HTML harus tetap dalam **satu file**.

- Tidak ada framework (React, Vue, dsb.) — pure vanilla HTML/CSS/JS
- Semua styling inline di `<style>` block
- Semua logic inline di `<script>` block
- Font di-load dari Google Fonts CDN (sudah dilakukan sekarang)
- Harus tetap responsif (mobile-friendly)

---

## Design System Baru

### Color Palette (Dark Mode Default)

```
--bg-primary:     #000000    // Page background
--bg-surface:     #141414    // Card/panel surface
--bg-elevated:    #1a1a1a    // Elevated surface (dropdowns, modals)
--bg-hover:       #1f1f1f    // Hover state on surface
--bg-input:       #0a0a0a    // Input fields background

--border:         #262626    // Default border
--border-hover:   #333333    // Hovered border
--border-focus:   #525252    // Focused input border

--text-primary:   #ffffff    // Primary text
--text-secondary: #a1a1a1    // Secondary/muted text
--text-tertiary:  #666666    // Disabled/placeholder

--accent-green:   #22c55e    // Active/success status
--accent-red:     #ef4444    // Error/danger/expired
--accent-amber:   #f59e0b    // Warning/cooling
--accent-blue:    #3b82f6    // Info/links
--accent-cyan:    #06b6d4    // SuperPool badge

--btn-primary-bg: #ffffff    // Primary button (white on dark)
--btn-primary-fg: #000000    // Primary button text
--btn-ghost-bg:   transparent
--btn-ghost-hover:#1f1f1f
```

### Typography

```css
--font-sans:  'Inter', -apple-system, sans-serif;
--font-mono:  'JetBrains Mono', 'SF Mono', monospace;

--text-xs:    0.75rem;   /* 12px - badges, captions */
--text-sm:    0.8125rem; /* 13px - table cells, secondary */
--text-base:  0.875rem;  /* 14px - body text */
--text-lg:    1rem;      /* 16px - subheadings */
--text-xl:    1.25rem;   /* 20px - page title */
--text-2xl:   1.5rem;    /* 24px - stat numbers */
--text-3xl:   2rem;      /* 32px - hero stat */
```

### Component Specs

| Component | Spec |
|---|---|
| **Buttons (primary)** | `bg: white`, `color: black`, `border-radius: 999px`, `padding: 8px 20px`, `font-weight: 500` |
| **Buttons (ghost)** | `bg: transparent`, `border: 1px solid #262626`, `border-radius: 999px`, hover `bg: #1f1f1f` |
| **Buttons (danger)** | `bg: #ef4444`, `color: white`, `border-radius: 999px` |
| **Cards** | `bg: #141414`, `border: 1px solid #262626`, `border-radius: 16px`, `padding: 20px 24px` |
| **Inputs** | `bg: #0a0a0a`, `border: 1px solid #262626`, `border-radius: 12px`, focus `border: #525252` |
| **Tables** | `bg: #141414`, no vertical borders, row hover `#1a1a1a`, header `#0a0a0a` |
| **Badges** | `border-radius: 999px`, `padding: 2px 8px`, `font-size: 12px`, colored backgrounds at 15% opacity |
| **Sidebar** | Width `240px` (desktop), collapsible, `bg: #0a0a0a`, `border-right: 1px solid #262626` |
| **Modal** | `bg: #1a1a1a`, `border: 1px solid #262626`, `border-radius: 20px`, `backdrop: blur(8px)` |
| **Toast** | `border-radius: 12px`, `bottom: 24px right: 24px`, subtle shadow |

---

## Halaman & Layout

### Navigasi (Sidebar)

```
┌──────────────────┐
│  ⬡  GrokPi       │  ← Logo + title
│                  │
│  📊 Overview     │  ← Dashboard stats
│  🔑 Tokens       │  ← Token management
│  🗝️ API Keys     │  ← API key management
│  📈 Usage        │  ← Usage logs + charts (NEW)
│  ⚙️ Config       │  ← Runtime config editor (NEW)
│  💾 Cache        │  ← Cache management (NEW)
│                  │
│  ─────────────── │
│  ↩ Sign out      │
│  v1.2.3          │  ← Version
└──────────────────┘
```

### 1. Login Page

Centered, minimal, dark:
- Logo Grok hexagon + "GrokPi" brand
- Single password field (app_key)
- Pill "Sign in" button (white on black)
- Tagline: "Admin Console"

### 2. Overview (Dashboard)

Stats grid (3×2) at top:
- **Tokens** — total + active count, mini status bar
- **API Keys** — total + active
- **Uptime** — from `/admin/system/status`
- **Version** — build version
- **Chat Quota** — aggregated from `/admin/stats/quota`
- **Config Source** — app_key source + DB override count

Recent activity section:
- Latest 5 usage logs from `/admin/usage/logs`

### 3. Tokens Page

- **Import form** — textarea for tokens, pool selector, quota, remark
- **Token table** — ID, Token (masked), Tier, Status, Quota bar, Last used, Remark, Actions
- Actions: Refresh, Enable/Disable, Replace, Edit remark, Delete

### 4. API Keys Page

- **Create form** — name, rate limit, daily limit
- **Key table** — ID, Name, Key (masked), Status, Limits, Usage, Last used, Actions
- Actions: Edit, Enable/Disable, Regenerate, Delete

### 5. Usage Page (NEW)

- **Period selector** — 24h / 7d / 30d
- **Stats cards** — total requests, tokens used, errors
- **Usage log table** — from `/admin/usage/logs` with pagination

### 6. Config Page (NEW)

- **Current config viewer** — rendered from `/admin/config`
- **Editable fields** — key config values with save button
- **DB override indicator** — show which values come from DB vs config.toml

### 7. Cache Page (NEW)

- **Cache stats** — from `/admin/cache/stats` (total size, file count)
- **File list** — from `/admin/cache/files`
- **Actions** — Delete individual files, Clear all cache

---

## API Endpoints yang Digunakan

Semua endpoint sudah tersedia — tidak perlu perubahan backend:

| Halaman | Endpoint | Method |
|---|---|---|
| Login | `/admin/login` | POST |
| Verify | `/admin/verify` | GET |
| Logout | `/admin/logout` | POST |
| Overview | `/admin/system/status` | GET |
| Overview | `/admin/stats/quota` | GET |
| Tokens | `/admin/tokens?page_size=100` | GET |
| Tokens | `/admin/tokens/batch` | POST |
| Tokens | `/admin/tokens/{id}` | PUT/DELETE |
| Tokens | `/admin/tokens/{id}/replace` | POST |
| Tokens | `/admin/tokens/{id}/refresh` | POST |
| API Keys | `/admin/apikeys` | GET/POST |
| API Keys | `/admin/apikeys/{id}` | GET/PATCH/DELETE |
| API Keys | `/admin/apikeys/{id}/regenerate` | POST |
| Usage | `/admin/system/usage?period=24h` | GET |
| Usage | `/admin/usage/logs?page_size=50` | GET |
| Config | `/admin/config` | GET/PUT |
| Cache | `/admin/cache/stats` | GET |
| Cache | `/admin/cache/files` | GET |
| Cache | `/admin/cache/delete` | POST |
| Cache | `/admin/cache/clear` | POST |

---

## Proposed Changes

### [MODIFY] [admin_access.html](file:///e:/GrokPi%20Lite/internal/httpapi/admin_access.html)

**Full rewrite** — file ini akan ditulis ulang sepenuhnya (~1500-2000 baris) dengan:
- Dark mode design system
- Sidebar navigation (client-side routing via hash)
- 7 halaman: Login, Overview, Tokens, API Keys, Usage, Config, Cache
- Responsive (sidebar collapses di mobile)
- Smooth page transitions
- Semua fungsionalitas lama dipertahankan + 3 halaman baru

> [!NOTE]
> **Tidak ada perubahan pada Go code** — `admin_ui.go` dan `server.go` tetap sama persis. Hanya isi file HTML yang berubah.

> [!NOTE]
> File ini akan sangat besar (~1500-2000 baris) karena semua CSS, JS, dan HTML digabung dalam satu file. Ini adalah trade-off dari arsitektur single-file embed.

---

## Open Questions

> [!IMPORTANT]
> **Q1: Dark mode only atau dengan toggle light mode?**
> Grok.com punya light + dark toggle. Apakah kamu mau dark-only atau juga menyediakan toggle?
> Rekomendasi: **Dark-only** dulu untuk versi pertama. Light mode bisa ditambah belakangan.

> [!IMPORTANT]
> **Q2: Scope halaman baru — semuanya sekarang atau bertahap?**
> Plan ini mencakup 7 halaman. Opsi:
> - **Full**: Semua 7 halaman sekaligus (lebih lama tapi konsisten)
> - **Fase 1**: 4 halaman core dulu (Login, Overview, Tokens, API Keys) → **Fase 2**: Usage, Config, Cache
>
> Rekomendasi: **Full** — karena semua API-nya sudah tersedia dan kita cukup menulis HTML/JS saja tanpa perubahan backend.

---

## Verification Plan

### Manual Verification
1. `docker compose up -d --build` — rebuild image dengan HTML baru
2. Buka `http://127.0.0.1:8080/admin/access` — verifikasi login page
3. Login → dashboard menampilkan semua stats
4. Navigasi sidebar → setiap halaman ter-render
5. Test CRUD token dan API key
6. Test responsive di viewport kecil (mobile)

### Automated Tests
```bash
# Go tests (admin endpoints tidak berubah — test harus tetap pass)
go test ./internal/httpapi/... -v
```
