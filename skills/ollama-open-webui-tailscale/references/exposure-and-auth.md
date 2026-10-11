# Exposure and sign-in: Tailscale Serve in front of Open WebUI

> Verified against Tailscale v1.104.1 (Serve docs as captured in the `tailscale` skill), Open WebUI v0.12.0 (SSO docs trusted-header section, env-configuration, troubleshooting/connection-error) and Ollama v0.40.3, 2026-10-11

```text
phone/laptop --HTTPS--> node.<tailnet>.ts.net:443 (tailscale serve)
             --> 127.0.0.1:8080 Open WebUI --> 127.0.0.1:11434 Ollama
```

## Publish with Serve

Prerequisites: tailnet HTTPS enabled and MagicDNS on (`tailscale` skill, `https-and-magicdns.md`). Ask first, then:

```bash
sudo tailscale serve --bg --https=443 http://127.0.0.1:8080
tailscale serve status
```

Undo with `sudo tailscale serve reset` (clears all Serve config on the node; use `sudo tailscale serve --https=443 off` to drop only this listener).

Test from a second tailnet device, then from one that is off the tailnet:

```bash
curl -fsSI https://<node>.<tailnet>.ts.net/ | head -3   # tailnet device: 200
curl -fsS  https://<node>.<tailnet>.ts.net/health        # app health route
```

The off-tailnet device must fail to connect. Never use `tailscale funnel` here.

## WebSockets and streaming

Open WebUI requires WebSocket support (`ENABLE_WEBSOCKET_SUPPORT` defaults to true); the docs list WebSocket failures and garbled streaming among the reverse-proxy problems. Tailscale's Serve page was not found to document WebSocket behaviour, so verify instead of assuming: open the Serve URL in a browser, send a prompt, and watch the browser dev tools Network tab filtered to `WS` for a connected socket and a response that streams token by token. If chats hang after load or never stream, fall back to a loopback Caddy in front of Open WebUI (`caddy` skill, `combos/tailscale-tls.md`) and point Serve at Caddy.

Set `WEBUI_URL` to the Serve URL and `CORS_ALLOW_ORIGIN` to the same origin if you tighten CORS; the docs say browser origin errors in logs mean the origin is missing from `CORS_ALLOW_ORIGIN` (semicolon separated).

## Who can reach it

The tailnet is not an authentication boundary for a chat UI that holds history. Restrict with a tag and a grant so only chosen users or devices reach this node on 443 (`tailscale` skill, `access-control.md`). Open WebUI keeps its own login on top.

## Sign-in options

1. **Built-in accounts (default).** The first account created becomes the admin. Create it, then set `ENABLE_SIGNUP=False` in the env file and recreate the container. Persistent-config note: some values persist in the app database and can also be changed in Admin Panel > Settings > General.
2. **Trusted header from Serve.** For tailnet traffic Serve adds `Tailscale-User-Login` (and `Tailscale-User-Name`) and strips client-supplied copies; they are absent for tagged devices and not set on Funnel traffic (`tailscale` skill, `serve.md`). Open WebUI can delegate login to such a header:

```text
WEBUI_AUTH_TRUSTED_EMAIL_HEADER=Tailscale-User-Login
WEBUI_AUTH_TRUSTED_NAME_HEADER=Tailscale-User-Name
```

Open WebUI treats the header value as the user's email. The docs warn that a wrong setup lets anyone log in as any user, so this is safe only when Open WebUI listens on loopback (`HOST=127.0.0.1`) and Serve is the only path in. Whether Tailscale's login value is an email for your identity provider was not verified: check `tailscale serve status` traffic with a test user first, and keep built-in sign-in as the fallback. Not tested with this stack. 3. **OIDC or OAuth.** Needs `WEBUI_URL` set before first use; see Open WebUI docs (`features/authentication-access/auth/sso`).

## Do not expose

- Ollama's port (no auth; Ollama answers 403 to unknown Host headers on loopback, so Serve cannot front it directly, see `tailscale` skill `combos/tailscale-serve-ollama.md` if you need raw API access).
- Open WebUI on `0.0.0.0`.
- The Docker socket or the `open-webui` data volume.
- A second Serve mapping on the same node without a grant that covers it.
