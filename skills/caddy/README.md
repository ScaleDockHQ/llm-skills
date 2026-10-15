# Caddy

An agent skill for using Caddy as the front of a self-hosted LLM endpoint: install, a Caddyfile that keeps SSE and NDJSON streams live with long timeouts, TLS (public, tailnet or behind a tunnel), auth in front of engines that have none, `forward_auth` against the gateway, an enriched `/v1/models` catalog, operations and troubleshooting. Templates were validated with Caddy v2.11.7.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill caddy
```

## Rules

- **Loopback unless public edge.** Fronts behind a tunnel or Serve bind `127.0.0.1` with `auto_https off`.
- **Stream, don't buffer.** `flush_interval -1`, no request or response buffers.
- **Keys stay with the gateway.** Caddy asks the gateway or checks one shared token for engines without auth.
- **Secrets stay out of Caddyfiles.** `{$ENV}` from a `0600` file; never enable `log_credentials`.
- **Validate before reload.**

## References

- [`references/install.md`](references/install.md): apt, `.deb`, Docker, systemd.
- [`references/llm-reverse-proxy.md`](references/llm-reverse-proxy.md): streaming, timeouts, body size, websockets, headers.
- [`references/tls.md`](references/tls.md): automatic HTTPS, tailnet certificates, internal CA.
- [`references/auth.md`](references/auth.md): bearer, `basic_auth`, `forward_auth`.
- [`references/model-catalog.md`](references/model-catalog.md): enriched `/v1/models`.
- [`references/operations.md`](references/operations.md): reload, logs, metrics, update.
- [`references/troubleshooting.md`](references/troubleshooting.md): error table.
- [`references/combos/forward-auth-llm.md`](references/combos/forward-auth-llm.md): gateway check and Ollama guard.
- [`references/combos/tailscale-tls.md`](references/combos/tailscale-tls.md): tailnet certificate on Caddy.
- [`assets/`](assets/): Caddyfile templates, catalog builder, systemd unit.

## Companion skills

- `litellm`: the gateway Caddy fronts.
- `cloudflare-tunnel`: public hostname without open ports.
- `tailscale`: tailnet access and certificates.
- `llm-clients`: how clients read `/v1/models`.
- `self-hosted-llms`: the full self-hosted stack.

## License

MIT
