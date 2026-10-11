# lobehub

Deploy and operate LobeHub (formerly LobeChat) v2 against self-hosted OpenAI-compatible and Anthropic-compatible endpoints: vLLM, llama.cpp, Ollama, LM Studio, LiteLLM and llama-swap. Covers the server-database Compose install, proxy URLs and keys, `*_MODEL_LIST` capability flags, Docker networking and the SSRF guard, update and backup, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill lobehub
```

## Contents

- `SKILL.md`: decision flow, rules and verification.
- `references/`: install, connections, models-and-capabilities, docker-networking, updating-and-backup, troubleshooting, `combos/gateway.md`.
- `assets/lobehub-models.env.example`: provider variables to merge into the Compose `.env`.

Verified against LobeHub v2.2.19, 2026-10-11. Unverified: the Anthropic proxy URL suffix and whether Client Request Mode exists in v2.
