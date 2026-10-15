# LM Studio

Install, serve, tune and update LM Studio for an agent: the desktop app, the `lms` CLI and the llmster headless daemon. Covers the local server on port 1234 with OpenAI-, Anthropic- and native REST endpoints, JIT loading and TTL, API tokens and network exposure, the MCP host, runtimes (llama.cpp and MLX), LM Link, and pointing Claude Code or Codex at a local model.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill lm-studio
```

## Rules

- **Ask before changing the system.** Installers (`curl | bash`), services, LM Link, tokens and non-loopback binds need approval and an undo path.
- **Non-loopback means authenticated.** Turn on Require Authentication before `--bind 0.0.0.0` or `--cors`.
- **Tokens never touch output.** Use a `0600` file or `LM_API_TOKEN`; tokens are shown once at creation.
- **MCP from API clients is code execution.** Keep "Allow calling servers from mcp.json" off unless asked.
- **Set the context length** (25k+ for coding agents) and estimate before loading.

## References

- [`references/install.md`](references/install.md): app, llmster, `lms` on PATH, requirements, always-on service.
- [`references/configuration.md`](references/configuration.md): `lms` flags, JIT, TTL, auth, network, logs.
- [`references/features.md`](references/features.md): MCP, runtimes and MLX, speculative decoding, parallel requests.
- [`references/api.md`](references/api.md): OpenAI, Anthropic and native v1 REST endpoints.
- [`references/updating.md`](references/updating.md): app, llmster and runtime updates.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/claude-code.md`](references/combos/claude-code.md), [`codex.md`](references/combos/codex.md), [`lm-link.md`](references/combos/lm-link.md): verified pairings.
- [`scripts/lms-health.sh`](scripts/lms-health.sh): read-only health check. [`assets/lmstudio.service`](assets/lmstudio.service): systemd unit for llmster.

## Companion skills

- `local-llms`: choose and compare local runtimes.
- `mlx`: run, convert and fine-tune MLX models directly.
- `llm-clients`: wire editors and coding agents to an endpoint.
- `llm-gateway`: add keys and routing in front.
- `choosing-hardware`: size RAM and VRAM for a model.

## License

MIT
