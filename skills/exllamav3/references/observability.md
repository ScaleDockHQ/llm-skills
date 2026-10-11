# Observability

> Verified against TabbyAPI main (config_sample.yml, endpoints/core/router.py) and ExLlamaV3 v1.6.1, 2026-10-11

## Health

`GET /health` (no auth): `{"status":"healthy"|"unhealthy","issues":[...]}`, HTTP 200 or 503. Used by the compose healthcheck (`curl -f http://127.0.0.1:5000/health`, 30 s interval). It does not load or wake a model.

## Logs

- Console: startup log shows the loaded config, VRAM split, version check and a `Response parsing:` line (tool format and reasoning tags detected). Docker: `docker logs -f <name>`; systemd: `journalctl -u tabbyapi -f`.
- Files: written under `logs/` (full timestamps).
- `logging.log_live_status` (default true): live line with cache usage, hit rate and in-flight jobs (prefill progress, generation speed), only on an interactive terminal; in containers run with `-t` to see it.
- `logging.access_log: true` logs every HTTP request (including health polls).
- Debug-only, privacy sensitive: `log_prompt`, `log_generation_params`, `log_requests`, `log_chat_completion_requests` (writes JSON plus the templated prompt into `logs/debug/`; API keys redacted, prompts preserved). Inspect or replay with `tools/inspect_chat_request.py` and `tools/replay_chat_request.py logs/debug/<file>.json --api-key ...` (read the key from an env var).
- `network.send_tracebacks` returns tracebacks to clients; debug only.

## Per-request metrics

`timings` object in responses (prompt and generation time and rates, cache and draft counters) and `prompt_progress` chunks with `return_progress: true`; usage with `stream_options.include_usage`. See `api.md`.

## Metrics endpoint

No Prometheus `/metrics` route appears in the core, OAI or Kobold routers on 2026-10-11. For dashboards scrape `nvidia-smi` (DCGM exporter) and derive request metrics from `timings` or from the gateway (`litellm`, `llm-observability`). Optional Seq logging: `developer.seqlog`, `seqlog_server_url` (default `http://localhost:5341`), `seqlog_api_key`.

## Quick checks

```bash
curl -s -w '\n%{http_code}\n' http://127.0.0.1:5000/health
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv -l 2
```
