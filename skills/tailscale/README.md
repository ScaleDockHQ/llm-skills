# Tailscale

An agent skill for reaching a self-hosted LLM endpoint privately over a tailnet: install, MagicDNS and HTTPS certificates, `tailscale serve` to a loopback gateway, optional Funnel, access policy (tags, grants, tests), key expiry on servers, updating and troubleshooting. It also ships a read-only script that checks no engine port is open beyond loopback. Public hostnames with Access policies belong to `cloudflare-tunnel`.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill tailscale
```

## Rules

- **The tailnet is not the API's auth boundary.** Keep gateway keys on.
- **Serve targets loopback only,** never a raw engine port.
- **Funnel is public** and has non-configurable bandwidth limits.
- **Disable key expiry on servers** or tag them.
- **Auth keys and machine names are sensitive.** Keys in `0600` files; machine names become public with HTTPS.

## References

- [`references/install.md`](references/install.md): install script, auth keys, `tailscale up`.
- [`references/serve.md`](references/serve.md): `tailscale serve`, identity headers.
- [`references/funnel.md`](references/funnel.md): limits and when to avoid it.
- [`references/https-and-magicdns.md`](references/https-and-magicdns.md): MagicDNS, certificates, Caddy integration.
- [`references/access-control.md`](references/access-control.md): tags, grants, tests, key expiry.
- [`references/updating.md`](references/updating.md): `tailscale update` and tracks.
- [`references/troubleshooting.md`](references/troubleshooting.md): error table.
- [`references/combos/tailscale-serve-ollama.md`](references/combos/tailscale-serve-ollama.md): Ollama through Serve.
- [`references/combos/tailscale-serve-caddy-litellm.md`](references/combos/tailscale-serve-caddy-litellm.md): Serve to a Caddy catalog front and the gateway.
- [`scripts/check-exposure.sh`](scripts/check-exposure.sh): exposure audit.
- [`assets/policy-llm.hujson`](assets/policy-llm.hujson): starter policy.

## Companion skills

- `cloudflare-tunnel`: public hostname with Access.
- `caddy`: loopback reverse proxy and model catalog.
- `litellm`: the authenticated gateway.
- `self-hosted-llms`: the full self-hosted stack.

## License

MIT
