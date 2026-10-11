---
name: tailscale
description: Tailscale gives your devices a private WireGuard network and publishes a local LLM endpoint as https://node.tailnet.ts.net via Serve, or to the internet via Funnel. Use to install, set up MagicDNS and HTTPS certificates, run `tailscale serve`/`funnel`/`cert`, restrict access with tags, ACLs and grants, avoid key expiry on servers, and fix 502, cert and DNS errors. Not for public hostnames with Access (cloudflare-tunnel).
license: MIT
compatibility: Linux, macOS or Windows with bash, curl and jq for the helper script. Needs a Tailscale account. Installing the client, enabling HTTPS or Funnel, editing the tailnet policy file and disabling key expiry need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Tailscale

A tailnet where your laptop, phone and GPU servers reach each other by name, and the LLM gateway is served at `https://node-a.<tailnet>.ts.net` with a valid certificate and no open port. Funnel is the optional public route.

**Scope:** this one product: install, Serve, Funnel, MagicDNS, certificates, access policy, key expiry, update, troubleshoot. Public hostnames with Access policies belong to `cloudflare-tunnel`, the reverse proxy in front of the gateway to `caddy`, the gateway to `litellm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints auth keys.

```bash
command -v tailscale && tailscale version | head -2
tailscale status 2>&1 | head -15                                   # peers and state
tailscale serve status 2>&1; tailscale funnel status 2>&1          # what is published, and to whom
tailscale status --json 2>/dev/null | jq '{BackendState, Self: {HostName: .Self.HostName, DNSName: .Self.DNSName, Tags: .Self.Tags, KeyExpiry: .Self.KeyExpiry}, MagicDNSSuffix: .MagicDNSSuffix}'
ss -tlnp 2>/dev/null | grep -E ':(4000|8080|8088|8000|11434)\b'    # engine and gateway binds: all 127.0.0.1?
curl -fsS https://api.github.com/repos/tailscale/tailscale/releases/latest | jq -r .tag_name
```

Ask only what discovery cannot show: who must reach the endpoint (only you, a team, other people's devices), whether the tailnet is shared with untrusted users or devices, which node serves, whether you have admin access to the admin console and policy file.

## Decision flow

1. **Not installed:** official install script or package. -> `references/install.md`
2. **Only your own devices need the endpoint:** `tailscale serve` to the loopback gateway or Caddy front. -> `references/serve.md`
3. **HTTPS not enabled for the tailnet:** admin console DNS page, MagicDNS and Enable HTTPS, then `tailscale serve` or `tailscale cert`. -> `references/https-and-magicdns.md`
4. **Public access without Cloudflare is really needed:** Funnel, with gateway keys mandatory. -> `references/funnel.md`
5. **More than one person or device on the tailnet:** tags, grants or ACLs, tests in the policy file. -> `references/access-control.md`
6. **Server drops off after months:** node key expiry; tag the server or disable expiry. -> `references/access-control.md`
7. **Ollama or llama.cpp behind Serve:** Ollama returns 403 on foreign Host headers. -> `references/combos/tailscale-serve-ollama.md`
8. **Gateway plus catalog front over the tailnet:** -> `references/combos/tailscale-serve-caddy-litellm.md`
9. **Upgrade or downgrade:** -> `references/updating.md`
10. **Errors:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, `tailscale up`, enabling HTTPS or Funnel, policy file edits and key-expiry changes need approval and an undo path (`tailscale serve --https=443 off`, `tailscale serve reset`).
- **The tailnet is not the API's auth boundary.** Every device and shared user reaches the endpoint. Keep gateway keys on, per client.
- **Serve targets loopback only.** The docs say only `http://127.0.0.1` is supported for proxies. Never serve a raw engine port; point at the gateway or a loopback Caddy front, and keep engines on `127.0.0.1`.
- **Funnel is public.** A port is private after `serve`, public after `funnel`; the last command wins. Funnel traffic carries no identity headers and has non-configurable bandwidth limits.
- **Disable key expiry on servers** (or authenticate them with a tag), or they leave the tailnet after the expiry period (180 days by default).
- **Machine names become public with HTTPS.** They appear in Certificate Transparency logs; rename before enabling.
- **Auth keys are secrets.** Reusable keys are dangerous if stolen; prefer one-off or ephemeral, tagged, short-lived keys in a `0600` file. Never put them on a command line you share.
- **Verify upstream.** Versions, flags and limits come from tailscale.com/kb and the GitHub releases at use time.

## Workflows

- [ ] Install, `sudo tailscale up`, confirm the node in `tailscale status` -> `references/install.md`
- [ ] Enable MagicDNS and HTTPS in the admin console -> `references/https-and-magicdns.md`
- [ ] Bind the gateway to `127.0.0.1`, then `sudo tailscale serve --bg --https=443 http://127.0.0.1:<port>` -> `references/serve.md`
- [ ] Restrict who may reach the node (tag plus grant, with `tests`) -> `references/access-control.md`
- [ ] Disable key expiry for the server -> `references/access-control.md`
- [ ] Verify: `scripts/check-exposure.sh` lists no engine listener outside loopback, `tailscale serve status` matches intent, and an unauthenticated `curl https://node-a.<tailnet>.ts.net/v1/models` returns 401 from the gateway

## Reference index

- `references/install.md`: install script, pinning, tracks, `tailscale up` flags, tagged and auth-key nodes.
- `references/serve.md`: `tailscale serve` flags, background mode, paths, identity headers, TCP forwarding.
- `references/funnel.md`: Funnel limits, ports, enabling, when not to use it.
- `references/https-and-magicdns.md`: MagicDNS, HTTPS certificates, `tailscale cert`, Caddy integration, rate limits.
- `references/access-control.md`: tags, grants and ACLs, `tests`, node attributes, key expiry, auth keys.
- `references/updating.md`: `tailscale update`, auto-update, tracks.
- `references/troubleshooting.md`: error table.
- `references/combos/tailscale-serve-ollama.md`: Ollama through Serve with the Host-header fix.
- `references/combos/tailscale-serve-caddy-litellm.md`: Serve to a Caddy catalog front to the gateway.
- `scripts/check-exposure.sh`: read-only audit of listeners and Serve/Funnel state.
- `assets/policy-llm.hujson`: starter policy file for an LLM server tag.

## Companion skills

- `cloudflare-tunnel`: public hostname with Access, no tailnet needed. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloudflare-tunnel`.
- `caddy`: loopback reverse proxy, forward auth, model catalog. Install: `npx skills add ScaleDockHQ/llms-skills --skill caddy`.
- `litellm`: the authenticated gateway behind Serve. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `self-hosted-llms`: the full self-hosted stack that uses Serve. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
