# Cloudflare Tunnel

An agent skill for publishing a self-hosted LLM endpoint through Cloudflare Tunnel (`cloudflared`): install, ingress rules, systemd service, Cloudflare Access for dashboards and service tokens for automated API callers, SSE streaming and timeout behaviour (HTTP 524, 530/1033, 502), updating and troubleshooting. It covers `cloudflared` and Cloudflare Access only. The gateway, the reverse proxy and the tailnet alternative have their own skills.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill cloudflare-tunnel
```

## Rules

- **Run it as a service.** A tunnel started with `nohup` dies silently and clients get HTTP 530.
- **Never expose raw engine ports.** Point ingress at the gateway or a loopback proxy.
- **Keys stay on.** The gateway authenticates API clients; Access protects dashboards.
- **Mind the 125 s read timeout.** Stream, or use another path for long jobs.
- **Secrets never touch output.** Credentials and tokens live in `0600` files; no debug logging in shared logs.

## References

- [`references/install.md`](references/install.md): apt, `.deb`, binaries, prerequisites.
- [`references/configuration.md`](references/configuration.md): config file, ingress, origin and run parameters, systemd.
- [`references/access-and-auth.md`](references/access-and-auth.md): Access, service tokens, `originRequest.access`.
- [`references/streaming-and-timeouts.md`](references/streaming-and-timeouts.md): SSE buffering, 524, websockets.
- [`references/observability.md`](references/observability.md): status, logs, metrics, replicas.
- [`references/updating.md`](references/updating.md): updates and zero-downtime changes.
- [`references/troubleshooting.md`](references/troubleshooting.md): error table.
- [`references/combos/caddy-catalog-front.md`](references/combos/caddy-catalog-front.md): enriched `/v1/models` through Caddy.
- [`references/combos/access-service-token-for-api.md`](references/combos/access-service-token-for-api.md): API behind Access for automated callers.
- [`assets/config.yml`](assets/config.yml): ingress template.

## Companion skills

- `tailscale`: tailnet-only access without a public hostname.
- `caddy`: loopback reverse proxy and model catalog.
- `litellm`: the authenticated gateway.
- `self-hosted-llms`: the full self-hosted stack.

## License

MIT
