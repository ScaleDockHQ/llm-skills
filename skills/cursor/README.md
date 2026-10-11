# Cursor

An agent skill for connecting Cursor to your own OpenAI-compatible LLM endpoint (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap). It explains the one supported route (Settings > Models > Override OpenAI Base URL), why the endpoint must be public HTTPS (requests leave from Cursor's servers, so localhost, LAN and VPN addresses fail), how to scope and store the key, model naming, tool-calling and streaming requirements, and symptom-first troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill cursor
```

## Rules

- **Ask before changing the system.** Public exposure, tunnels, keys and Settings edits need approval and an undo path.
- **Secrets never touch output.** Use a scoped virtual key in a `0600` file; the key is sent to Cursor's backend on every request.
- **Public means authenticated.** Expose only a gateway with bearer auth, rate limits and logs.
- **The override is global** and covers chat and agent only; Tab keeps using Cursor's models.
- **Verify upstream.** The base-URL override comes from Cursor staff answers, not the help page; re-check after updates.

## References

- [`references/install.md`](references/install.md): install, versions, docs and settings locations.
- [`references/custom-endpoint.md`](references/custom-endpoint.md): data flow, override setup, routing rules, model names, tool calling, billing.
- [`references/combos/self-hosted-endpoints.md`](references/combos/self-hosted-endpoints.md): per-engine and gateway values, recommended public shape.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/updating.md`](references/updating.md): re-verifying the override after Cursor updates.

**Script:** [`scripts/probe.sh`](scripts/probe.sh): read-only check of models, chat, streaming and tool calls (key from a file or environment, never printed).

## Companion skills

- `litellm`, `llm-gateway`, `cloudflare-tunnel`, `caddy`, `llm-clients`, `continue`, `cline`, `kilo-code`.

## License

MIT
