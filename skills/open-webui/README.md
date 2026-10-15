# open-webui

Install, connect and operate Open WebUI against self-hosted OpenAI-compatible endpoints: vLLM, llama.cpp, Ollama, LM Studio, LiteLLM and llama-swap. Covers Docker networking to host endpoints, key handling, model ids and capabilities, tool calling and streaming, persistence, backup and updates, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill open-webui
```

## Contents

- `SKILL.md`: decision flow, rules and workflows.
- `references/`: install, connections, models-and-tools, docker-networking, persistence-and-updating, troubleshooting, `combos/litellm.md`.
- `assets/`: `docker-compose.yml` (pinned, localhost-bound) and `open-webui.env.example`.

Verified against Open WebUI v0.12.0, 2026-10-11. Anthropic-compatible custom base URLs are not supported by Open WebUI itself; use a gateway's OpenAI-compatible route.
