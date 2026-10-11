# Exposure: Cloudflare Tunnel

> Verified against cloudflared 2026.10.0, 2026-10-11

## What it is and when to choose it

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
runs `cloudflared` on node-a, which opens outbound connections to Cloudflare; requests to
`llm.example.com` arrive through them. No inbound port, no public IP, TLS at the edge.

Choose it for a public, key-authenticated endpoint that any client on any network can reach. Choose
Tailscale (`exposure-tailscale.md`) when only your own devices need access, or when requests run
longer than Cloudflare's proxy read timeout and cannot stream.

## Install (DGX Spark/arm64 and generic x86)

```bash
ARCH=arm64      # amd64 on x86
curl -fsSLO "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
sudo dpkg -i "cloudflared-linux-${ARCH}.deb"
cloudflared --version
```

Or use Cloudflare's apt repository ([pkg.cloudflare.com](https://pkg.cloudflare.com/index.html)) so
updates come with the OS.

## Minimal working config

Locally managed tunnel (config in a file you version):

```bash
cloudflared tunnel login                                 # browser login, writes cert.pem to ~/.cloudflared
cloudflared tunnel create llm-stack                      # writes <tunnel-uuid>.json credentials
cloudflared tunnel route dns llm-stack llm.example.com
sudo install -d /etc/cloudflared
sudo install -m 600 ~/.cloudflared/<tunnel-uuid>.json /etc/cloudflared/
sudo install -m 644 assets/cloudflared-config.yml /etc/cloudflared/config.yml   # then edit
cloudflared --config /etc/cloudflared/config.yml tunnel ingress validate
cloudflared --config /etc/cloudflared/config.yml tunnel ingress rule https://llm.example.com/v1/models
sudo cloudflared --config /etc/cloudflared/config.yml service install
sudo systemctl enable --now cloudflared
```

The ingress in `assets/cloudflared-config.yml`:

1. `llm.example.com` + `path: ^/(v1/)?models/?$` -> `http://127.0.0.1:8088` (catalog front).
2. `llm.example.com` -> `http://127.0.0.1:4000` (LiteLLM).
3. `dash.example.com` -> `http://127.0.0.1:5555`, protected by an Access application.
4. Catch-all `http_status:404` (required, last).

Rules are evaluated top to bottom; `path` is a regular expression; the path is forwarded unchanged.

## How it plugs into the stack

- Clients use `https://llm.example.com/v1` with `Authorization: Bearer <your-key>`; LiteLLM checks
  the key. Do **not** put Cloudflare Access in front of the API hostname: API clients cannot do
  the browser login. (Access service tokens, sent as `CF-Access-Client-Id` /
  `CF-Access-Client-Secret` headers, work only with clients that let you add headers.)
- Dashboards (sparkDash, the llama-swap UI if you expose it) go behind Access. With
  `originRequest.access` (`required`, `teamName: <team>`, `audTag: [<aud-tag>]`) cloudflared also
  validates the Access token itself.

## Operating

```bash
systemctl status cloudflared --no-pager | head -5
journalctl -u cloudflared -f
cloudflared tunnel info llm-stack           # connectors and their edge locations (needs cert.pem)
cloudflared tunnel list
```

Change ingress: edit the file, validate it (as above), `sudo systemctl restart
cloudflared`, then the smoke test.

## Timeouts

Cloudflare closes a proxied request with **HTTP 524** when the origin sends no response for the
Proxy Read Timeout, 125 seconds by default (Enterprise plans can raise it). `originRequest` has
connect and keep-alive settings but no read timeout to raise.

Where it bites in this stack:

- **Cold swaps**: a non-streaming request for an unloaded large model waits for the whole load.
  Streaming requests are safe when llama-swap's `sendLoadingState: true` sends loading progress.
- **Long image generations**: `/v1/images/generations` returns nothing until the image is done.
- **Huge prompts** on slow prefill, non-streaming.

Mitigations, in order of preference: stream (and keep `sendLoadingState`); keep the models clients
use preloaded (`hooks.on_startup.preload`, `ttl: 0`); send long jobs through the tailnet path
(`exposure-tailscale.md`), which has no such proxy timeout; for image servers, smaller sizes or
fewer steps through the public path.

## Known pitfalls

- **Tunnel started with `nohup`**: works until the process dies (OOM, crash, logout of a tmux
  session, reboot), then every request returns **HTTP 530** (error 1033: no healthy connector) and
  nothing restarts it. Always run it as the systemd service.
- **Catch-all above a path rule**: the catalog rule never matches; clients get the thin list.
- **`localhost` vs `127.0.0.1`**: if a service listens only on IPv4 loopback and `localhost`
  resolves to `::1` first, cloudflared gets connection refused (502). Use `127.0.0.1`.
- **Access on the API hostname**: API clients get an HTML login page instead of JSON.
- **Credentials file readable by others**: it lets anyone run your tunnel. Mode 600.

## Official links

- [Configuration file](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
- [Run as a Linux service](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/as-a-service/linux/)
- [Common tunnel errors](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/troubleshoot-tunnels/common-errors/)
- [Error 524](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/error-524/)
- [Service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/)
- [cloudflared releases](https://github.com/cloudflare/cloudflared/releases)
