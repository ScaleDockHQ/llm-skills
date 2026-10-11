# Ollama on a LAN, Tailscale or a tunnel

> Verified against Ollama v0.40.3, 2026-10-11

(docs: faq; server/routes.go host-allow logic). Tailscale and Cloudflare specifics belong to their skills and were not re-verified here.

Ollama has no authentication. Anything that can open port 11434 can run, pull and delete models. Add network or proxy-level protection before exposing it.

## Options, safest first

1. **Stay on loopback** and use SSH port forwarding: `ssh -N -L 11434:127.0.0.1:11434 user@server`. Clients use `http://127.0.0.1:11434`.
2. **Bind to a private-mesh address only** (for example your Tailscale IP): `OLLAMA_HOST=<tailscale-ip>:11434` in the systemd override. Only peers on the tailnet reach it. See the `tailscale` skill (`npx skills add ScaleDockHQ/llms-skills --skill tailscale`).
3. **Reverse proxy with auth** (nginx, Caddy) on the host, Ollama on loopback. Rewrite the Host header, or Ollama answers 403:

```nginx
server {
    listen 80;
    server_name example.com;
    location / {
        proxy_pass http://localhost:11434;
        proxy_set_header Host localhost:11434;
        # add auth here: auth_basic, mTLS, or an OIDC proxy
    }
}
```

4. **Tunnels:** `ngrok http 11434 --host-header="localhost:11434"` or `cloudflared tunnel --url http://localhost:11434 --http-host-header="localhost:11434"`. Put access control (Cloudflare Access, ngrok auth) on the tunnel; see `cloudflare-tunnel` skill.
5. **`OLLAMA_HOST=0.0.0.0:11434` on a LAN** only behind a host firewall that limits sources. When bound to a non-loopback address Ollama skips its Host-header check.

## Host header rule (loopback bind)

With the default bind Ollama returns 403 unless `Host` is `localhost`, the machine hostname, `*.local`, `*.localhost`, `*.internal`, or a loopback, private or local IP. A public hostname through a proxy or tunnel therefore needs the Host rewrite above.

## Browser clients

Web UIs calling Ollama from the browser need the origin in `OLLAMA_ORIGINS`; extensions need `chrome-extension://*,moz-extension://*,safari-web-extension://*` as applicable.

## Checks

```bash
ss -ltnp | grep 11434                         # which address is it bound to
curl -s http://<host>:11434/api/version       # from another machine; should only work where you intend
```
