# Tailscale Serve with a Caddy catalog front and LiteLLM

> Verified against Tailscale v1.104.1 and Caddy v2.11.7 (local test of the catalog front with a mock gateway), 2026-10-11

Goal: one HTTPS name on the tailnet that serves an enriched `/v1/models`, proxies everything else to the gateway, and keeps gateway keys as the only credential.

```text
client --HTTPS--> node-a.<tailnet>.ts.net:443 (tailscale serve)
       --> 127.0.0.1:8088 Caddy: /v1/models from the catalog, everything else --> 127.0.0.1:4000 gateway
       --> engines on 127.0.0.1:<port>
```

## Steps

1. Gateway and engines bind `127.0.0.1` (`scripts/check-exposure.sh` verifies).
2. Install the `caddy` skill (`npx skills add ScaleDockHQ/llm-skills --skill caddy`) and set up the catalog front from its `assets/` and `references/model-catalog.md`.
3. Enable MagicDNS and HTTPS for the tailnet (`https-and-magicdns.md`), then:

   ```bash
   sudo tailscale serve --bg --https=443 http://127.0.0.1:8088
   tailscale serve status
   ```

4. Tag the node and grant `tcp:443` to your users only (`access-control.md`). Disable key expiry for the server.
5. Smoke test:

   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' https://node-a.<tailnet>.ts.net/v1/models      # expect 401
   curl -sS https://node-a.<tailnet>.ts.net/health/liveliness                                # gateway health, if it exposes one
   ```

   Then an authenticated `/v1/models` (key via `curl -K -` from a `0600` file) and a streamed completion with `curl -N`.

## Notes

- **Keys stay on.** The tailnet is not an auth boundary for the API; use one virtual key per client, never the master key.
- **Point Serve at 8088, not 4000**, or `/v1/models` loses the enriched catalog.
- Dashboards: serve them on another port, for example `sudo tailscale serve --bg --https=8443 http://127.0.0.1:5555`. Tailscale identity headers can identify tailnet users to the backend if it listens on loopback only.
- Alternative: let Caddy terminate TLS with the tailnet certificate instead of Serve (see the `caddy` skill, `combos/tailscale-tls.md`). Do not run both on port 443.
- Over a public path (Cloudflare Tunnel) the same Caddy front is reached via a path rule instead of Serve (`cloudflare-tunnel` skill).
