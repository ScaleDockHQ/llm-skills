# LM Studio

> Verified against LM Studio 0.4.26 (`lms` CLI bundled, llmster headless daemon), 2026-10-11

## What it is and when to choose it

LM Studio is a desktop app for macOS (Apple Silicon), Windows (x64 and ARM64), and Linux (x64 and ARM64 AppImage). You can search Hugging Face, download GGUF or MLX models, chat with them, and run a local API server. It has three parts:

- **LM Studio app:** the GUI.
- **llmster:** the headless daemon. It provides the same serving capabilities without a GUI.
- **`lms`:** the CLI. It controls whichever of the two is running.

Choose LM Studio when the user prefers a GUI, wants a memory estimate before loading, wants MLX and GGUF in one tool on a Mac, or needs API-token auth without writing proxy config.

## Install

- **App:** the installer from https://lmstudio.ai/download. `lms` ships with it. If `lms` isn't on your PATH, run `npx lmstudio install-cli` and open a new terminal.
- **llmster (headless):** macOS/Linux `curl -fsSL https://lmstudio.ai/install.sh | bash`; Windows `irm https://lmstudio.ai/install.ps1 | iex`. Then `lms daemon up`.
- Requirements: macOS 14+ on Apple Silicon (Intel Macs aren't supported); Windows x64 needs AVX2; Linux is Ubuntu 20.04+ (newer releases are less tested). LM Studio recommends 16 GB+ of RAM.

## Minimal working config

```bash
lms get <model>                    # e.g. "qwen3-8b"; append @q4_k_m for a specific quant; --mlx / --gguf filter
lms ls                             # downloaded models (--json for scripts)
lms load --estimate-only <model> --context-length 32768   # memory estimate, does not load
lms load <model> --context-length 32768 --gpu max --identifier local-model
lms ps                             # loaded models
lms server start                   # 127.0.0.1, last-used port (1234 by default)
curl -s http://localhost:1234/v1/models
```

## How it plugs in

| Item                 | Value                                                                                                                                                                |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Default bind         | `127.0.0.1:1234`. `lms server start --port N`; `--bind 0.0.0.0` (or `LMS_SERVER_HOST`) for the LAN                                                                   |
| Health               | `lms server status`; `GET /v1/models`                                                                                                                                |
| OpenAI-compatible    | `http://localhost:1234/v1`: `/v1/models`, `/v1/chat/completions`, `/v1/completions`, `/v1/responses`, `/v1/embeddings`                                               |
| Anthropic-compatible | `/v1/messages` with `ANTHROPIC_BASE_URL=http://localhost:1234`                                                                                                       |
| Native REST          | `/api/v1/...` (chat, load, unload, download)                                                                                                                         |
| Auth                 | Off by default. Turn on **Require Authentication** under Developer → Server Settings, create tokens with **Manage Tokens**, and send `Authorization: Bearer <token>` |
| CORS                 | Off by default; `lms server start --cors`                                                                                                                            |

Just-in-time loading: when JIT is on, `/v1/models` lists every downloaded model, and requests load models on demand. JIT-loaded models auto-unload after a TTL. Set the TTL per model with `lms load --ttl <seconds>`.

## Operating

- Start/stop server: `lms server start` / `lms server stop`; `lms server status`.
- Daemon: `lms daemon up` / `lms daemon down` / `lms daemon status`; update with `lms daemon down && lms daemon update && lms daemon up`.
- App as a background service: Settings (`Cmd`/`Ctrl` + `,`) → run the LLM server on login. Closing the window then minimizes LM Studio to the tray.
- Linux boot service for llmster: LM Studio documents a systemd unit that runs `lms daemon up`, `lms load ... --yes`, and `lms server start` (see the official link below). On a desktop, prefer the app's "run on login".
- Logs: `lms log stream` (model I/O), `lms log stream --source server` (server logs), `--stats` for prediction stats.
- Runtimes (llama.cpp CUDA/Vulkan/CPU, MLX): `lms runtime ls`, `lms runtime get`, `lms runtime select`, `lms runtime update`, `lms runtime remove`.
- Unload: `lms unload <model>` or `lms unload --all`.
- Disk: the models directory is shown, and can be changed, in the **My Models** tab. Delete models there.

## Tuning knobs worth knowing

- `--context-length`: set it explicitly. Agents need tens of thousands of tokens.
- `--gpu 0-1|max|off`: fraction of layers to offload. `max` is right when the estimate fits.
- Flash attention and KV cache quantization are in the app's per-model load settings _(unverified: exact menu location varies between versions)_.
- On Apple Silicon, prefer the MLX build of a model when one exists (`lms get --mlx`).
- Resource guardrails in the app can block loads that the estimator thinks won't fit. Fix the size; don't disable the guardrail.

## Known pitfalls

- `lms` starts LM Studio or llmster automatically for most commands. `lms status`, `lms server status`, and `lms server stop` don't.
- If several LM Studio products are installed, `lms` talks to the running one first (llmster or the app before Bionic).
- `--bind 0.0.0.0` without **Require Authentication** exposes every loaded model to the network. LM Studio's own docs warn about this.
- "Allow calling servers from mcp.json" lets API clients use your MCP servers, which may have filesystem access. Keep it off unless you need it.
- The port is sticky: `lms server start` reuses the last port. Check `lms server status` before pointing clients at 1234.

## Official links

- Docs: https://lmstudio.ai/docs
- LM Studio vs llmster vs lms: https://lmstudio.ai/docs/app/basics/lmstudio-vs-llmster-vs-lms
- Headless mode: https://lmstudio.ai/docs/developer/core/headless
- Linux startup task: https://lmstudio.ai/docs/developer/core/headless_llmster
- Authentication: https://lmstudio.ai/docs/developer/core/authentication
- Serve on local network: https://lmstudio.ai/docs/developer/core/server/serve-on-network
- `lms server start`: https://lmstudio.ai/docs/cli/serve/server-start
- `lms load`: https://lmstudio.ai/docs/cli/local-models/load
- OpenAI compatibility: https://lmstudio.ai/docs/developer/openai-compat
- Anthropic compatibility: https://lmstudio.ai/docs/developer/anthropic-compat
- CLI source: https://github.com/lmstudio-ai/lms
