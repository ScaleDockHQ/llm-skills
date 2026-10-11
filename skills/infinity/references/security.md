# Infinity security

> Verified against infinity_emb 0.0.77 (infinity_server.py, cli.py, README), 2026-10-11

- **Auth is a single shared Bearer token** (`--api-key`, `INFINITY_API_KEY`). When empty, there is no authentication at all. Generate with `openssl rand -hex 24` into a `0600` env file.
- **Unprotected routes.** `/health` and `/` (redirect to docs) never require the token. `/docs` and `/openapi.json` are FastAPI defaults; confirm with `curl` that they do not leak anything you care about, or block them at a proxy.
- **Bind narrowly.** Default host `0.0.0.0`. Publish `127.0.0.1:7997:7997`, or a private interface, and let LiteLLM hold the key.
- **No TLS.** Terminate at a proxy (`caddy`) or keep it on loopback or a tunnel.
- **`--trust-remote-code`** executes code from model repos. Keep it off unless you have reviewed the repo and pinned `--revision`.
- **CORS.** `--permissive-cors` allows every origin; leave it off.
- **Telemetry.** `INFINITY_ANONYMOUS_USAGE_STATS=0` disables anonymous usage statistics.
- **Supply chain.** Pin the image tag or digest; ROCm and TRT-ONNX images are built outside CI.
- **Gated models.** `HF_TOKEN` in the env file, read-only token, remove after caching.
