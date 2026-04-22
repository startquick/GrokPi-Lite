# AGENTS

## Repo shape (what matters)
- Single Go service entrypoint: `cmd/grokpi/main.go`.
- This is a headless API edition (no UI/frontend).
- HTTP wiring lives in `internal/httpapi/`.
  - OpenAI-compatible routes: `/v1/chat/completions`, `/v1/models`
  - Anthropic-compatible routes: `/v1/messages`
  - admin routes: `/admin/*`
- Flow orchestration (chat, image, video retry logic) lives in `internal/flow/`.
- Upstream Grok API client with anti-bot headers in `internal/xai/`.
- CF auto-refresh via FlareSolverr in `internal/cfrefresh/`.

## Token & Quota Architecture (Latest)
- **Automatic Priority Tiers**: When an admin imports Grok SSO tokens, the system contacts `/rest/rate-limits`. If the `grok-3` capacity is `>= 30`, it is automatically assigned to `PoolSuper` and given `Priority: 10`. Regular accounts fall back to `PoolBasic` with `Priority: 0`. This logic lives in `internal/token/quota.go`.
- **Client API Keys**: Use the `sk-...` standard. The endpoint outputs are unmasked in CLI scripts so users can directly copy them. Both `Authorization: Bearer <key>` (OpenAI) and `x-api-key: <key>` (Anthropic) headers are natively supported to accommodate multi-platform clients.
- **Admin CLI**: Do not manually `curl` the admin endpoints to manage tokens/keys. Use the provided interactive scripts:
  - Linux/Mac: `./scripts/linux/grokpi_admin.sh`
  - Windows: `.\scripts\windows\grokpi_admin.ps1`
- **Admin Auth Checkers**: For fast troubleshooting of admin auth/session issues, use:
  - Linux/Mac: `./scripts/linux/grokpi_admin_check.sh`
  - Windows: `.\scripts\windows\grokpi_admin_check.ps1`
  These scripts only do `POST /admin/login` and `GET /admin/verify`, so they are the fastest way to distinguish wrong `app_key`, broken session handling, or a stale deploy.

## Source-of-truth commands
- Full local build: `make build`.
- Run: `make run` or `make dev`.
- Backend tests (CI-equivalent core): `go vet ./... && go test -race -count=1 ./...`.
- Vulnerability check (CI runs this too): `go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...`.
- Post-deploy smoke test: `make smoke BASE_URL=http://127.0.0.1:8080 APP_KEY=... API_KEY=...`.

## Critical gotchas
- `Dockerfile.local` expects a prebuilt host binary at `bin/grokpi` (`COPY bin/grokpi ...`), so run `make build` before `docker compose up --build`.
- `make clean` removes `data/` in addition to build artifacts; do not run casually.

## Config/runtime behavior that is easy to miss
- Runtime config precedence is `DB overrides > config.toml > defaults`; editing `config.toml` may appear ignored when admin-saved config exists in DB.
- Local defaults are from `config.defaults.toml`; runtime Docker config is mounted into the container at `/app/config.toml`.
- The checked-in `config.toml` is a local-only placeholder and must not be copied to VPS as-is.
- Default `app_key` in `config.defaults.toml` is `"QUICKstart012345+"` - always change this before exposing the service in production.
- `/admin/system/status` now reports `config.app_key_source`, `config.has_db_overrides`, and `config.db_override_count`, which is the quickest way to confirm whether the live `app_key` came from DB overrides or `config.toml`.

## Cloudflare Bypass & Anti-Bot Protection
- **CFRefresh Trigger**: The `cfScheduler.TriggerRefresh` hook is wired across the entire application (Chat, Video, Image, and Token Quota scheduler). Any `403` Cloudflare challenge from xAI forces an immediate FlareSolverr bypass attempt on-the-fly.
- **Fail-Safe & Backoff**: Consecutive FlareSolverr failures increment an internal tracking state, causing exponential backoff logic (waiting 60s, 120s, up to 15m) to prevent upstream API blocking and local overload.
- **Telegram Webhook**: Using `proxy.telegram_bot_token` and `proxy.telegram_chat_id`, the system proactively sends Telegram alerts to admins if the solver fails 3 times in a row.
