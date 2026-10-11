# MagicDNS, HTTPS certificates and `tailscale cert`

> Verified against Tailscale v1.104.1 (docs: MagicDNS validated 2026-01-05, Enabling HTTPS validated 2025-12-10, Caddy certificates on Tailscale validated 2026-01-05, CLI cert), 2026-10-11

## MagicDNS

Registers a DNS name for every device: `<machine-name>.<tailnet-name>.ts.net`, plus search domains so the short machine name works. Tailnets created on or after 2022-10-20 have it on; otherwise enable it on the admin console DNS page. Rename a machine in the admin console and the name follows. Shared devices are reachable only by the full name. On macOS `host` and `nslookup` bypass system DNS and will not resolve MagicDNS names; `ping` works. To stop one Linux node from accepting tailnet DNS settings: `tailscale set --accept-dns=false`. The legacy `*.beta.tailscale.net` names ended on 2024-09-13.

## Enable HTTPS (once per tailnet)

1. Admin console > DNS: enable MagicDNS.
2. Under HTTPS Certificates select **Enable HTTPS** and acknowledge that machine names and the tailnet DNS name are published in the public Certificate Transparency ledger.
3. Rename any machine whose name reveals something sensitive **before** a certificate is issued. The tailnet name itself can be the default or a random name (like `yak-bebop.ts.net`); other changes are not permitted.

Disabling HTTPS later does not revoke certificates and breaks links that rely on it.

## Certificates

- Let's Encrypt via DNS-01; Tailscale creates a `*.ts.net` DNS TXT record for the node to complete the challenge. Private keys and the ACME account key stay on your machine.
- Valid 90 days. **`tailscale serve` and the Caddy integration renew automatically.** Certificates you fetch with `tailscale cert` are files on disk, so you must renew them yourself.
- Repeated issuance can hit Let's Encrypt rate limits and force a wait of up to 34 hours. Do not loop `serve reset` or `tailscale cert` while debugging.
- Certificate status per machine is visible on the admin console Machines page (clients v1.56 or later, machine online).

```bash
sudo tailscale cert node-a.<tailnet>.ts.net                                   # writes <name>.crt and <name>.key in the current dir
sudo tailscale cert --cert-file=/etc/ssl/ts.crt --key-file=/etc/ssl/ts.key node-a.<tailnet>.ts.net
```

Use `tailscale cert` only when something other than `tailscale serve` terminates TLS. Docs advise `tailscale serve` if you just proxy to an HTTP service. Set key files to `0600`, owned by the service user, and renew before 90 days (a systemd timer running the same command). The renewal tool for keys on disk is the same command; re-running it fetches a new certificate.

## Caddy gets tailnet certificates automatically

Since Caddy 2.5, a site named `node-a.<tailnet>.ts.net` gets its certificate from the local Tailscale daemon with no configuration, and renews it. If Caddy runs as a non-root user (the Debian package uses `caddy`), set in `/etc/default/tailscaled`:

```text
TS_PERMIT_CERT_UID=caddy
```

then restart `tailscaled`. This lets you use Caddy instead of `tailscale serve` as the TLS-terminating front on port 443 (see the `caddy` skill and `combos/tailscale-serve-caddy-litellm.md`). If Caddy listens on 443 on the tailnet address, do not also run Serve on 443.

## Names and bare hostnames

`https://machine-name` (no domain) never has a valid certificate: HTTPS works only on the full `*.ts.net` name. `http://machine-name` works over MagicDNS without TLS.

## Official links

- [MagicDNS](https://tailscale.com/kb/1081)
- [Enabling HTTPS](https://tailscale.com/kb/1153)
- [Caddy certificates on Tailscale](https://tailscale.com/kb/1190)
- [Tailscale CLI: cert](https://tailscale.com/kb/1080)
