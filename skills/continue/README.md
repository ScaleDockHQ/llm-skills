# Continue

An agent skill for configuring Continue (VS Code, JetBrains and the `cn` CLI) against self-hosted LLM endpoints: vLLM, llama.cpp, Ollama, LiteLLM and llama-swap, over OpenAI-compatible or Anthropic-compatible base URLs. It covers `~/.continue/config.yaml`, `apiBase` rules, secrets in `~/.continue/.env`, roles and capabilities for Agent mode, model-name mapping, the Responses API trap, tool-calling and streaming caveats, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill continue
```

## Rules

- **Ask before changing the system.** Show a diff and keep a backup before editing `~/.continue/config.yaml`.
- **Secrets never touch output.** Use `${{ secrets.NAME }}` and a `0600` `~/.continue/.env`; IDE extensions cannot read shell exports.
- **Capabilities only add.** Declare `tool_use` and `image_input` for custom models.
- **Neutral aliases.** Avoid names that make Continue use the Responses API, or set `useResponsesApi: false`.
- **Verify upstream.** Fields come from docs.continue.dev and the repository at use time.

## References

- [`references/install.md`](references/install.md): extension, JetBrains, `cn` CLI, files and versions.
- [`references/config-endpoints.md`](references/config-endpoints.md): config.yaml fields, providers, secrets, capabilities.
- [`references/combos/self-hosted-endpoints.md`](references/combos/self-hosted-endpoints.md): exact entries per engine and gateway.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/updating.md`](references/updating.md): updating and config migration.

**Template and script:** [`assets/config.yaml`](assets/config.yaml) (validated YAML); [`scripts/probe.sh`](scripts/probe.sh) (read-only endpoint check, key never printed).

## Companion skills

- `litellm`, `llm-gateway`, `llm-clients`, `cursor`, `cline`, `kilo-code`, `vllm`, `llama-cpp`, `ollama`, `llama-swap`.

## License

MIT
