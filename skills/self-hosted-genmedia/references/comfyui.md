# ComfyUI as a headless image/video server

> Verified against ComfyUI v0.39.0 (Comfy-Org/ComfyUI) and llama-swap v263, 2026-10-11

## How it plugs into this stack

- **No OpenAI route.** ComfyUI speaks its native API (`POST /prompt` with an API-format graph, `GET /history/{id}`, `GET /view`). Clients that need `/v1/images/generations` need a small loopback wrapper, or use sd-server (`image-servers.md`) when the model family is supported.
- **llama-swap:** use the dedicated `/comfyui/` endpoint with the reserved model id `comfyui_auto` and `checkEndpoint: /` (ComfyUI has no `/health`). Details in `stack-integration.md`.
- **Auth:** none in ComfyUI core. Keep it on `127.0.0.1` behind llama-swap `apiKeys` and/or LiteLLM.
- **Memory:** budget it with `memory-planning.md`; share the GPU with LLMs through an exclusive llama-swap group or `--reserve-vram`.
- **Long jobs:** `POST /prompt` returns at once; poll `/history/{id}` rather than holding a request open through Cloudflare.

Depth: install the comfyui skill (npx skills add ScaleDockHQ/llm-skills --skill comfyui)
