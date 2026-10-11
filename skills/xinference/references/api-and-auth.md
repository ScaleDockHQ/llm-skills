# Xinference API surface and authentication

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

## Endpoints

| Path                                                                                                                                         | Purpose                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `GET /status`                                                                                                                                | Liveness, used by compose and services; unauthenticated |
| `/docs`                                                                                                                                      | Interactive API docs                                    |
| `GET /v1/models`, `POST /v1/models`, `DELETE /v1/models/{uid}`                                                                               | List, launch, terminate running models                  |
| `GET /v1/models/{uid}/progress`                                                                                                              | Per-replica launch stages                               |
| `POST /v1/models/{uid}/reload`, `GET .../reload`                                                                                             | Reconfigure without reloading weights                   |
| `POST /v1/models/recommend`                                                                                                                  | Read-only launch recommendation                         |
| `GET /v1/model_registrations/{type}`                                                                                                         | Launchable models (`LLM`, `embedding`, ...)             |
| `POST /v1/cache/models`, `GET /v1/downloads`                                                                                                 | Download only and download management                   |
| `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/rerank`, `/v1/responses`                                                   | Inference                                               |
| `/v1/images/generations`, `/v1/images/edits`, `/sdapi/v1/*`, `/v1/video/generations`, `/v1/audio/transcriptions`, `/translations`, `/speech` | Media                                                   |
| `GET /v1/cluster/version`, `/v1/cluster/info`, `/v1/cluster/devices`, `/v1/virtualenvs`                                                      | Version, topology, GPU devices, virtualenvs             |
| `GET /v1/engines/{model_name}`, `/v1/models/{uid}/replicas`, `/v1/models/{uid}/requests/{id}/abort`                                          | Engine discovery, replicas, abort a request             |
| `/anthropic/v1/messages`                                                                                                                     | Anthropic-style chat                                    |
| `/metrics`                                                                                                                                   | Prometheus (supervisor)                                 |
| `/v1/admin/setup`, `/v1/admin/setup/status`                                                                                                  | First-run admin creation (unauthenticated until done)   |
| `/v1/admin/users`, `/v1/admin/keys`                                                                                                          | Users and API keys                                      |
| `GET /v1/audit/search`, `GET /v1/cluster/logs/correlated`                                                                                    | Audit and correlated logs                               |

## Authentication model (default on since v3.0)

- State lives in SQLite (`XINFERENCE_AUTH_DB_PATH`, default `XINFERENCE_HOME/auth/auth.db`) plus an
  auto-generated JWT secret and API-key encryption key under `XINFERENCE_HOME/auth/`. Back them up; share
  them (or the env vars) across every process that serves the API.
- Disable only with `XINFERENCE_AUTH_ADVANCED=false|0|no`; then no endpoint is protected.
- First run: no admin exists. `GET /v1/admin/setup/status` returns `needs_setup`; `POST /v1/admin/setup` with
  `username` and `password` creates the admin; it refuses a second account. Whoever calls it first becomes
  admin, so do it before exposing the port. Lost password or lost race: an operator on the host runs
  `xinference-reset-auth-password --username admin` (revokes refresh tokens).
- Sessions: access tokens last 30 minutes (`XINFERENCE_ACCESS_TOKEN_EXPIRE_MINUTES`), refresh tokens 7 days.
  `xinference login -e URL --username U --password P` stores a token under `XINFERENCE_HOME/auth/`.
- API keys for programs: `POST /v1/admin/keys` with `{"name":"my-key"}` (names unique and required; values can be revealed later with `keys:manage`). Use `Authorization: Bearer <key>`, the CLI
  `--api-key`, or `Client(endpoint, api_key=...)`. Keys can be restricted to models in the Web UI.
- Permissions: `models:list`, `models:read`, `models:write`, `models:register`, `keys:create`, `keys:manage`,
  `users:manage`, `cache:list|delete`, `virtualenv:list|delete`, `logs:list`, `monitor:view`,
  `settings:read|write`, `admin`. A caller can only grant permissions they hold; changes apply on the next call.
  Legacy scope names (`models:start`, `models:stop`, `models:add`, `models:unregister`) are mapped but
  deprecated.
- Typical least-privilege client key: a user with `models:list` and `models:read`.
- 401 means bad or missing credentials, 403 missing permission.

```bash
# Create a user and read-only key (admin token from a 0600 file; store the returned key in a 0600 file)
curl -s -X POST http://127.0.0.1:9997/v1/admin/users -H "Authorization: Bearer $(cat ~/.xinference-admin-token)" \
  -H 'Content-Type: application/json' -d '{"username":"client1","password":"<choose>","permissions":["models:list","models:read"]}'
```

## Hardening

- `XINFERENCE_ALLOWED_IPS` (IPs or CIDRs), brute-force protection with unban in the Security Settings page,
  `XINFERENCE_HTTP_REQUEST_TIMEOUT` (Slowloris guard, default 120), `XINFERENCE_HTTP_LIMIT_CONCURRENCY`.
- OIDC SSO (Keycloak and similar): `XINFERENCE_OIDC_ENABLED=1` plus issuer, client id, client secret and
  redirect URI variables (`XINFERENCE_OIDC_*`); secrets from a protected env file.
- Audit trail: `XINFERENCE_LOG_DIR/audit.log` (JSON lines, daily rotation, 90 days). It is an auth audit trail,
  not a full access log (`/status` and some bootstrap routes are excluded). Request bodies are fetched only with
  `logs:list` and `model_requests:read_body`, and never when auth is disabled. Opt-in model request logging was
  added in v3.5.
- Put TLS and rate limits in a reverse proxy (`caddy`, `cloudflare-tunnel`, `tailscale` skills); the server
  speaks plain HTTP.
