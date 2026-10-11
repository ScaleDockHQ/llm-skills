---
name: ollama-open-webui-tailscale
description: Private ChatGPT-style web UI for local models, Ollama behind Open WebUI, reachable only over your Tailscale tailnet with HTTPS. Use to wire Ollama, Open WebUI and `tailscale serve` together, fix Open WebUI not seeing Ollama, pick bind addresses, WEBUI_SECRET_KEY, sign-up and trusted-header login, update images, and remove the stack. Not for single-product depth (ollama, tailscale), public exposure (cloudflare-tunnel) or multi-user gateways (litellm).
license: MIT
compatibility: Linux with Docker (host networking path) plus curl and jq; macOS and Windows need the caveats in references/open-webui-ollama.md. Needs a Tailscale account. Installing, starting services, enabling tailnet HTTPS and running tailscale serve need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Ollama + Open WebUI + Tailscale

A chat UI on your own models that you open from a phone or laptop at `https://<node>.<tailnet>.ts.net`, with Ollama and Open WebUI never listening on the LAN.

**Scope:** this combination only. Ollama depth lives in the `ollama` skill, Tailscale depth in `tailscale`. Open WebUI has no skill yet: this stack carries the minimum, verified against its docs and releases (v0.12.0 on 2026-10-11). Install later: `open-webui` skill when it is published.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints secrets.

```bash
command -v ollama docker tailscale
ollama --version 2>/dev/null; docker --version; tailscale version 2>/dev/null | head -1
ss -ltn 2>/dev/null | grep -E ':(11434|8080|3000)\b'    # who listens where (Linux)
curl -fsS http://127.0.0.1:11434/api/version | jq .       # Ollama up?
curl -fsS http://127.0.0.1:11434/api/tags | jq -r '.models[].name'
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i open-webui
tailscale status 2>/dev/null | head -5; tailscale serve status 2>/dev/null
```

## Decision flow

1. Ollama missing or without models: install the `ollama` skill and pull a model first.
2. Linux host with Docker: run Open WebUI with host networking and `HOST=127.0.0.1` so both services stay on loopback (`references/open-webui-ollama.md`).
3. macOS or Windows, or Open WebUI in a bridge network: Ollama must be reachable from the container; that changes the bind and needs a firewall. Read the caveats in the same reference before choosing.
4. Several users, per-user keys or budgets, or non-Ollama backends: put LiteLLM in the middle (install the `litellm` skill) and add it as an OpenAI connection.
5. Anyone outside your tailnet must reach it: stop and use `cloudflare-tunnel` with Access. Never use Funnel for this stack.

## Rules

- **Ask before changing the system.** Containers, services, `tailscale serve` and tailnet HTTPS need approval and an undo path (`references/operations.md`).
- **Nothing but Serve is reachable.** Ollama on `127.0.0.1:11434` (its default), Open WebUI on `127.0.0.1:8080`, Serve on 443. Re-run the discovery `ss` check after every change.
- **Ollama has no authentication.** Never point Serve at it directly; Open WebUI is the only client (`references/exposure-and-auth.md`).
- **Set `WEBUI_SECRET_KEY` once and keep it.** Without it every recreated container logs everyone out. Generate it into a `0600` file, never echo it.
- **Close sign-up after the admin exists.** The first account becomes admin; `ENABLE_SIGNUP` defaults to true.
- **No Funnel.** It publishes a password-protected chat UI to the internet.
- **Pin an image tag for anything you keep.** `:main` and `:latest` are the same rolling image.
- **Verify upstream.** Versions, tags and env names come from upstream docs read on the writing date.

## Build the stack

- [ ] Ollama on loopback with a model pulled -> `ollama` skill, `references/exposure-and-auth.md`
- [ ] Open WebUI container that reaches Ollama and listens on loopback -> `references/open-webui-ollama.md`
- [ ] Create the admin account, then set sign-up off -> `references/exposure-and-auth.md`
- [ ] `sudo tailscale serve --bg --https=443 http://127.0.0.1:8080`, then test from a second tailnet device -> `references/exposure-and-auth.md`
- [ ] Verify: `ss` shows only loopback listeners; the Serve URL loads, a prompt streams, and a device off the tailnet cannot connect.
- [ ] Update or remove later -> `references/operations.md`

## Reference index

- `references/open-webui-ollama.md`: Open WebUI image tags, the host-network run command, `OLLAMA_BASE_URL`, container-to-host reachability caveats.
- `references/exposure-and-auth.md`: tailnet HTTPS with `tailscale serve`, tags and grants, sign-up, trusted-header login, WebSocket check, what not to expose.
- `references/operations.md`: health checks, backup of the data volume, updates and rollback, removal, troubleshooting by symptom.

## Companion skills

- `ollama`: install, models and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill ollama`.
- `tailscale`: tailnet, MagicDNS, HTTPS, ACLs and grants. Install: `npx skills add ScaleDockHQ/llms-skills --skill tailscale`.
- `litellm`: multi-user gateway in front of Ollama. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `cloudflare-tunnel`: public hostname with Access, when the tailnet is not enough. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloudflare-tunnel`.
- `voice-stack`: adds speech input and spoken replies to this UI. Install: `npx skills add ScaleDockHQ/llms-skills --skill voice-stack`.
- `open-webui`: not published yet. Install later: `npx skills add ScaleDockHQ/llms-skills --skill open-webui`.
