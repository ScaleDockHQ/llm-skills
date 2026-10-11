# Unsloth Studio and Desktop

> Verified against unslothai/unsloth Studio/Desktop v0.1.905-beta (README.md, unsloth.ai/docs install and export pages), 2026-10-11

Unsloth Studio is an open-source web UI to run and train models, with data recipes (datasets from PDFs, CSVs, DOCX), observability, chat, and export. Unsloth Desktop is the native app of the same product. Both are labeled beta (`v0.1.x-beta` releases). Studio UI is AGPL-3.0; the Core library is Apache-2.0.

README claims: runs on Windows, Linux, WSL and macOS; NVIDIA, AMD and Intel GPUs, CPUs and Vulkan; trains LLMs, diffusion, TTS and embedding models; serves an OpenAI-compatible API (docs page https://unsloth.ai/docs/basics/api); connects to Claude Code, Codex and MCP servers.

## Install and launch

```bash
curl -fsSL https://unsloth.ai/install.sh | sh            # macOS, Linux, WSL; same command updates
unsloth studio                                           # launch (local)
unsloth studio -H 127.0.0.1 -p 8888                      # explicit loopback and port
```

See `references/install.md` for Desktop installers, Docker, Homebrew and the installer environment variables. Developer/nightly installs: `git clone https://github.com/unslothai/unsloth && cd unsloth && ./install.sh --local`, update with `git pull && ./install.sh --local`.

## Exposure rules

- `unsloth studio --secure` creates a free Cloudflare HTTPS link reachable from anywhere; `-H 0.0.0.0` serves on all interfaces; LAN access is a setting (Settings > API keys > LAN access).
- Server-side tools are on by default and Studio can execute code, so exposing it is exposing a shell-capable service. Get approval first, set a strong password, and consider `--disable-tools`.
- Exposing (`--secure`, `--cloudflare`, non-loopback `-H`) prompts once at the terminal for a new admin password; Ctrl+C aborts the launch rather than exposing the auto-generated one. Headless: `UNSLOTH_STUDIO_PASSWORD='<from a 0600 file>' unsloth studio --secure`. Reset: `unsloth studio reset-password`. Stay off the network with `-H 127.0.0.1`.
- Never put the password on a command line that is logged or shown; read it from a file or a secret manager.

## Train and export in the UI

Training runs, observability and checkpoints live in the UI. Export (docs `new/studio/export`): choose run, choose checkpoint (later checkpoints are usually final), pick Merged Model (16-bit, adapter folded in), LoRA Only (adapter weights, needs the base model), or GGUF / llama.cpp (for Unsloth, llama.cpp, Ollama, LM Studio), then save locally or push to the Hub with a write token. You can also convert any existing model, not only Unsloth runs.

## Other commands in the CLI

`unsloth start <agent>` connects coding agents (`claude`, `codex`, `opencode`, `hermes`, `vibe`, `openclaw`, `dsh`) to local models through Unsloth's OpenAI- and Anthropic-compatible APIs, for example `unsloth start claude --model unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL` (README). `unsloth studio`, `start`, `train`, `export`, `chat`, `eval`, `inference` exist as command modules in `unsloth_cli/commands/`; only `studio` and `start` are documented in the README, the rest are **unverified** here.

## GGUF-only mode

`curl -fsSL https://unsloth.ai/install.sh | UNSLOTH_NO_TORCH=1 sh` installs without PyTorch for running GGUF models (no training).
