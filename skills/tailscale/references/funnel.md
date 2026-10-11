# Tailscale Funnel

> Verified against Tailscale v1.104.1 (docs: Tailscale Funnel validated 2026-01-20, Tailscale Serve overview), 2026-10-11

Funnel publishes a local service to the public internet at your node's `*.ts.net` name. Funnel relay servers hand a TCP proxy to your node; the relay does not decrypt traffic and TLS ends on your device. Funnel is documented as **beta**.

## Requirements and limits (from the docs)

- Tailscale v1.38.3 or later; MagicDNS and HTTPS enabled and valid HTTPS certificates.
- A `funnel` node attribute for the user or device in the policy file. The CLI adds `"nodeAttrs": [{"target": ["autogroup:member"], "attr": ["funnel"]}]` when you approve enabling it, so by default every tailnet member may use Funnel: narrow `target` if that is too wide.
- Only DNS names under your tailnet domain (`<node>.<tailnet>.ts.net`). No custom domains.
- Only ports **443, 8443 and 10000**, only TLS.
- **Non-configurable bandwidth limits** apply to Funnel traffic.
- Public DNS records can take up to 10 minutes to appear.
- No identity headers on Funnel traffic.
- A port cannot be Serve and Funnel at once; the last command wins.
- The Serve overview says Funnel is enabled by default and can be turned off, while the Funnel page says it is disabled by default and enabled on first use of `tailscale funnel`. The docs conflict; check `tailscale funnel status` and the policy file for your tailnet.

## Use

```bash
sudo tailscale funnel --bg 8088          # publish a loopback target (same target syntax as serve)
tailscale funnel status
sudo tailscale funnel --https=443 off    # stop
```

Run it only after the gateway enforces keys: anyone on the internet can then reach everything behind the target. For an LLM stack prefer Cloudflare Tunnel when you need public access: custom domain, Access policies for dashboards, WAF and service tokens (`cloudflare-tunnel` skill). Funnel suits a short demo or a webhook receiver.

Because bandwidth limits are not configurable and not published, do not rely on Funnel for sustained high-throughput traffic such as bulk embeddings or large uploads (the numbers are undocumented: unverified).

## Disable

`tailscale funnel --https=<port> off`, or remove the `funnel` attribute from `nodeAttrs` to prevent anyone from using it.

## Official links

- [Tailscale Funnel](https://tailscale.com/kb/1223)
- [Funnel examples](https://tailscale.com/kb/1247)
- [Tailscale Serve](https://tailscale.com/kb/1312)
