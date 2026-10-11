# LiteLLM: config.yaml, endpoints, health

> Verified against LiteLLM v1.105.0 (docs: proxy/configs, proxy/config_settings, proxy/health, proxy/prod, proxy/deploy), 2026-10-11

## Minimal working config

```yaml
model_list:
  - model_name: chat-local # alias clients send
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

Top-level sections:

- `model_list`: the registry (details in `models-and-providers.md`).
- `litellm_settings`: module behavior (`drop_params`, `callbacks`, `request_timeout`, `json_logs`, `turn_off_message_logging`).
- `router_settings`: routing, retries, fallbacks, aliases, Redis (`routing-fallbacks.md`).
- `general_settings`: master key, `database_url`, health checks, parallelism, key-generation defaults.
- `environment_variables`: values set for the process.

Any value can come from the environment with `os.environ/NAME`. The proxy's Swagger page (`/#/config.yaml`) lists the keys the running version accepts; `proxy/config_settings` documents all of them. Start with `--config /app/config.yaml` (the compose template does).

## Complete template

`assets/litellm-config.yaml` holds a ready config: local backend with Responses bridge and zero cost, OpenAI, Anthropic, OpenRouter overflow, embeddings, fallbacks, aliases, health settings. `assets/docker-compose.yaml` and `assets/litellm.env.example` complete the deployment.

## Endpoints

Port 4000 by default.

- OpenAI: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/responses`, `/v1/models`.
- Anthropic: `/v1/messages` (unified, any provider) and `/anthropic/*` passthrough to Anthropic.
- Auth: `Authorization: Bearer <key>`; Anthropic clients may send `x-api-key` instead.
- Admin UI: `/ui`. Swagger: `/`.
- Model metadata (with key): `GET /v1/model/info`, `GET /model_group/info`. `/v1/models` is the OpenAI-shaped list.

## Health

- No auth: `GET /health/liveliness` (alias `/health/liveness`) is 200 while the process is up; `GET /health/readiness` returns `{"status": "healthy", "db": ...}` and 503 when a configured DB is unreachable. Use these for Docker healthchecks and load balancers.
- With a key: `GET /health` sends a real request to every model (costs tokens, and cold-starts every model behind a swapper). `?model=<name>` checks one.
- `general_settings.background_health_checks: true` with `health_check_interval` caches results; limit it with `background_health_check_model_groups` when some backends load on demand. `health_check_details: false` hides model details when the proxy is broadly exposed.
- Per-model probe tuning in `model_info`: `mode`, `health_check_timeout`, `health_check_max_tokens`, `disable_background_health_check`.

## Operating notes

- Config file changes need a restart: `docker compose restart litellm` (`up -d` does not restart an unchanged container).
- Models added via UI or `/model/new` live in the DB (`STORE_MODEL_IN_DB=True`); config-file models cannot be edited in the UI. Keep one source of truth.
- Settings saved from the UI into `general_settings`, `router_settings` or `litellm_settings` are stored in the DB and override the YAML on restart.
- Inside the container `127.0.0.1` is the container. Reach a backend on the Docker host with `host.docker.internal` (compose maps it to `host-gateway`) or the LAN address.

## Tuning knobs

- `--num_workers` and `--max_requests_before_restart` (CLI): on Kubernetes use one worker per pod and scale pods; recycle workers if memory grows under sustained load.
- `litellm_settings.request_timeout` (default 6000 s) and `router_settings.timeout` / `stream_timeout`.
- `general_settings.max_parallel_requests` (per deployment) and `global_max_parallel_requests`.
- `litellm_settings.drop_params: true` for heterogeneous backends.
- Dedicated Prometheus listener since v1.101.0: `--prometheus_metrics_port` / `PROMETHEUS_METRICS_PORT` (see `observability.md`).

## Known pitfalls

- Budgets and virtual keys do nothing without a database; `litellm_settings.max_budget` is silently not enforced.
- Changing `LITELLM_SALT_KEY` makes every DB-stored credential unreadable.
- `api_base` without `/v1` for an OpenAI-compatible backend gives `Not Found`.
- Upstream quickstart compose publishes Postgres on 5432 and the proxy on all interfaces with a default DB password; the template here does neither.

## Official links

- Config: https://docs.litellm.ai/docs/proxy/configs
- All settings: https://docs.litellm.ai/docs/proxy/config_settings
- Health: https://docs.litellm.ai/docs/proxy/health
- Production checklist: https://docs.litellm.ai/docs/proxy/prod
