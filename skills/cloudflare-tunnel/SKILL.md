---
name: cloudflare-tunnel
description: Cloudflare Tunnel (cloudflared) publishes a local LLM endpoint at a public HTTPS hostname with no open port, optionally behind Cloudflare Access. Use to install cloudflared, write ingress rules, run it under systemd, put a dashboard behind Access, give API clients service tokens, keep SSE streaming working, and fix HTTP 524, 530 or 1033, 502 and buffered streams. Not for tailnet-only access (tailscale).
license: MIT
compatibility: Linux or macOS with bash, curl and jq, and a domain on Cloudflare DNS. Needs a Cloudflare account. Installing a service, creating tunnels, DNS routes and Access policies needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Cloudflare Tunnel

A running `cloudflared` connector that carries `https://llm.example.com` from Cloudflare's edge to a loopback port on your server, with TLS at the edge, no inbound firewall hole, API clients authenticated by your gateway keys, and dashboards behind Cloudflare Access.

**Scope:** this one product: install, configure, run as a service, protect, update, troubleshoot. Tailnet-only access belongs to `tailscale`, the reverse proxy in front of the gateway to `caddy`, the gateway to `litellm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secrets.

```bash
command -v cloudflared && cloudflared --version
systemctl is-active cloudflared 2>/dev/null; systemctl is-enabled cloudflared 2>/dev/null
ls -l /etc/cloudflared ~/.cloudflared 2>/dev/null | sed 's/ [^ ]*\.json$/ <credentials>.json/'  # names and modes only
sed -E '/(token|secret|key)/I d' /etc/cloudflared/config.yml 2>/dev/null           # config without secrets
cloudflared tunnel list 2>/dev/null                                                  # needs cert.pem
ss -tlnp 2>/dev/null | grep -E ':(4000|8080|8088|11434|8000)\b'                      # what the tunnel should point at
curl -fsS https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r .tag_name
```

Ask only what discovery cannot show: hostname and zone, who calls the API (browsers, SDKs, CLIs that cannot add headers), whether any request or response takes over two minutes, locally-managed (config file) or remotely-managed (dashboard/token) tunnel.

## Decision flow

1. **No cloudflared:** install from Cloudflare's package repo or the GitHub `.deb`. -> `references/install.md`
2. **No tunnel yet:** create it, route DNS, write the ingress file, run it as a systemd service. -> `references/configuration.md`
3. **Clients are SDKs and tools using `Authorization: Bearer <key>`:** leave the API hostname without Access; the gateway enforces keys. If the hostname must sit behind Access, issue a service token. -> `references/access-and-auth.md`
4. **Dashboards or admin UIs:** Access application with an identity policy, plus `originRequest.access` to make cloudflared verify the token. -> `references/access-and-auth.md`
5. **Streaming, long requests, websockets:** SSE needs `Content-Type: text/event-stream`; the proxy read timeout is 125 s. -> `references/streaming-and-timeouts.md`
6. **Needs `/v1/models` enriched or a path-specific front:** path rule to a local Caddy. -> `references/combos/caddy-catalog-front.md`
7. **API behind Access for CI or agents:** -> `references/combos/access-service-token-for-api.md`
8. **Metrics, logs, replicas:** -> `references/observability.md`
9. **Upgrade or change config:** -> `references/updating.md`
10. **524, 530, 1033, 502, buffering, disconnects:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installing a service, `tunnel create`, DNS routes, Access applications and service tokens need approval and an undo path (`cloudflared tunnel delete`, remove the route, disable the token).
- **Run it as a service.** A `nohup` or tmux tunnel dies silently and every request then returns HTTP 530 (error 1033).
- **Never expose raw engine ports.** Ingress points only at the gateway or a loopback reverse proxy bound to `127.0.0.1`. Never vLLM, llama.cpp or Ollama directly: they have no real auth.
- **Keys stay on.** The tunnel is transport. LiteLLM virtual keys (or an Access service token) authenticate API calls.
- **Use `127.0.0.1`, not `localhost`,** in service URLs. IPv6 `::1` first gives 502.
- **Catch-all last.** The final ingress rule is `http_status:404`; rules match top to bottom and the path is forwarded unchanged.
- **Secrets never touch output.** Credentials JSON and tunnel tokens are `0600` files (or `--token-file`); never `--token <value>` on a command line, never `--loglevel debug` in shared logs (it logs request headers).
- **Verify upstream.** Versions, flags, defaults and limits come from developers.cloudflare.com and the GitHub releases at use time.

## Workflows

- [ ] Install and check the version -> `references/install.md`
- [ ] Create the tunnel, DNS route, `config.yml` from `assets/config.yml`, validate, install the service -> `references/configuration.md`
- [ ] Smoke test: `curl -sS https://llm.example.com/health/liveliness`, an authed `/v1/models`, and a streamed chat completion
- [ ] Protect dashboards with Access -> `references/access-and-auth.md`
- [ ] Verify: the unauthenticated request returns 401 from the gateway, not a login page, and the engine ports are loopback-only (`ss -tlnp`)

## Reference index

- `references/install.md`: apt, `.deb`, Homebrew, binary names for arm64 and amd64, version check.
- `references/configuration.md`: locally vs remotely managed tunnels, config file, ingress rules, origin parameters and defaults, run parameters, systemd.
- `references/access-and-auth.md`: Access applications, service tokens and headers, strict mode, `originRequest.access`, what breaks API clients.
- `references/streaming-and-timeouts.md`: SSE buffering, 524, idle timeout, websockets, QUIC vs HTTP/2.
- `references/observability.md`: logs, metrics endpoint, tunnel status, replicas.
- `references/updating.md`: auto-update rules, package updates, config changes without downtime.
- `references/troubleshooting.md`: error table.
- `references/combos/caddy-catalog-front.md`: path rule to a Caddy front for `/v1/models`.
- `references/combos/access-service-token-for-api.md`: API behind Access for automated callers.
- `assets/config.yml`: ingress template for the API host and a dashboard.

## Companion skills

- `tailscale`: tailnet-only access, no public hostname. Install: `npx skills add ScaleDockHQ/llms-skills --skill tailscale`.
- `caddy`: loopback reverse proxy, model catalog, forward auth. Install: `npx skills add ScaleDockHQ/llms-skills --skill caddy`.
- `litellm`: the authenticated gateway behind the tunnel. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `self-hosted-llms`: the full self-hosted stack that uses this tunnel. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
