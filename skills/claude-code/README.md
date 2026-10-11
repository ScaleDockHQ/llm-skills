# Claude Code

Helps an agent connect Claude Code (`claude`) to self-hosted and gateway models over the Anthropic Messages API: install and update, base URL and credential setup without printing secrets, model-slot mapping, context and output limits, compatibility switches for non-Anthropic backends, and troubleshooting. Covers vLLM, llama.cpp, Ollama, llama-swap and LiteLLM endpoints, with a script that probes an endpoint the way Claude Code uses it.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill claude-code
```

## Rules

- **Base URL is the root.** No `/v1`; Claude Code appends `/v1/messages`.
- **One credential variable.** Bearer or `x-api-key`, matched to what the endpoint checks. Never commit it.
- **Declare real limits** for model names Claude Code cannot resolve to a Claude model.
- **Test the endpoint first** with `scripts/check-endpoint.sh`.
- **Anthropic does not support non-Claude models behind a gateway.** Test edits, not just chat.

## References

- [`references/custom-endpoints.md`](references/custom-endpoints.md): base URL, auth, per-engine setup, privacy traffic.
- [`references/models-and-limits.md`](references/models-and-limits.md): slots, aliases, discovery, window and output limits.
- [`references/compatibility.md`](references/compatibility.md): betas, thinking, tools, streaming, caching.
- [`references/install-and-update.md`](references/install-and-update.md): install paths, channels, pinning, settings files.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-gateway.md`](references/combos/litellm-gateway.md): LiteLLM in front of local engines.

Also ships `templates/claude-code.env.example`, `templates/settings.json` and `scripts/check-endpoint.sh`.

## Companion skills

- `litellm`, `llm-gateway`: bridge and manage the endpoint.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints.
- `tool-calling-parsers`: engine-side tool-call parsing.
- `llm-clients`: other clients.

## License

MIT
