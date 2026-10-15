# SillyTavern

An agent skill for connecting SillyTavern, the local character-chat and roleplay front end, to your own model servers. It covers the git and Docker install, Chat Completion with the Custom OpenAI-compatible source and the Claude reverse proxy, Text Completion types for vLLM, llama.cpp, Ollama and Generic, key handling in `secrets.json`, Additional Parameters, prompt post-processing, tool calling, streaming, Connection Profiles, safe remote access settings and troubleshooting, with a `config.yaml` snippet and a read-only endpoint probe.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill sillytavern
```

## Rules

- **Ask before changing the system.** Installs, `config.yaml` edits, listen and whitelist changes and updates need approval and an undo path.
- **Secrets never touch output.** Keys live in `data/<user>/secrets.json` (`0600`); never print, paste or commit them.
- **ST's server makes the requests**, so URLs must resolve from the ST host or container, not your browser.
- **Chat Completion Custom URL ends in `/v1`; Text Completion URL is the server root.**
- **Never port-forward ST to the internet.** Use a VPN or tunnel plus whitelist, accounts or basic auth.
- **Verify upstream.** Option names come from the upstream docs and `config.yaml` at use time.

## References

- [`references/install.md`](references/install.md): git, Docker, `config.yaml` essentials, security, updating.
- [`references/api-connections.md`](references/api-connections.md): API types, recipes, Claude proxy, tools, streaming, profiles.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Template: [`assets/config.yaml.snippet`](assets/config.yaml.snippet). Script: [`scripts/check-endpoint.sh`](scripts/check-endpoint.sh).

## Companion skills

- `llm-clients`: choosing and troubleshooting every kind of LLM client.
- `litellm`, `llama-swap`: gateways to point SillyTavern at.
- `koboldcpp`, `llama-cpp`, `vllm`, `ollama`, `exllamav3`: engines it talks to natively.
- `tool-calling-parsers`: fixing function calling that returns nothing.
- `tailscale`, `cloudflare-tunnel`: safe remote access.

## License

MIT
