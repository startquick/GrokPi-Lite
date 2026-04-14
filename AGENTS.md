# AGENTS

## Repo shape (what matters)
- Single Go service entrypoint: `cmd/grokpi/main.go`.
- Frontend is Next.js static export in `web/`, embedded into the Go binary via `web/embed.go` (`//go:embed all:out`).
- HTTP wiring lives in `internal/httpapi/`; OpenAI-compatible routes are under `/v1/*`, admin routes under `/admin/*`.
- Flow orchestration (chat, image, video retry logic) lives in `internal/flow/`.
- Upstream Grok API client with anti-bot headers in `internal/xai/`.
- CF auto-refresh via FlareSolverr in `internal/cfrefresh/`.

## Source-of-truth commands
- Full local build (frontend + budget check + backend binary): `make build`.
- Run without rebuilding frontend: `make dev` (runs `go run ./cmd/grokpi` with ldflags).
- Frontend only: `cd web && npm ci && npm run build`.
- Backend tests (CI-equivalent core): `go vet ./... && go test -race -count=1 ./...`.
- Frontend CI checks: `cd web && npm ci && npx tsc --noEmit && npm run build`.
- Vulnerability check (CI runs this too): `go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...`.

## Critical gotchas
- Backend compile/tests require `web/out` to exist because of embed; if you did not build frontend, create a stub first: `mkdir -p web/out && touch web/out/.gitkeep` (this is what CI does).
- `make build` enforces frontend performance budgets via `scripts/validate_frontend_budget.py` and `performance-budgets.json`; build can fail even when TypeScript/build pass.
- `Dockerfile.local` expects a prebuilt host binary at `bin/grokpi` (`COPY bin/grokpi ...`), so run `make build` before `docker compose up --build`.
- `make clean` removes `data/` in addition to build artifacts; do not run casually.
- `scripts/` is gitignored — the budget validation script exists locally but is not distributed in the repo. If missing, `make build` will fail at the `web` target.
- CI uses Node 22 but README documents Node 20; use Node 22 to match CI.

## Config/runtime behavior that is easy to miss
- Runtime config precedence is `DB overrides > config.toml > defaults`; editing `config.toml` may appear ignored when admin-saved config exists in DB.
- Local defaults are from `config.defaults.toml`; user-specific `config.toml` is gitignored and mounted into Docker at `/app/config.toml`.
- Default `app_key` in `config.defaults.toml` is `"Masanto"` — always change this before exposing the service.
