# Tailscale Serve with Ollama

> Verified against Tailscale v1.104.1, Ollama v0.40.3 (FAQ, server/routes.go at v0.40.3) and Caddy v2.11.7 (local test of the guard), 2026-10-11

Goal: reach a laptop or server's Ollama from your phone and other machines over the tailnet, with HTTPS, a token, and Ollama still bound to loopback.

## Why Ollama cannot sit directly behind Serve

- Ollama has **no authentication**. Anyone who reaches the port can run models and pull or delete them. The tailnet is not an auth boundary (every tailnet device and shared user can connect).
- Ollama binds `127.0.0.1:11434` by default (FAQ); do not change `OLLAMA_HOST` to `0.0.0.0` to "make Serve work": Serve proxies to loopback.
- When bound to loopback Ollama's host check returns **403** for any `Host` that is not `localhost`, a loopback or private IP, this machine's hostname, or `*.local`, `*.internal`, `*.localhost` (`allowedHostsMiddleware` in `server/routes.go`, present at v0.40.3). Serve forwards the request with the `*.ts.net` Host, so it gets 403. The documented Cloudflare Tunnel recipe for Ollama (`--http-host-header="localhost:11434"`) exists for the same reason. Tailscale Serve has no documented Host-rewrite option, so a small loopback Caddy fixes it and adds the token check.

## Setup

```text
client --HTTPS--> node-a.<tailnet>.ts.net:443 (tailscale serve)
       --> 127.0.0.1:8089 Caddy (bearer check, Host rewrite, no buffering)
       --> 127.0.0.1:11434 Ollama
```

1. Ollama stays on its default bind. Confirm: `ss -tlnp | grep 11434` shows `127.0.0.1:11434`.
2. Install the `caddy` skill (`npx skills add ScaleDockHQ/llms-skills --skill caddy`) and use `assets/Caddyfile.ollama-guard` there. Put `OLLAMA_PROXY_TOKEN=<random>` in a `0600` `EnvironmentFile` (generate with `openssl rand -hex 32` straight into `sudoedit`).
3. `sudo tailscale serve --bg --https=443 http://127.0.0.1:8089` and confirm `tailscale serve status`.
4. Restrict who may reach the node with a tag and grant (`access-control.md`).

## Use

```bash
( TOKEN=$(< ~/.config/ollama/proxy.token)
  printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" |
    curl -sS -K - https://node-a.<tailnet>.ts.net/v1/models | jq -r '.data[].id' )
```

Clients that speak the OpenAI API use `https://node-a.<tailnet>.ts.net/v1` and the token as the API key. For Ollama's native API use the same host with `/api/...`; both stream because the guard sets `flush_interval -1`.

## Pitfalls

- Model loading time: the first request after `OLLAMA_KEEP_ALIVE` expires reloads the model; keep-alive and preloading are Ollama settings. No Cloudflare-style 125 s cap exists on this path (no Serve timeout is documented).
- The token is one shared secret: for several users put LiteLLM in front (`litellm` skill) and keep this guard only for Ollama behind it.
- Do not also publish with Funnel: it would expose a token-only endpoint to the internet.
