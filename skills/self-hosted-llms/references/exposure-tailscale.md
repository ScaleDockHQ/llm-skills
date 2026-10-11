# Exposure: Tailscale Serve

> Verified against Tailscale v1.104.1 docs (tailscale serve CLI, HTTPS certificates, key expiry, Funnel; validated Jan 2026), 2026-10-11

Make the stack reachable from your own devices over the tailnet, with a valid HTTPS certificate and
no open ports. For public access with API keys use `exposure-cloudflare.md`.

## Tailscale

### What it is and when to choose it

A WireGuard-based mesh VPN. `tailscale serve` terminates HTTPS on the node's tailnet name
(`https://node-a.<tailnet>.ts.net`) and proxies to a loopback port. Choose it when only you or your
team (on the tailnet) use the endpoint. Nothing is published to the internet unless you enable Funnel.

### Install (DGX Spark/arm64 and generic x86)

Same command on both architectures:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale version
```

Expose one node only (normally node-a, where the gateway runs). Node-b does not need Serve.

### Minimal working config

Admin console prerequisites, once per tailnet:

1. **DNS** page: enable **MagicDNS**.
2. **HTTPS Certificates**: **Enable HTTPS** and acknowledge that machine names are published to a
   public ledger.

Then on node-a, point Serve at the Caddy catalog front:

```bash
sudo tailscale serve --bg --https=443 http://127.0.0.1:8088
tailscale serve status
```

`--bg` keeps the config running in the background; it persists across reboots and
`tailscale down`/`up`. Serve proxies only to `http://127.0.0.1` targets, which fits the loopback-only
port map. Remove it with `sudo tailscale serve --https=443 off`, or everything with
`sudo tailscale serve reset`.

### How it plugs into the stack

```
client --HTTPS--> node-a.<tailnet>.ts.net:443 (tailscale serve)
       --> 127.0.0.1:8088 Caddy: /v1/models from the catalog, rest --> 127.0.0.1:4000 LiteLLM
       --> 127.0.0.1:8080 llama-swap --> engines on 127.0.0.1:${PORT}
```

- Clients use `https://node-a.<tailnet>.ts.net/v1` as base URL (see `clients.md`).
- **Keep LiteLLM keys on.** The tailnet is not an auth boundary for the API: every tailnet device and
  shared user can reach it, and keys give you per-client revocation, budgets and logs. Use virtual
  keys per client, never the master key (see `security.md`).
- The Caddy site must accept the tailnet hostname (an address-only `:8088` site does); see
  `model-catalog.md`.
- To also reach sparkDash, serve it on another HTTPS port, e.g.
  `sudo tailscale serve --bg --https=8443 http://127.0.0.1:5555` (see `monitoring-sparkdash.md`).

### Operating

```bash
tailscale status                  # peers and this node's state
tailscale serve status            # active serve config (add --json for scripts)
curl -sS https://node-a.<tailnet>.ts.net/health/liveliness   # LiteLLM, no auth needed
```

Certificates: Let's Encrypt certificates last 90 days. Serve obtains and renews them automatically.
Only certificates you fetch yourself with `tailscale cert` need manual renewal.

### Tuning knobs

- **Key expiry**: node keys expire after 180 days by default, and an expired server drops off the
  tailnet. For servers, disable it: admin console **Machines** -> the node's menu -> **Disable key
  expiry**. Tagged devices have key expiry disabled by default. The Device management page also
  allows a custom period of 1-180 days.
- **Access**: restrict which users/devices may reach node-a with the tailnet policy file
  (grants/ACLs); keep the default allow-all only for single-user tailnets.
- **Machine name**: rename the node before enabling HTTPS if the current name is sensitive.

### Known pitfalls

- **Names become public.** With HTTPS enabled, machine names appear in Certificate Transparency
  logs. Do not enable it if a machine name reveals something sensitive; rename first.
- **Rate limits.** Repeatedly re-issuing certificates can hit Let's Encrypt limits and force a wait
  of up to 34 hours. Do not loop `serve reset` / re-enable while debugging.
- **Re-auth over SSH.** `tailscale up --force-reauth` renews the key but can drop your SSH session
  if you are connected over the tailnet. Use a local console or another path.
- **Wrong target.** The Serve docs state that only `http://127.0.0.1` is supported for proxies; use
  the full loopback URL, not a LAN IP.
- **Bypassing the catalog.** Pointing Serve at 4000 skips Caddy, so `/v1/models` loses the enriched
  catalog. Point it at 8088.

## Tailscale Funnel (public access, optional)

Funnel publishes a Serve target to the public internet. Use it only if you want public access and
do not use Cloudflare. It is in beta, disabled by default, listens only on ports 443, 8443 and
10000, and the first `tailscale funnel` run prompts you to approve enabling it. It uses the same
target syntax as `tailscale serve`.

With Funnel the endpoint is public: LiteLLM keys become mandatory, and anything behind 8088 is
reachable by anyone. For public exposure prefer Cloudflare Tunnel with Cloudflare Access in front
of dashboards (`exposure-cloudflare.md`).

## Official links

- Serve CLI: https://tailscale.com/kb/1242/tailscale-serve
- HTTPS certificates: https://tailscale.com/kb/1153/enabling-https
- Key expiry: https://tailscale.com/kb/1028/key-expiry
- Funnel: https://tailscale.com/kb/1223/funnel
