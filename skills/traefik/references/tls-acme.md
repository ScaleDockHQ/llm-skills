# Traefik: TLS and Let's Encrypt

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: reference "Certificate Resolvers: ACME", "EntryPoints" redirections.

```yaml
certificatesResolvers:
  le:
    acme:
      email: you@example.com
      storage: /data/acme.json # default acme.json; chmod 600, persistent volume
      # caServer: https://acme-staging-v02.api.letsencrypt.org/directory   # test first
      tlsChallenge: {} # needs 443 reachable from the internet
      # httpChallenge: { entryPoint: web }   # needs 80 reachable
      # dnsChallenge: { provider: <name> }   # wildcard certs; token via env or file
```

- `acme.email` is required. Default CA is Let's Encrypt production (`https://acme-v02.api.letsencrypt.org/directory`).
- Pick one challenge: TLS-ALPN-01 (443), HTTP-01 (entrypoint reachable on port 80), DNS-01 (needed for wildcards and for hosts not reachable from the internet; provider credentials via environment variables from the provider's lego page).
- Attach with `tls.certResolver: le` on the router; add `tls.domains` for wildcards.
- HTTP to HTTPS: entrypoint `http.redirections.entryPoint` (`to`, `scheme`, `permanent`).
- Private hosts (tailnet only) cannot use HTTP or TLS challenges; use DNS-01, or the Tailscale resolver page in the ACME docs, or bring your own certificates via the dynamic `tls.certificates` file section.
- Rate limits of the CA apply; switch to staging while testing, then delete `acme.json` entries when going to production.

Check: `jq -r 'to_entries[]|.value.Certificates[]?.domain.main' /data/acme.json` (names only; the file also holds private keys, never print it).
