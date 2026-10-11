---
name: lm-studio
description: Install, serve, tune and update LM Studio (desktop app, `lms` CLI, llmster headless daemon) for GGUF and MLX models on a local server at :1234. Use for lms load/get/server start, JIT loading, TTL, API tokens, LM Link, mcp.json, Claude Code or Codex against a local model, "lms command not found", "Cannot find model". Not for Ollama or llama.cpp.
license: MIT
compatibility: macOS 14+ on Apple Silicon, Windows (x64 with AVX2, ARM64) and Linux (x64, ARM64; Ubuntu 20.04+). Needs curl and jq for the discovery commands. Installs, services, network exposure, tokens and LM Link need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LM Studio

Get a working, tuned and updatable LM Studio server that exposes OpenAI-, Anthropic- and native REST endpoints for local GGUF and MLX models, with or without the GUI.

**Scope:** this one product: install, serve, tune, share, update, troubleshoot. Choosing between runtimes belongs to `local-llms`; fitting a model to hardware belongs to `choosing-hardware`.

Work through the steps in order. Load a reference only when a step names it. Facts below were read from lmstudio.ai/docs and github.com/lmstudio-ai on 2026-10-11 (latest app 0.4.26). Run `lms <command> --help` on the installed build before relying on a flag.

## Three parts, one tool

| Part         | What it is                                                                                         |
| ------------ | -------------------------------------------------------------------------------------------------- |
| LM Studio    | The desktop app: search, download, chat, server, MCP host, settings.                               |
| **llmster**  | The headless daemon (no GUI): the same serving core for Linux boxes, GPU rigs, CI. `lms daemon …`. |
| **`lms`**    | The CLI that drives whichever of the two is running. Ships with both.                              |
| Bionic (new) | A separate agent app from the same vendor. Not covered here; `lms` may talk to it if it is alone.  |

## Discover first

Read-only; nothing here prints secrets.

```bash
command -v lms && lms --help | head -5            # CLI present? (run the app once if not)
lms server status --json --quiet                  # {"running":true,"port":1234} or not running
lms daemon status 2>&1 | head -3                  # llmster running?
lms ls | head -20                                 # downloaded models (--json for scripts)
lms ps                                            # loaded models
lms runtime ls                                    # installed engines (llama.cpp, MLX, ...)
curl -s http://127.0.0.1:1234/v1/models | jq -r '.data[].id' | head   # needs the server up; add a Bearer header if auth is on
sysctl -n machdep.cpu.brand_string hw.memsize 2>/dev/null; uname -sm
```

## Decision flow

1. No `lms` on PATH: GUI user installs the app, runs it once, then `lms` works; headless Linux/macOS box uses the llmster installer. `references/install.md`.
2. Pick the model and size it before loading: `lms get <model>` then `lms load --estimate-only <model> --context-length N`. On a Mac prefer an MLX build (`lms get --mlx`). `references/configuration.md`.
3. Serve: `lms load` (or rely on JIT) then `lms server start`. Loopback by default. Verify with `/v1/models`. `references/configuration.md`.
4. Others on the network, or a browser app: needs **Require Authentication** first, then `--bind` / `--cors`. `references/configuration.md` (Network and auth).
5. Always-on: app "run on login", or llmster plus a systemd unit (`assets/lmstudio.service`). `references/install.md`.
6. Coding agent as the client: `references/combos/claude-code.md` or `references/combos/codex.md`. Model on another machine: `references/combos/lm-link.md`.
7. Tools, MCP, structured output, speculative decoding, parallel requests, presets: `references/features.md`. Endpoints and request fields: `references/api.md`.
8. Update or roll forward runtimes: `references/updating.md`. Anything failing: `references/troubleshooting.md`.

## Quick reference

```bash
lms get openai/gpt-oss-20b                 # append @q4_k_m for a quant; --mlx / --gguf filter
lms load openai/gpt-oss-20b --context-length 32768 --gpu max --identifier local-model
lms server start                           # 127.0.0.1, last-used port (1234 by default)
curl -s http://127.0.0.1:1234/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local-model","messages":[{"role":"user","content":"Say hi"}]}' | jq -r '.choices[0].message.content'
```

| Surface           | URL                                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| OpenAI-compatible | `http://localhost:1234/v1`: models, responses, chat/completions, embeddings, completions, decisions |
| Anthropic         | `http://localhost:1234` (`POST /v1/messages`)                                                       |
| Native v1 REST    | `/api/v1/chat`, `/api/v1/models`, `/models/load`, `/models/unload`, `/models/download`              |

## Rules

- **Ask before changing the system.** Installs (`curl | bash` runs a remote script: show the user the URL first), services, firewall rules, tokens, LM Link and any non-loopback bind need approval and an undo path.
- **Non-loopback means authenticated.** Any `--bind` other than `127.0.0.1` exposes every model. Enable **Require Authentication** first (Developer > Server Settings, **Manage Tokens**). Upstream says the same.
- **Tokens never touch output.** Keep the API token in a `0600` file or an environment variable (`LM_API_TOKEN`); never in a command line you echo, a repo or a log. A token is shown once at creation.
- **MCP from API clients is code execution.** "Allow calling servers from mcp.json" needs Require Authentication on. Leave it off unless asked.
- **Set the context length.** Agents need 25k+ tokens; the estimator (`--estimate-only`) tells you if it fits. Do not disable resource guardrails to force a load.
- **Verify upstream.** Versions, flags and defaults come from the docs read on the writing date; `lms --help` wins on a newer build.

## Workflows

- [ ] Install and verify `lms`, then check the platform, RAM and runtime -> `references/install.md`
- [ ] Download, estimate, load, start the server, curl `/v1/models` -> `references/configuration.md`
- [ ] Harden: auth token, bind address, CORS, MCP toggles -> `references/configuration.md`
- [ ] Make it permanent: login item, or llmster + `assets/lmstudio.service` -> `references/install.md`
- [ ] Point a client at it (Claude Code, Codex, SDK, curl) -> `references/combos/`, `references/api.md`
- [ ] Verify: `lms ps` shows the model, `scripts/lms-health.sh` exits 0, a chat completion returns text.

## Reference index

- `references/install.md`: app, llmster installer, `lms` on PATH, requirements, always-on service.
- `references/configuration.md`: `lms` flags, load settings, JIT, TTL, auto-evict, server settings, auth, network, logs, paths.
- `references/features.md`: MCP host, speculative decoding, parallel requests, runtimes/MLX, per-model defaults, LM Link overview.
- `references/api.md`: OpenAI, Anthropic and native v1 REST endpoints, request fields, comparison, curl examples.
- `references/updating.md`: app, llmster, runtimes, beta channel, version checks.
- `references/troubleshooting.md`: symptoms, causes and fixes.
- `references/combos/claude-code.md`: Claude Code on a local model. `combos/codex.md`: Codex `--oss`. `combos/lm-link.md`: remote models via LM Link.
- `scripts/lms-health.sh`: read-only health check (server, models, optional token from env).
- `assets/lmstudio.service`: systemd unit for llmster on Linux (from upstream docs).

## Companion skills

- `local-llms`: choose and compare local runtimes. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `mlx`: run, convert and fine-tune MLX models directly with `mlx-lm`. Install: `npx skills add ScaleDockHQ/llms-skills --skill mlx`.
- `llm-clients`: wire editors and coding agents to an endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`.
- `llm-gateway`: put a gateway in front for keys and routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `choosing-hardware`: size RAM/VRAM for a model. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
