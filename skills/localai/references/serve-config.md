# Serve and configure LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

`local-ai run [MODEL_URL_OR_NAME ...]` starts the server. Every flag has a `LOCALAI_*` environment variable (many also a legacy un-prefixed name). Confirm with `local-ai run --help`.

## Core settings

| Setting                                               | Env var                                          | Default                  |
| ----------------------------------------------------- | ------------------------------------------------ | ------------------------ |
| Bind address                                          | `LOCALAI_ADDRESS`                                | `:8080`                  |
| Models dir                                            | `LOCALAI_MODELS_PATH`                            | `<base>/models`          |
| Backends dir                                          | `LOCALAI_BACKENDS_PATH`                          | `<base>/backends`        |
| Config dir (`api_keys.json`, `runtime_settings.json`) | `LOCALAI_CONFIG_DIR`                             | `<base>/configuration`   |
| Data dir                                              | `LOCALAI_DATA_PATH`                              | `<base>/data`            |
| Threads                                               | `LOCALAI_THREADS`                                | auto; use physical cores |
| Default context size                                  | `LOCALAI_CONTEXT_SIZE`                           | per model                |
| Preload models                                        | `LOCALAI_MODELS` (list of URLs or names)         | none                     |
| Galleries                                             | `LOCALAI_GALLERIES`, `LOCALAI_BACKEND_GALLERIES` | upstream galleries       |
| Disable web UI                                        | `LOCALAI_DISABLE_WEBUI`                          | `false`                  |
| Debug logs                                            | `DEBUG=true` or `--log-level=debug`              | off                      |
| Upload limit (MB)                                     | `LOCALAI_UPLOAD_LIMIT`                           | `15`                     |
| Hugging Face token                                    | `HF_TOKEN`                                       | unset                    |

Models preloaded on the command line or via `LOCALAI_MODELS` are gallery names, config URLs, `huggingface://`, `oci://` or `ollama://` style URIs.

## Authentication

Simple API keys:

```bash
# keys come from a 0600 env file; never inline them
LOCALAI_API_KEY=key1,key2 local-ai run
```

Clients may send `Authorization: Bearer <key>`, `x-api-key: <key>` or `xi-api-key: <key>`. Keys can also live in `<config dir>/api_keys.json` and are picked up without restart. With keys set, all requests need one; health probes (`/healthz`, `/readyz`) stay open.

Optional hardening flags:

- `LOCALAI_SUBTLE_KEY_COMPARISON=true`: constant-time key comparison.
- `LOCALAI_OPAQUE_ERRORS=true`: blank 500 for every error (hides detail; makes debugging hard).
- `LOCALAI_DISABLE_API_KEY_REQUIREMENT_FOR_HTTP_GET`: lets GETs on UI paths skip the key. Testing only.
- `LOCALAI_REQUIRE_BACKEND_INTEGRITY=true`: reject backend installs without a signature policy or SHA256.
- `LOCALAI_DISABLE_PREDOWNLOAD_SCAN`: disables the best-effort scan before downloads; leave it off.

User accounts (UI login, roles, per-user API keys and usage): `LOCALAI_AUTH=true`, optionally with GitHub OAuth (`GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`) or OIDC (`LOCALAI_OIDC_ISSUER`, `LOCALAI_OIDC_CLIENT_ID`, `LOCALAI_OIDC_CLIENT_SECRET`). Related: `LOCALAI_ADMIN_EMAIL` (auto-promote), `LOCALAI_REGISTRATION_MODE` (`open`, `approval`, `invite`), `LOCALAI_DISABLE_LOCAL_AUTH`, `LOCALAI_DEFAULT_API_KEY_EXPIRY`, `LOCALAI_AUTH_DATABASE_URL` (SQLite file or `postgres://`). Keep secrets in an env file with mode `0600`.

## Bind safety

The server refuses to start when bound to a public-internet address with no authentication configured. Loopback and private addresses are allowed. Fix it by setting auth or binding to a private address; `--allow-insecure-public-bind` (`LOCALAI_ALLOW_INSECURE_PUBLIC_BIND`) exists only for setups where an upstream proxy enforces auth. A wildcard bind on a host with any public interface counts as public.

## TLS and reverse proxy

LocalAI does not terminate TLS. Put Caddy, nginx, HAProxy or a tunnel in front.

- Set `LOCALAI_BASE_URL=https://localai.example.com`: authoritative for generated links (images, video, job status) and OAuth callbacks.
- Otherwise forward `X-Forwarded-Proto`, `X-Forwarded-Host` and, for a subpath, `X-Forwarded-Prefix`.
- Streaming responses: disable proxy buffering and raise read timeouts.
- CORS: `LOCALAI_CORS=true` with `LOCALAI_CORS_ALLOW_ORIGINS`. CSRF middleware is on by default (`LOCALAI_DISABLE_CSRF` turns it off).

Skills: `caddy` for the proxy (`npx skills add ScaleDockHQ/llms-skills --skill caddy`).

## Socket activation

systemd can hold port 8080 and start LocalAI on first connection: a `local-ai.socket` with `ListenStream=8080` and a matching `local-ai.service` that runs `local-ai run`. Enable the socket, not the service. `--address` is ignored while an inherited listener is present, and multiple stream listeners are rejected.

## Model YAML

Each model has `<name>.yaml` in the models dir. See `references/models-and-formats.md` and `templates/model.yaml`.

## Runtime settings

The web UI Settings page persists values to `<config dir>/runtime_settings.json`. `LOCALAI_DISABLE_RUNTIME_SETTINGS=true` ignores it so flags and env vars win.
