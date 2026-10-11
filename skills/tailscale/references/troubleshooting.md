# Troubleshooting

> Verified against Tailscale v1.104.1 (docs: Serve, Funnel, Enabling HTTPS, Key expiry, MagicDNS, CLI), Ollama server/routes.go at v0.40.3, 2026-10-11

First look: `tailscale status`, `tailscale serve status`, `tailscale ping <peer>`, `tailscale netcheck`, then the backend directly on the node (`curl -sS http://127.0.0.1:<port>/...`).

| Symptom                                                                        | Cause                                                                                                                             | Fix                                                                                                |
| ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `https://node.<tailnet>.ts.net` times out from a peer                          | policy file does not allow the port, node offline, or Serve not running                                                           | `tailscale status`; check grants and `tests`; `tailscale serve status`                             |
| `serve` prints a URL to enable HTTPS                                           | tailnet HTTPS not enabled                                                                                                         | follow the consent URL, or enable on the admin console DNS page                                    |
| Browser certificate error                                                      | HTTPS not enabled or cert not yet issued; using `https://machine-name` (no domain)                                                | use the full `*.ts.net` name; wait; check the Machines page certificate status                     |
| Cannot get certificates, wait up to 34 hours                                   | Let's Encrypt rate limit after repeated issuance                                                                                  | stop re-issuing; wait                                                                              |
| HTTP 502 / bad gateway from Serve                                              | backend not listening on the loopback target, or listens on another port                                                          | `ss -tlnp`, `curl http://127.0.0.1:<port>`; serve the right port                                   |
| HTTP 403 only when going through Serve, direct `curl 127.0.0.1` works (Ollama) | Ollama's Host-header check rejects a `.ts.net` Host when bound to loopback                                                        | put Caddy in between and set the upstream Host (`combos/tailscale-serve-ollama.md`)                |
| Clients get 401                                                                | gateway keys (correct): `Authorization: Bearer <key>` missing                                                                     | send the key                                                                                       |
| Funnel URL does not load                                                       | `funnel` node attribute missing, DNS not propagated (up to 10 min), port not 443/8443/10000, last command on the port was `serve` | `tailscale funnel status`; policy file; wait                                                       |
| Node disappears from the tailnet after ~6 months                               | node key expired (180 days default)                                                                                               | `sudo tailscale up --force-reauth` from a local console; then disable key expiry or tag the server |
| `--force-reauth` over SSH kills the session                                    | SSH rode the tailnet                                                                                                              | use another path; admins can extend the key 30 minutes                                             |
| Short name does not resolve                                                    | MagicDNS off, or macOS `host`/`nslookup`                                                                                          | enable MagicDNS; test with `ping` or `tailscale ping`                                              |
| Resolves wrongly on one Linux node                                             | local DNS conflict                                                                                                                | `tailscale set --accept-dns=false` (last resort)                                                   |
| Mac App Store build cannot serve files                                         | sandbox limits                                                                                                                    | use the open-source variant, or serve a port                                                       |
| Serve stops after reboot                                                       | Serve was started without `--bg`                                                                                                  | re-run with `--bg`                                                                                 |
| Port conflict, or a private port became public                                 | Serve and Funnel share ports; the latest command wins                                                                             | re-run `serve` for that port                                                                       |

## Direct vs relayed

`tailscale ping <peer>` shows whether traffic goes direct or through a DERP relay. Relayed paths add latency and limit throughput for large uploads; `tailscale netcheck` reports NAT and DERP latency. For GPU servers, open UDP or a stable NAT mapping helps direct connections.

## Collect before asking for help

`tailscale version`, `tailscale status` (redacted), `tailscale serve status`, the failing `curl -v` output without `Authorization` header lines, and for support `tailscale bugreport`.

## Official links

- [Tailscale Serve](https://tailscale.com/kb/1312)
- [Funnel](https://tailscale.com/kb/1223)
- [Key expiry](https://tailscale.com/kb/1028)
- [Enabling HTTPS](https://tailscale.com/kb/1153)
- [Ollama host check](https://github.com/ollama/ollama/blob/main/server/routes.go)
