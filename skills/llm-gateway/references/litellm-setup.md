# LiteLLM proxy setup

> Verified against LiteLLM v1.105.0 (docs: proxy/docker_quick_start, proxy/deploy, proxy/prod, proxy/configs, proxy/config_settings, proxy/health, proxy/release_cycle), 2026-10-11

## What it is and when to choose it

The LiteLLM proxy is a self-hosted gateway that exposes OpenAI-compatible, OpenAI Responses and Anthropic Messages endpoints and routes them to 100+ providers, including any OpenAI-compatible local engine. With Postgres attached it adds virtual keys, teams, budgets, spend logs and an Admin UI. Choose it as the default self-hosted gateway (see `choosing-a-gateway.md`).

## Install

Docker Compose with Postgres is the recommended single-host install. Start from `assets/docker-compose.yaml` and `assets/litellm-config.yaml`.

Images are published at `ghcr.io/berriai/litellm` (mirrored at `docker.litellm.ai/berriai/litellm`). Since 1.84.0 stable releases use plain semver tags, published both bare (`1.105.0`) and `v`-prefixed (`v1.105.0`). Upstream examples still show `main-stable` or `latest`; pin a release tag instead.

Create secrets without printing them:

```bash
umask 077
touch .env
printf 'LITELLM_MASTER_KEY=sk-%s\nLITELLM_SALT_KEY=sk-%s\nPOSTGRES_PASSWORD=%s\n' \
  "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" "$(openssl rand -hex 24)" >> .env
# then add provider keys by editing .env in an editor, never with echo in shell history
```

- `LITELLM_MASTER_KEY` must start with `sk-`. The proxy refuses to start without it or with a known unsafe value. It is also the Admin UI password (user `admin`).
- `LITELLM_SALT_KEY` encrypts provider credentials stored in the database. Set it once and never change it after models or credentials are stored in the DB; there is no in-place rotation.
- `DATABASE_URL` (`postgresql://user:pass@host:5432/db`) enables keys, teams, budgets and spend logs.

Start and load the key into the current shell without echoing it:

```bash
docker compose up -d
LITELLM_MASTER_KEY="$(grep '^LITELLM_MASTER_KEY=' .env | cut -d= -f2-)"; export LITELLM_MASTER_KEY
```

## Minimal working config

```yaml
model_list:
  - model_name: chat-local
    litellm_params:
      model: openai/local-model # openai/ prefix = generic OpenAI-compatible backend
      api_base: http://127.0.0.1:8080/v1 # include /v1
      api_key: "none"
    model_info:
      max_input_tokens: 32768
      max_output_tokens: 8192
      supports_function_calling: true

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
```

Top-level sections: `model_list`, `litellm_settings` (module behavior: `drop_params`, callbacks, `request_timeout`), `router_settings` (routing, retries, fallbacks, aliases), `general_settings` (master key, database, health checks), `environment_variables`. Any value can be read from the environment with `os.environ/NAME`. The proxy's Swagger page (`/#/config.yaml`) lists every accepted key for the running version.

Run with `--config /app/config.yaml` (the compose template does this).

## How it plugs into the stack

- Port: 4000.
- OpenAI: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/responses`, `/v1/models`.
- Anthropic: `/v1/messages` (unified, any provider) and `/anthropic/*` passthrough to Anthropic.
- Auth: `Authorization: Bearer <key>`; Anthropic clients may also send `x-api-key`.
- Health, no auth: `GET /health/liveliness` (alias `/health/liveness`) returns 200 while the process is up; `GET /health/readiness` returns `{"status": "healthy", "db": ...}` and 503 when a configured DB is unreachable.
- Health, with a key: `GET /health` probes every model with a real request (costs tokens); `?model=<name>` checks one. Use `background_health_checks: true` and `health_check_interval` in `general_settings` to cache results.
- Model metadata: `GET /v1/model/info` and `GET /model_group/info` (with key) show `model_info`; `/v1/models` is the OpenAI-shaped list.
- Admin UI: `/ui`.

Inside the LiteLLM container, `127.0.0.1` is the container itself. To reach a backend on the Docker host use `host.docker.internal` (the compose template maps it to the host gateway) or the host's LAN address.

## Operating

- Config file changes need a container restart (`docker compose restart litellm`).
- Models added through the UI or `/model/new` live in the DB (`STORE_MODEL_IN_DB=True`). Config-file models cannot be edited in the UI. Keep one primary source of truth.
- Settings saved from the UI into `general_settings`, `router_settings`, `litellm_settings` are stored in the DB and override the YAML on restart.
- Logs: `docker compose logs -f litellm`. Temporary verbose logs: add `--detailed_debug` or set `LITELLM_LOG=DEBUG`; revert afterwards since debug logs can contain prompts.

## Tuning knobs worth knowing

- `--num_workers` on the CLI and `--max_requests_before_restart` for long-running workers (see proxy/prod).
- `general_settings.background_health_checks`, `health_check_interval`, `health_check_details: false` when the proxy is broadly exposed.
- `litellm_settings.request_timeout` (default 6000 s) and `router_settings.timeout` / `stream_timeout`.
- `general_settings.max_parallel_requests` (per deployment) and `global_max_parallel_requests`.
- `litellm_settings.drop_params: true` for heterogeneous backends.

## Known pitfalls

- Budgets and virtual keys do nothing without a database. `litellm_settings.max_budget` without a DB is silently not enforced.
- Changing `LITELLM_SALT_KEY` makes every DB-stored credential unreadable.
- Rotating the master key with `POST /key/regenerate` and `new_master_key` while a salt key is set can brick stored credentials; with a salt key, just change the env var and restart (see proxy/master_key_rotations).
- Upstream quickstart compose binds Postgres to host port 5432 and LiteLLM to all interfaces; the template here binds to `127.0.0.1` only.
- `api_base` without `/v1` for an OpenAI-compatible backend gives `Not Found` errors.

## Official links

- Quickstart: https://docs.litellm.ai/docs/proxy/docker_quick_start
- Production deployment: https://docs.litellm.ai/docs/proxy/deploy
- Production checklist: https://docs.litellm.ai/docs/proxy/prod
- Config reference: https://docs.litellm.ai/docs/proxy/configs and https://docs.litellm.ai/docs/proxy/config_settings
- Health checks: https://docs.litellm.ai/docs/proxy/health
- Release cycle: https://docs.litellm.ai/docs/proxy/release_cycle
- Upstream quickstart compose: https://github.com/BerriAI/litellm/blob/main/docker/docker-compose.quickstart.yml
