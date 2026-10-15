# Caddy terminating TLS with a tailnet certificate

> Verified against Caddy v2.11.7 and Tailscale v1.104.1 (docs: Caddy certificates on Tailscale, validated 2026-01-05; Caddy tls directive), 2026-10-11

Use instead of `tailscale serve` when you want Caddy's features (auth matchers, catalog, several sites) on the tailnet name. Caddy fetches and renews the certificate from the local Tailscale daemon.

## Prerequisites

- MagicDNS and HTTPS enabled for the tailnet (`tailscale` skill: `npx skills add ScaleDockHQ/llm-skills --skill tailscale`).
- If Caddy runs as a non-root user (Debian package: `caddy`), in `/etc/default/tailscaled` set `TS_PERMIT_CERT_UID=caddy` and restart `tailscaled`.

## Caddyfile

```caddy
node-a.<tailnet>.ts.net {
	reverse_proxy 127.0.0.1:4000 {
		flush_interval -1
	}
}
```

A site name ending in `.ts.net` gets its certificate from Tailscale with no `tls` block (`get_certificate tailscale` is documented as usually unnecessary). Caddy binds 443 on all interfaces by default: add `bind <tailscale-ip>` (from `tailscale ip -4`) so it does not listen on the LAN or public addresses, or firewall it. Do not run `tailscale serve` on the same port. With `bind`, a start before `tailscaled` is up may fail; ordering after `tailscaled.service` in a systemd drop-in is the likely fix (this ordering and the `bind` setup were not tested here: unverified).

## Checks

```bash
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
curl -sS -o /dev/null -w '%{http_code}\n' https://node-a.<tailnet>.ts.net/v1/models       # 401 without a key
```

If the handshake fails with a certificate error, check HTTPS is enabled, the node name matches, and `TS_PERMIT_CERT_UID`. Do not loop restarts: repeated issuance can hit Let's Encrypt limits (up to 34 hours).

## Trade-offs

Serve renews and restarts for you and keeps Caddy on loopback with no TLS config; this combo gives one process to configure but exposes Caddy directly on the tailnet interface, so the policy file must restrict who reaches port 443.
