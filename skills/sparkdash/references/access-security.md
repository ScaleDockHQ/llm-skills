# sparkDash: access, security and privacy

> Verified against sparkDash v2.32.0 (README Security, `docs/REMOTE-ACCESS.md`), 2026-10-11

The application API has no login of its own in this release. Safety comes from the bind address, an optional bearer token and your front door.

## Auth modes

`GET /api/health` reports `authMode`:

| Mode               | Meaning                                                                               |
| ------------------ | ------------------------------------------------------------------------------------- |
| `loopback-open`    | Loopback only; any local process can use mutations including power                    |
| `bearer`           | `SPARKDASH_TOKEN` set and required                                                    |
| `open-remote`      | Non-loopback bind without a token: open to anyone who can reach the port              |
| `required-missing` | Non-loopback bind with `SPARKDASH_ALLOW_OPEN_REMOTE=0` and no token: refuses to start |

Upstream docs are not fully consistent: the `.env.example` and REMOTE-ACCESS say direct LAN binds fail closed, while the README says a tokenless LAN bind is open by default (`SPARKDASH_ALLOW_OPEN_REMOTE=1`). Do not rely on either; set the token and `=0`, then read `authMode`.

## Remote viewing, in order of preference

```bash
ssh -N -L 5555:127.0.0.1:5555 llm@node-a                       # then http://127.0.0.1:5555 locally
sudo tailscale serve --bg --https=8443 http://127.0.0.1:5555    # tailnet only; undo: --https=8443 off
tailscale serve status
```

- The Tailscale name works without `SPARKDASH_ALLOWED_HOSTS`. Do not take port 443 if something else uses it.
- A reverse proxy on a custom domain must require authentication on every path, proxy `/api/*` and `/ws` with WebSocket upgrades, and its domain must be in `SPARKDASH_ALLOWED_HOSTS`. TLS without authentication is not enough. Cloudflare: put Cloudflare Access in front (`cloudflare-tunnel` skill).
- Funnel (public) is not recommended.
- Recover from an accidental LAN bind: `BIND_HOST=127.0.0.1 docker compose up -d --force-recreate`.

## What is stored and exposed

- SSH passwords: AES-256-GCM in `config/sparks-secrets.json`; key in `config/.secrets-key` or `SPARKDASH_SECRETS_KEY`. Prefer SSH keys, mounted read-only.
- Telemetry shows hostnames, IPs, model names, process names and token counts. It does not capture prompts unless **Save benchmark debug traces** is on, which stores prompts in bench history.
- `/api/sparks/:id/metrics` is as open as the rest of the API; a widget such as Glance reading it needs the same protection.
- The container is privileged with host PID and root filesystem mounts: a compromise of the dashboard is a compromise of the host.

## Privacy checklist

- [ ] `authMode` is `loopback-open` or `bearer`.
- [ ] Debug traces off unless benchmarking, and bench history cleared after.
- [ ] `config/` mode and backups restricted; `.secrets-key` stored with the backup but apart from it.
- [ ] Power helper sudo scoped to one path.

## Official links

- Remote access: https://github.com/MiaAI-Lab/sparkDash/blob/main/docs/REMOTE-ACCESS.md
- Tailscale Serve: https://tailscale.com/kb/1242/tailscale-serve
