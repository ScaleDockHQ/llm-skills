# Portkey gateway: serve configuration

> Verified against Portkey AI Gateway v1.15.2 and default branch source (src/start-server.ts, src/index.ts, src/globals.ts, initializeSettings.ts, conf.example.json), 2026-10-11

## Runtime knobs

- Port: `--port=<n>` argument to `start-server.js` (default 8787). Listens through `@hono/node-server`; bind address is controlled by the container or host, so restrict it with Docker port mapping or a firewall.
- `--headless`: no static console UI and no `/public/*` routes.
- Console: `/public/` and `/public/logs`, disabled when `NODE_ENV` or `ENVIRONMENT` is `production`. In newer source, `GET /public/` returns a message unless `conf.json` has `admin_token`, and `/log/stream` needs the admin session. Released 1.15.2 packages do not include that change.
- `conf.json` in the repo root is imported at build time (`cache`, `admin_token`, `plugins_enabled`). With `FETCH_SETTINGS_FROM_FILE=true`, `initializeSettings.ts` reads `./conf.json` at runtime for `integrations`; it is not wired into the 1.x request path, and `integrations`-style provider slugs belong to the 2.0 pre-release and the hosted product. Do not rely on it for 1.15.2.
- In-memory response cache is enabled by `"cache": true` in `conf.json` at build. There is no Redis cache or semantic cache in the open-source build.

## Endpoints (OpenAI-compatible)

`/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/responses`, `/v1/messages` (Anthropic Messages), `/v1/messages/count_tokens`, `/v1/images/generations`, `/v1/images/edits`, `/v1/audio/speech`, `/v1/audio/transcriptions`, `/v1/audio/translations`, `/v1/files`, `/v1/batches`, `/v1/realtime` (WebSocket), `GET /v1/models`, `/v1/prompts/:id/completions`, plus a generic `/v1/proxy/*` passthrough. `GET /` is the liveness check.

## Request headers

| Header                                             | Meaning                                                                                               |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `Authorization: Bearer <provider key>`             | The provider API key, forwarded upstream                                                              |
| `x-portkey-provider`                               | Provider slug, for example `openai`, `anthropic`, `azure-openai`, `vertex-ai`, `ollama`               |
| `x-portkey-config`                                 | Config JSON string (hosted also accepts a saved `pc-...` ID)                                          |
| `x-portkey-custom-host`                            | Base URL for self-hosted or OpenAI-compatible backends (validated; private addresses may be rejected) |
| `x-portkey-request-timeout`                        | Timeout in milliseconds                                                                               |
| `x-portkey-retry-count`                            | Retry attempts (1 to 5)                                                                               |
| `x-portkey-cache`, `x-portkey-cache-force-refresh` | Cache mode and refresh (cache must be enabled)                                                        |
| `x-portkey-metadata`                               | JSON metadata for logs and conditional routing                                                        |
| `x-portkey-trace-id`                               | Trace correlation ID                                                                                  |
| `x-portkey-forward-headers`                        | Extra headers to forward to the provider                                                              |
| `x-portkey-strict-open-ai-compliance`              | Strict OpenAI response shape                                                                          |
| `x-portkey-api-key`                                | Portkey (hosted) API key; unused by the open-source gateway                                           |

Response headers: `x-portkey-retry-attempt-count`, `x-portkey-last-used-option-index`, `x-portkey-last-used-option-params`, `x-portkey-cache-status`, `x-portkey-trace-id`. Provider and key are required unless the config supplies them (`provider` plus `api_key`, or `strategy` plus `targets`).

## Pointing at local engines

```bash
curl -fsS http://127.0.0.1:8787/v1/chat/completions \
  -H "x-portkey-provider: openai" \
  -H "x-portkey-custom-host: http://127.0.0.1:8000/v1" \
  -H "Authorization: Bearer none" -H "Content-Type: application/json" \
  -d '{"model":"<served-model-name>","messages":[{"role":"user","content":"ping"}]}'
```

`ollama` is a first-class provider slug. For vLLM, llama.cpp, LM Studio or llama-swap use the `openai` provider with `custom_host`.

The gateway validates `custom_host` as an SSRF guard (source `isValidCustomHost`): HTTP or HTTPS only, no credentials in the URL, no `api.portkey` hosts, and it blocks private and reserved IPv4 ranges, internal TLDs and cloud metadata addresses. Hosts allowed by default are `localhost`, `127.0.0.1`, `::1` and `host.docker.internal`. For a LAN or tailnet GPU box set `TRUSTED_CUSTOM_HOSTS` (comma-separated host names or IPs, exact match) in the gateway environment, for example `TRUSTED_CUSTOM_HOSTS=localhost,127.0.0.1,gpu-box.example.ts.net`. Setting it replaces the defaults, so list `localhost` again if you still need it. Inside Docker, `127.0.0.1` is the container itself; use `host.docker.internal` or the service name (and trust it).

## Secrets

Do not write provider keys into config files that are committed or shared. Render configs from a template at deploy time with keys from the environment or a 0600 file, or send keys per request from the caller. Nothing in the gateway masks keys in configs you pass in headers, so avoid logging request headers in front proxies.

## Environment variables (gateway process)

Read at start from `src/utils/env.ts` (v1.15.2): `PORT`, `NODE_ENV`, `TRUSTED_CUSTOM_HOSTS`, `HTTP_PROXY`, `HTTPS_PROXY`, `TLS_KEY_PATH`, `TLS_CERT_PATH`, `TLS_CA_PATH` (TLS to upstream or for the server on supported runtimes; check before relying on them), `APM_LOGGER`, and provider credential variables such as `AWS_*` (Bedrock, including role assumption and web identity), `AZURE_*` (Entra, managed identity, federated token) and `KMS_*` (S3 encryption for file or batch features). Most values can also be a file path through the gateway's file-contents helper; read `src/utils/env.ts` for the exact behavior on your tag. Names only here; never print values.
