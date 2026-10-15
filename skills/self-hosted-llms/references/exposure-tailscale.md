# Exposure: Tailscale Serve

> Verified against Tailscale v1.104.1 docs (tailscale serve CLI, HTTPS certificates, key expiry, Funnel; validated Jan 2026), 2026-10-11

Depth: install the tailscale skill (`npx skills add ScaleDockHQ/llm-skills --skill tailscale`). For public access
with API keys use `exposure-cloudflare.md`.

## How it plugs into this stack

`tailscale serve` terminates HTTPS on node-a's tailnet name and proxies to the Caddy catalog front. Choose it when
only you or your team use the endpoint; nothing is published unless Funnel is enabled. Expose node-a only (where
the gateway runs).

```bash
sudo tailscale serve --bg --https=443 http://127.0.0.1:8088     # after MagicDNS and HTTPS are enabled in the admin console
tailscale serve status
sudo tailscale serve --https=443 off                            # remove; `serve reset` removes everything
```

```
client --HTTPS--> node-a.<tailnet>.ts.net:443 (tailscale serve)
       --> 127.0.0.1:8088 Caddy: /v1/models from the catalog, rest --> 127.0.0.1:4000 LiteLLM
       --> 127.0.0.1:8080 llama-swap --> engines on 127.0.0.1:${PORT}
```

- Clients use `https://node-a.<tailnet>.ts.net/v1` (`clients.md`).
- **Keep LiteLLM keys on.** Every tailnet device and shared user can reach the API; keys give per-client
  revocation, budgets and logs. Virtual keys per client, never the master key (`security.md`).
- The Caddy site must accept the tailnet hostname (an address-only `:8088` site does; `model-catalog.md`).
- sparkDash on another port: `sudo tailscale serve --bg --https=8443 http://127.0.0.1:5555` (`monitoring-sparkdash.md`).
- Serve proxies only to `http://127.0.0.1` targets. Pointing it at 4000 skips Caddy and loses the enriched
  catalog; point it at 8088.
- Disable node key expiry for servers (180-day default drops an expired server from the tailnet): admin console
  Machines, Disable key expiry. Tagged devices have it disabled by default.
- Restrict reachability with the tailnet policy file; keep allow-all only for single-user tailnets.

## Stack-specific pitfalls

- With HTTPS enabled, machine names appear in public Certificate Transparency logs: rename a sensitive node first.
- Re-issuing certificates repeatedly can hit Let's Encrypt limits (waits of up to 34 hours): do not loop
  `serve reset` while debugging. Serve renews certificates itself (90-day lifetime).
- `tailscale up --force-reauth` over a tailnet SSH session can drop it; use a local console.
- Funnel (public, beta, ports 443, 8443, 10000) makes LiteLLM keys mandatory and exposes everything behind 8088;
  prefer Cloudflare Tunnel with Access for public exposure.

## Official links

- Serve CLI: https://tailscale.com/kb/1242/tailscale-serve
- HTTPS certificates: https://tailscale.com/kb/1153/enabling-https
- Key expiry: https://tailscale.com/kb/1028/key-expiry
- Funnel: https://tailscale.com/kb/1223/funnel
