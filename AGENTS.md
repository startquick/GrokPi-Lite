# AGENTS

## Repo shape (what matters)
- Single Go service entrypoint: `cmd/grokpi/main.go`.
- This is a headless API edition (no UI/frontend).
- HTTP wiring lives in `internal/httpapi/`; OpenAI-compatible routes are under `/v1/*`, admin routes under `/admin/*`.
- Flow orchestration (chat, image, video retry logic) lives in `internal/flow/`.
- Upstream Grok API client with anti-bot headers in `internal/xai/`.
- CF auto-refresh via FlareSolverr in `internal/cfrefresh/`.

## Source-of-truth commands
- Full local build: `make build`.
- Run: `make run` or `make dev`.
- Backend tests (CI-equivalent core): `go vet ./... && go test -race -count=1 ./...`.
- Vulnerability check (CI runs this too): `go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...`.

## Critical gotchas
- `Dockerfile.local` expects a prebuilt host binary at `bin/grokpi` (`COPY bin/grokpi ...`), so run `make build` before `docker compose up --build`.
- `make clean` removes `data/` in addition to build artifacts; do not run casually.

## Config/runtime behavior that is easy to miss
- Runtime config precedence is `DB overrides > config.toml > defaults`; editing `config.toml` may appear ignored when admin-saved config exists in DB.
- Local defaults are from `config.defaults.toml`; user-specific `config.toml` is gitignored and mounted into Docker at `/app/config.toml`.
- Default `app_key` in `config.defaults.toml` is `"Masanto"`  always change this before exposing the service.
