# Traefik Skill

An agent skill for [Traefik Proxy](https://github.com/traefik/traefik) as the TLS and auth front of self-hosted LLM endpoints. It covers Docker Compose and file-provider installs, routers, services and middlewares (forwardAuth, basicAuth, ipAllowList, rateLimit), Let's Encrypt certificates, streaming-safe settings for SSE and long requests, logs and Prometheus metrics, v2 to v3 and minor upgrades, and troubleshooting 404, 502 and 504. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill traefik
```

## Rules

- **Ask before changing the system.** Exposure, Docker socket and certificates need approval.
- **Never enable `api.insecure` in production.**
- **The Docker socket is root-equivalent.** `exposedByDefault=false`.
- **Pin the image tag.**
- **LLM routes stream.** No buffering, no write timeout.
- **`acme.json` is `0600`.**
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): Compose, binary, hardening.
- [`references/serve-config.md`](references/serve-config.md): static config, entrypoints, timeouts.
- [`references/routing-and-providers.md`](references/routing-and-providers.md): routers, services, providers.
- [`references/middlewares-auth.md`](references/middlewares-auth.md): auth, allowlists, limits.
- [`references/tls-acme.md`](references/tls-acme.md): certificate resolvers.
- [`references/llm-reverse-proxy.md`](references/llm-reverse-proxy.md): streaming and long requests.
- [`references/observability.md`](references/observability.md): logs, metrics, health.
- [`references/updating.md`](references/updating.md): support, migration, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

Templates: [`templates/docker-compose.yml`](templates/docker-compose.yml), [`templates/traefik.yml`](templates/traefik.yml), [`templates/dynamic-llm.yml`](templates/dynamic-llm.yml).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

`caddy`, `cloudflare-tunnel`, `tailscale`, `choosing-llm-hosting`, `litellm`, `llama-swap`, `vllm`, `ollama`, `llm-gateway`.

## License

MIT
