# Tailscale Serve

> Verified against Tailscale v1.104.1 (docs: tailscale serve CLI page validated 2026-01-26, Tailscale Serve overview validated 2026-01-20), 2026-10-11

`tailscale serve` shares a local service with the rest of your tailnet at `https://<node>.<tailnet>.ts.net`. The Tailscale daemon terminates TLS with an automatically provisioned certificate and proxies to a local target. Serve needs HTTPS enabled for the tailnet (`https-and-magicdns.md`); run without it and the CLI prints a consent URL that offers to enable it.

## The command

```bash
sudo tailscale serve --bg --https=443 http://127.0.0.1:8088     # gateway or Caddy front
tailscale serve status                                           # add --json for scripts
sudo tailscale serve --https=443 off                             # remove one listener
sudo tailscale serve reset                                       # remove all
```

| Flag                                           | Meaning                                                                                                          |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `--bg`                                         | run in the background; resumes after reboot and `tailscale down` / `up`                                          |
| `--https=<port>`                               | HTTPS listener (default mode); `--http=<port>` serves plain HTTP (short MagicDNS name works, still tailnet-only) |
| `--set-path=<path>`                            | mount point, e.g. `/v1` (Go ServeMux style patterns)                                                             |
| `--tcp=<port>` / `--tls-terminated-tcp=<port>` | TCP forwarder, raw or TLS-terminated                                                                             |
| `--proxy-protocol=<1                           | 2>`                                                                                                              | PROXY protocol on TCP forwarding |
| `--accept-app-caps=<caps>`                     | forward app capabilities in a header (v1.92 or later)                                                            |
| `--yes`                                        | skip interactive prompts                                                                                         |

Without `--bg` the command runs in the foreground and, after a reboot or restart of Tailscale, has to be started again. With `--bg` it persists. `off` needs the original flags (target optional).

Targets: a port (`3000`), `localhost:3000`, a full URL (`http://127.0.0.1:3000`), a file or directory (open-source macOS builds only for files), or `text:<value>`. The docs state that **only `http://127.0.0.1` is supported for proxies**, which fits a loopback-only stack. They also document `https://` and `https+insecure://` targets for backends that serve TLS (the docs are not fully consistent on this: test your own variant).

## Several services, one node

Use ports or paths:

```bash
sudo tailscale serve --bg --https=443  http://127.0.0.1:8088      # API at https://node-a.<tailnet>.ts.net
sudo tailscale serve --bg --https=8443 http://127.0.0.1:5555      # dashboard at :8443
```

A port is **either** Serve (tailnet only) **or** Funnel (public): the most recent command for that port decides.

## Identity headers

For traffic from the tailnet (not Funnel), Serve adds `Tailscale-User-Login`, `Tailscale-User-Name` and `Tailscale-User-Profile-Pic` to the proxied request and strips any client-supplied copies. They are not set for traffic from **tagged** devices. Shared-device users also get headers. Because a service reachable on a LAN address could be called with forged headers, only trust them if the backend listens on `127.0.0.1` only. A backend can use them as a lightweight sign-in (Caddy `forward_auth` or the backend itself); LLM API clients still need gateway keys.

## Streaming and timeouts

SSE and long responses go through the daemon's reverse proxy. No Serve proxy read timeout is documented, unlike Cloudflare's 125 s limit; I did not find a documented buffering behaviour for SSE either (unverified: test with `curl -N`). For minutes-long non-streaming or image jobs the tailnet path is the usual workaround for Cloudflare's limits.

## What Serve is not

- Not an auth layer for APIs: every tailnet member and shared user reaches it unless the policy file narrows it (`access-control.md`).
- Not a load balancer. **Tailscale Services** (`tailscale serve --service=svc:<name>`, `get-config`, `set-config`, `drain`, `advertise`) exist for multi-host virtual services; out of scope here, see the CLI page.

## Operating

```bash
tailscale serve status
curl -sS https://node-a.<tailnet>.ts.net/health/liveliness        # gateway health, no key
curl -N -sS -K - https://node-a.<tailnet>.ts.net/v1/chat/completions -d '{"model":"<alias>","stream":true,"messages":[{"role":"user","content":"count to 20"}]}'   # headers via -K -, key from a 0600 file
```

## Official links

- [tailscale serve command](https://tailscale.com/kb/1242)
- [Tailscale Serve](https://tailscale.com/kb/1312)
- [Enabling HTTPS](https://tailscale.com/kb/1153)
- [Tailscale CLI](https://tailscale.com/kb/1080)
