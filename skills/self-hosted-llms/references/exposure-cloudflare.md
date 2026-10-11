# Exposure: Cloudflare Tunnel

> Verified against cloudflared 2026.10.0, 2026-10-11

Depth: install the cloudflare-tunnel skill (`npx skills add ScaleDockHQ/llms-skills --skill cloudflare-tunnel`).

## How it plugs into this stack

`cloudflared` runs on node-a as a systemd service (`assets/systemd/cloudflared.service`) and opens outbound
connections to Cloudflare; nothing listens publicly. Choose it for a public, key-authenticated endpoint. Choose
Tailscale (`exposure-tailscale.md`) when only your own devices need access or requests outlast the proxy
timeout and cannot stream.

Ingress in `assets/cloudflared-config.yml` (rules run top to bottom; `path` is a regex, forwarded unchanged):

1. `llm.example.com` + `path: ^/(v1/)?models/?$` -> `http://127.0.0.1:8088` (catalog front)
2. `llm.example.com` -> `http://127.0.0.1:4000` (LiteLLM)
3. `dash.example.com` -> `http://127.0.0.1:5555`, protected by an Access application
4. catch-all `http_status:404` (required, last)

Validate before restarting: `cloudflared --config /etc/cloudflared/config.yml tunnel ingress validate` and
`... tunnel ingress rule https://llm.example.com/v1/models`. Credentials file mode `600`.

- API clients use `https://llm.example.com/v1` with `Authorization: Bearer <key>`; LiteLLM checks the key. Do
  **not** put Cloudflare Access in front of the API hostname (API clients cannot do the browser login). Access
  service tokens work only with clients that can add `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers.
- Dashboards (sparkDash, the llama-swap UI) go behind Access; `originRequest.access` (`required`, `teamName`,
  `audTag`) makes cloudflared validate the token itself.
- Operate: `systemctl status cloudflared`, `journalctl -u cloudflared -f`, `cloudflared tunnel info llm-stack`.

## Timeouts (the stack-specific part)

Cloudflare closes a proxied request with **HTTP 524** when the origin sends nothing for the Proxy Read Timeout
(125 seconds by default; Enterprise can raise it). `originRequest` has no read timeout to raise. It bites on:
cold swaps of non-streaming requests, long `/v1/images/generations`, and huge non-streaming prompts.

Mitigations, in order: stream and keep llama-swap `sendLoadingState: true`; preload the models clients use
(`hooks.on_startup.preload`, `ttl: 0`); send long jobs through the tailnet; shrink image jobs on the public path.

## Stack-specific pitfalls

- Tunnel started with `nohup`: after any crash or reboot every request returns **HTTP 530** (error 1033) and
  nothing restarts it. Always the systemd service.
- Catch-all above a path rule: the catalog rule never matches and clients get the thin list.
- `localhost` vs `127.0.0.1`: if `localhost` resolves to `::1` first and the service is IPv4-only, cloudflared
  gets connection refused (502). Use `127.0.0.1`.
- Access on the API hostname returns an HTML login page instead of JSON.

## Official links

- [Configuration file](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
- [Common tunnel errors](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/troubleshoot-tunnels/common-errors/)
- [Error 524](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/error-524/)
