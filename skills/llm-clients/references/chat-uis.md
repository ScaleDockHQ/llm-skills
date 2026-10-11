# Chat UIs: Open WebUI, LobeHub

> Verified against Open WebUI v0.12.0 docs and LobeHub v2.2.19 docs (formerly LobeChat), 2026-10-11

Stack notes only. Install, connections, capabilities, upgrades and troubleshooting live in the product skills (also `librechat`, `anythingllm` and `sillytavern` for other UIs).

## How they plug into this stack

Self-hosted chat UIs call the endpoint from their own server process, usually a container, over OpenAI Chat Completions, and read `/v1/models` to list models. Capabilities (vision, tools, context) are set in the UI or env model lists.

Stack pitfalls:

- `localhost` inside the container is the container; use `host.docker.internal` or a shared Docker network name.
- Give the UI a least-privilege virtual key and a model allowlist, not the gateway master key.
- Gateways return placeholder `/v1/models` metadata (fixed `created`, `owned_by: openai`), so fetched models can show wrong dates or default capabilities.
- Open WebUI has no Anthropic-compatible base URL option; use the gateway's OpenAI route.

Depth:

- `open-webui`: `npx skills add ScaleDockHQ/llms-skills --skill open-webui`
- `lobehub`: `npx skills add ScaleDockHQ/llms-skills --skill lobehub`
- `librechat`: `npx skills add ScaleDockHQ/llms-skills --skill librechat`
- `anythingllm`: `npx skills add ScaleDockHQ/llms-skills --skill anythingllm`
- `sillytavern`: `npx skills add ScaleDockHQ/llms-skills --skill sillytavern`
