# TLS and certificates

> Verified against Caddy v2.11.7 (docs: tls directive, Automatic HTTPS, Caddy certificates on Tailscale validated 2026-01-05, global options), 2026-10-11

Decide first **who terminates TLS**:

| Setup                                    | TLS terminator                                            | Caddy config                                                                  |
| ---------------------------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Public or LAN site with its own DNS name | Caddy (ACME)                                              | site name = domain; ports 80 and 443 open; `assets/Caddyfile.llm-edge`        |
| Tailscale tailnet name                   | Caddy using the tailnet certificate, or `tailscale serve` | site name = `node.<tailnet>.ts.net`; see `combos/tailscale-tls.md`            |
| Cloudflare Tunnel                        | Cloudflare edge                                           | loopback site, `auto_https off`, `bind 127.0.0.1`: `assets/Caddyfile.catalog` |
| Tailscale Serve                          | tailscaled                                                | same loopback site                                                            |

## Automatic HTTPS (public name)

Naming a site by domain makes Caddy obtain and renew a certificate via ACME and redirect HTTP to HTTPS, provided DNS points at the host and ports 80 and 443 are reachable. No directive is needed. Pin the storage (`/var/lib/caddy`) in backups and do not run two Caddy instances with the same storage and different configs. The DNS challenge (for wildcard certs, or hosts not reachable on 80/443) needs a DNS provider module compiled into Caddy: not verified here, see the docs.

For a loopback-only front, turn it off globally so Caddy does not try ACME for `:8088`:

```caddy
{
	auto_https off
	admin off
}
```

## Tailnet certificates

Caddy automatically gets the certificate for any `*.ts.net` site name from the local Tailscale daemon, with no configuration (the tls docs mark `get_certificate tailscale` as usually unnecessary). Requirements: HTTPS enabled in the tailnet, the machine on the tailnet, and, if Caddy is not root, `TS_PERMIT_CERT_UID=caddy` in `/etc/default/tailscaled`. Renewal is automatic. Machine names appear in public certificate transparency logs when HTTPS is enabled.

## Internal CA

For names that are not publicly resolvable (a LAN name like `llm.lan`), use `tls internal` in the site block. Clients must trust Caddy's local root; `caddy trust` installs it on the host running Caddy, other devices need the root certificate copied (from Caddy's data directory) and trusted. Many SDKs let you set a CA bundle or `SSL_CERT_FILE` instead of disabling verification: never disable verification.

## Behind another proxy: client IPs and scheme

When cloudflared or Tailscale Serve connects over loopback, Caddy sees `X-Forwarded-*` from a private address. Trust only that range (`trusted_proxies static private_ranges` in `servers`), see `llm-reverse-proxy.md`.

## Protocols

Default `protocols h1 h2 h3`. HTTP/3 uses UDP 443: open it or ignore it. `protocols h1 h2c` style lists are valid for loopback fronts.

## Official links

- [tls directive](https://caddyserver.com/docs/caddyfile/directives/tls)
- [Automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Global options](https://caddyserver.com/docs/caddyfile/options)
- [Caddy certificates on Tailscale](https://tailscale.com/kb/1190)
