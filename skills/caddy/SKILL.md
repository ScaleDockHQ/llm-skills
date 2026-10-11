---
name: caddy
description: Caddy is a web server and reverse proxy with automatic HTTPS, used as a loopback front for LLM endpoints. Use to install it, write a Caddyfile that proxies to LiteLLM, vLLM or Ollama with SSE streaming and long timeouts, add bearer or forward_auth checks, serve an enriched /v1/models catalog, terminate TLS with tailnet or Let's Encrypt certs, and fix 502, 403 and buffered-stream errors. Not for tunnels (cloudflare-tunnel, tailscale).
license: MIT
compatibility: Linux or macOS with bash, curl and jq (the catalog builder needs jq). Installing packages, opening ports 80 and 443, systemd units and TLS or auth changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Caddy

A Caddy instance in front of an LLM gateway or engine that keeps streaming responses live, applies timeouts and auth checks, hides engine quirks (Host header, buffering), and optionally serves a richer `/v1/models` list than the gateway does.

**Scope:** this one product: install, Caddyfile for LLM endpoints, TLS, auth patterns, model catalog, update, troubleshoot. Choosing a gateway belongs to `llm-gateway`, running one to `litellm`, publishing without open ports to `cloudflare-tunnel` and `tailscale`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secrets.

```bash
command -v caddy && caddy version
systemctl is-active caddy 2>/dev/null; systemctl is-enabled caddy 2>/dev/null
ls -l /etc/caddy /etc/llm-stack 2>/dev/null
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1 | tail -1
ss -tlnp 2>/dev/null | grep -E ':(80|443|2019|4000|8000|8080|8088|11434)\b'    # who listens where
curl -fsS https://api.github.com/repos/caddyserver/caddy/releases/latest | jq -r .tag_name
```

Ask only what discovery cannot show: what Caddy fronts (gateway, engine, Ollama), who calls it (browser, SDK, other proxy), whether TLS terminates here or upstream (tunnel, Tailscale Serve), and whether `/v1/models` needs enriching.

## Decision flow

1. **Not installed:** official apt repo, `.deb`, binary or Docker image. -> `references/install.md`
2. **Reverse-proxy a gateway or engine:** `reverse_proxy` with `flush_interval -1`, sane timeouts, body size. -> `references/llm-reverse-proxy.md`
3. **TLS here:** public name (ACME), tailnet name (`*.ts.net`, no config), or internal CA; or none because a tunnel terminates TLS. -> `references/tls.md`
4. **Add auth in front of an engine that has none (Ollama, llama.cpp):** bearer matcher or `forward_auth`. -> `references/auth.md`
5. **Clients show wrong dates or context in the model picker:** serve an enriched catalog. -> `references/model-catalog.md`
6. **Ollama behind Serve or a tunnel returns 403:** Host-header fix. -> `references/combos/forward-auth-llm.md` (and `assets/Caddyfile.ollama-guard`)
7. **Reload, update, logs, metrics:** -> `references/operations.md`
8. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Package installs, ports 80/443, systemd edits and certificate or auth changes need approval and an undo path (the previous Caddyfile, `systemctl stop caddy`).
- **Bind to loopback unless Caddy is the public edge.** Site blocks behind a tunnel or Serve use `bind 127.0.0.1` and `auto_https off`. Never expose the admin API (`localhost:2019` default; `admin off` for single-purpose loopback fronts).
- **Never expose raw engine ports.** Engines listen on `127.0.0.1`; only Caddy (or a tunnel) reaches them.
- **Stream, don't buffer.** `flush_interval -1` on every LLM `reverse_proxy`; no `request_buffers` or `response_buffers`.
- **Keys stay with the gateway.** Caddy checks keys by asking the gateway (`forward_auth`) or checks one shared token for engines with none. It does not store per-client keys.
- **Secrets stay out of Caddyfiles.** Use `{$ENV_VAR}` with a `0600` `EnvironmentFile`; hash passwords (`caddy hash-password`); Caddy logs `Authorization` as REDACTED by default, so never enable `log_credentials`.
- **Validate before reload.** `caddy fmt`, `caddy validate`, then `systemctl reload caddy`.
- **Verify upstream.** Directive names, defaults and versions come from caddyserver.com/docs and the GitHub releases at use time.

## Workflows

- [ ] Install and check `caddy version` -> `references/install.md`
- [ ] Pick a template from `assets/` (`Caddyfile.llm-edge`, `Caddyfile.catalog`, `Caddyfile.ollama-guard`), edit names and ports
- [ ] `caddy validate --config <file> --adapter caddyfile`, then install and `systemctl reload caddy`
- [ ] Smoke test: unauthenticated request returns 401, authenticated `/v1/models` returns the list, and a `stream: true` completion arrives token by token (`curl -N`)
- [ ] Verify: engine ports bound to `127.0.0.1` only (`ss -tlnp`), Caddy admin not exposed

## Reference index

- `references/install.md`: apt repo, `.deb`, Docker, systemd units, environment files.
- `references/llm-reverse-proxy.md`: streaming, timeouts, body size, websockets, headers, health checks.
- `references/tls.md`: automatic HTTPS, `*.ts.net` certificates, behind a tunnel, trusted proxies.
- `references/auth.md`: bearer matcher, `basic_auth`, `forward_auth`, Tailscale identity.
- `references/model-catalog.md`: enriched `/v1/models`, builder script, client fields.
- `references/operations.md`: reload, logs, metrics, update, rollback.
- `references/troubleshooting.md`: error table.
- `references/combos/forward-auth-llm.md`: forward_auth against LiteLLM and a bearer guard for Ollama.
- `references/combos/tailscale-tls.md`: Caddy terminating TLS with a tailnet certificate.
- `assets/`: Caddyfile templates, `build-catalog.sh`, `catalog.example.json`, `llm-catalog.service`.

## Companion skills

- `litellm`: the gateway Caddy usually fronts. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `cloudflare-tunnel`: public hostname without open ports. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloudflare-tunnel`.
- `tailscale`: tailnet access and certificates. Install: `npx skills add ScaleDockHQ/llms-skills --skill tailscale`.
- `llm-clients`: how clients read `/v1/models`. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`.
- `self-hosted-llms`: the full self-hosted stack that uses these pieces. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
