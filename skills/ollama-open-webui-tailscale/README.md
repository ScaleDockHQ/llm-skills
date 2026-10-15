# Ollama + Open WebUI + Tailscale

A stack skill that gets an agent from local Ollama models to a private web chat reachable over your tailnet with HTTPS. It covers Open WebUI's container, its connection to Ollama, loopback-only binds, `tailscale serve`, sign-in choices, updates and removal. Open WebUI has no skill of its own yet, so the minimum is verified here against its docs and v0.12.0.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill ollama-open-webui-tailscale
```

## Rules

- **Ask before changing the system.** Containers, Serve and tailnet HTTPS need approval.
- **Loopback everywhere except Serve.** Ollama has no authentication.
- **No Funnel.** Use `cloudflare-tunnel` with Access for public reach.
- **Fix `WEBUI_SECRET_KEY` and close sign-up** after creating the admin.

## References

- [`references/open-webui-ollama.md`](references/open-webui-ollama.md): image tags, host-network run command, reaching Ollama.
- [`references/exposure-and-auth.md`](references/exposure-and-auth.md): Serve, WebSocket check, trusted-header login.
- [`references/operations.md`](references/operations.md): health, backup, update, removal, troubleshooting.

## Companion skills

- `ollama`, `tailscale`, `litellm`, `cloudflare-tunnel`, `voice-stack`.
- `open-webui`: not published yet. Install later when available.

## License

MIT
