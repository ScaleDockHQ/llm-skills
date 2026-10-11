# Operating llama-swap

> Verified against llama-swap v263 (README, docs/kb observability, container-security, API keys), 2026-10-11

## Daily commands

```bash
curl -s 127.0.0.1:8080/running | jq .                         # what is loaded
curl -s 127.0.0.1:8080/upstream/<id>/health                   # engine health through the proxy (loads it)
curl -s -X POST 127.0.0.1:8080/api/models/unload              # free all memory
curl -sN 127.0.0.1:8080/logs/stream/upstream                  # engine output
journalctl -u llama-swap -f                                   # service logs
sudo systemctl restart llama-swap                             # unloads all models (runs each cmdStop), reloads config
```

Preload with one request to the model or `hooks.on_startup.preload`. Reach the UI (`/ui`) through an SSH tunnel or a private network, not a public hostname.

## Observability

- Three log streams: `proxy` (swaps, loading, errors), `upstream` (engine stdout/stderr), `http` (one access line per request). `logToStdout` selects which also go to stdout (`"proxy,http"`, `both`, `none`); default `proxy`. An invalid value such as `true` fails config loading. Restart to change it.
- Activity page: recent requests, timing, token metrics, in-flight sessions. `metricsMaxInMemory` and `captureBuffer` bound memory; `store.path` persists metrics in sqlite across restarts. Captures hold request bodies, so keep them off if prompts are sensitive.
- `/metrics` exposes Prometheus system and GPU metrics. Upstream ships an example Grafana dashboard at `docs/grafana/example-dashboard.json`.
- `logLevel: debug` for diagnosis, then back to `info`.

## Reverse proxy (nginx, Caddy)

Disable response buffering for streaming or SSE breaks:

```nginx
location /api/events      { proxy_pass http://backend; proxy_buffering off; proxy_cache off; }
location /v1/chat/completions { proxy_pass http://backend; proxy_buffering off; proxy_cache off; }
```

llama-swap also sets `X-Accel-Buffering: no` on SSE responses, but disable buffering at the proxy anyway. Raise proxy read timeouts above the longest cold load, or use `sendLoadingState: true` so the connection is never silent.

## Security

- Default is unauthenticated. `apiKeys` gates inference, `/ui` and `/api/`; it is not a firewall. llama-swap starts processes on the host, so do not expose it on a bearer token alone.
- Bind `127.0.0.1` (or a private interface) and let a gateway or tunnel front it.
- Container images run as root by default. Use `non-root` tagged images when device and file permissions allow, or Docker user-namespace remapping, and treat model files as part of the trust boundary (pickle risks).
- Keep keys in `0600` files or environment variables, referenced with `${env.NAME}`.

## Capacity checks

Before adding a model, check what is resident with `/running`, GPU or unified memory with the platform tool, and containers started outside llama-swap (`docker ps`), which hold memory it does not know about.

## Sources

- <https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/operations/observability-storage-and-activity.md>
- <https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/operations/container-security.md>
- <https://github.com/mostlygeek/llama-swap#reverse-proxy-configuration-nginx>
