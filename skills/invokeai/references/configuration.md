# InvokeAI: configuration, exposure and multi-user mode

> Verified against InvokeAI v6.14.2 (docs configuration/invokeai-yaml, features/Multi-User Mode, config_default.py, api_app.py and run_app.py at tag v6.14.2), 2026-10-11

## Root and settings order

Root directory search: `--root <path>`, then `INVOKEAI_ROOT`, then the directory of the active venv, then `~/invokeai`. It holds `models/`, `outputs/`, `databases/`, `nodes/`, `style_presets/`, `configs/` and `invokeai.yaml`. Settings precedence: CLI args (only `--root` and `--config`), environment variables, `invokeai.yaml`, defaults. Any setting can be an environment variable prefixed `INVOKEAI_` (JSON for non-primitive values). An invalid value gives a `ValidationError` at start naming the setting.

```yaml
# ~/invokeai/invokeai.yaml  (keep user settings below schema_version)
host: 127.0.0.1
port: 9090
enable_partial_loading: true
```

## Defaults worth knowing (config_default.py)

| Setting                                                     | Default                     | Notes                                                                             |
| ----------------------------------------------------------- | --------------------------- | --------------------------------------------------------------------------------- |
| `host` / `port`                                             | `127.0.0.1` / `9090`        | `0.0.0.0` serves the LAN                                                          |
| `allow_origins`                                             | `[]`                        | CORS origins; `allow_credentials` true, methods and headers `*`                   |
| `ssl_certfile` / `ssl_keyfile`                              | unset                       | HTTPS through uvicorn                                                             |
| `multiuser`                                                 | `false`                     | single-user mode = no auth, full admin                                            |
| `generation_devices`                                        | `auto`                      | one concurrent session per CUDA GPU                                               |
| `enable_partial_loading`                                    | `true`                      | low-VRAM streaming                                                                |
| `device_working_mem_gb`                                     | `3`                         | VRAM reserved for compute                                                         |
| `max_cache_ram_gb` / `max_cache_vram_gb`                    | unset (dynamic)             | leave unset unless tuning                                                         |
| `max_queue_size`, `session_queue_mode`, `max_queue_history` | 10000, `round_robin`, unset | queue limits; mode `round_robin` or `FIFO`                                        |
| `allow_nodes` / `deny_nodes`                                | unset                       | restrict node types                                                               |
| `log_level`                                                 | `info`                      | `log_handlers`: `console`, `syslog=...`, `file=...`, `http=...`                   |
| `http_compression_level`                                    | `9`                         | gzip on the event loop; use `0` behind a proxy that compresses, `1` for local use |
| `remote_api_tokens`                                         | unset                       | URL regex to Bearer token for model downloads                                     |
| `patchmatch`                                                | `true`                      | inpaint helper                                                                    |
| `unsafe_disable_picklescan`                                 | off                         | never enable on shared hosts                                                      |

## Binding and exposure

- Default is loopback only. Setting `host: 0.0.0.0` (or the `INVOKEAI_HOST` variable) exposes the UI and API. In single-user mode that is an unauthenticated administrator API: do not do it on an untrusted network.
- Prefer one of: SSH tunnel or tailnet; `multiuser: true` plus HTTPS; a reverse proxy with authentication (`caddy` skill). The app has middleware for serving under a sub-path behind a proxy (root_path aware); test the UI and websockets through it. Set `http_compression_level: 0` when the proxy compresses.
- Generated images and thumbnails are fetched by unauthenticated URLs even in multi-user mode (browsers cannot send headers on `<img>`); security relies on unguessable UUID names.

## Multi-user mode

Enable with `multiuser: true` in `invokeai.yaml` and restart. The first start shows an **Administrator Setup** dialog (email, display name, strong password; a lost password cannot be retrieved, only reset by an administrator). Roles: admin and regular user, with per-user boards, images, workflows and queue items; legacy single-user content is owned by an internal `system` user that only the administrator can access. `strict_password_checking: true` enforces complexity. `session_queue_mode: round_robin` serves each user in turn; `FIFO` strictly orders jobs. CLI helpers `invoke-useradd` and `invoke-userdel` come with the package.

API behaviour changes: authenticate with `POST /api/v1/auth/login` (JSON with `email`, `password`, optional `remember_me`), then send `Authorization: Bearer <token>` on every call. The only unauthenticated routes are `GET /api/v1/auth/status`, `POST /api/v1/auth/setup`, `POST /api/v1/auth/login` and the image, thumbnail and workflow-thumbnail GETs. Tokens expire (the response carries `expires_in`, 86400 in the docs' example) and responses can refresh them through an `X-Refreshed-Token` header. Use HTTPS in production and keep tokens out of logs.

## Multi-GPU and other options

`generation_devices: [cuda:0, cuda:1]` to choose GPUs; `auto` runs one session per CUDA GPU, `CUDA_VISIBLE_DEVICES` restricts what `auto` sees; integrated GPUs are excluded when a discrete one exists. Model hashing: `hashing_algorithm: blake3_single` (default; `blake3_multi` suits SSDs).

## Check the effective values

```bash
grep -v '^\s*#' ~/invokeai/invokeai.yaml
curl -fsS 127.0.0.1:9090/openapi.json | jq '.info'      # version of the running API
env | grep '^INVOKEAI_' | sed 's/\(TOKEN\|KEY\)=.*/\1=<redacted>/'
```
