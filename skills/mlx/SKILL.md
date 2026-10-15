---
name: mlx
description: Run, serve, convert, quantize and LoRA fine-tune models on Apple Silicon with MLX (mlx-lm, mlx-vlm, mlx_lm.server). Use for mlx_lm.generate/chat/convert/lora/fuse, mlx-community models, vision models via mlx_vlm.server, iogpu.wired_limit_mb, "[WARNING] Generating with a model that requires", MLX vs GGUF on a Mac. Not for LM Studio, Ollama or llama.cpp.
license: MIT
compatibility: macOS 14+ on Apple Silicon with native arm64 Python 3.11+ (mlx-lm; 3.10+ for mlx-vlm); needs curl and jq for server checks. Installs, sudo sysctl changes, model downloads, uploads to Hugging Face and network exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# MLX (mlx-lm and mlx-vlm)

Get Apple's native MLX stack running on a Mac: generate, chat, serve an OpenAI-style API, convert and quantize Hugging Face models, and fine-tune with LoRA, all in unified memory.

**Scope:** this one product family: install, serve, tune, convert, fine-tune, update, troubleshoot. Choosing between runtimes belongs to `local-llms`; quantization strategy across engines belongs to `model-quantization`; LoRA strategy belongs to `fine-tuning-llms`.

Work through the steps in order. Load a reference only when a step names it. Facts were read from upstream on 2026-10-11: mlx-lm 0.32.0 (PyPI; GitHub tag v0.32.0, latest GitHub release v0.31.3), mlx 0.32.3, mlx-vlm 0.7.6. Flags below come from the 0.32.0 sources and `main`; confirm with `<command> --help` on the installed version.

## Discover first

Read-only; nothing here prints secrets.

```bash
uname -m; sw_vers -productVersion                     # arm64 and macOS 14+ required
sysctl -n machdep.cpu.brand_string hw.memsize         # chip and RAM (bytes)
sysctl iogpu.wired_limit_mb                           # 0 = system default GPU wired limit
python3 -c 'import platform; print(platform.machine(), platform.python_version())'   # want arm64, 3.11+
command -v mlx_lm.generate mlx_lm.server mlx_vlm.generate
python3 -m mlx --version 2>/dev/null; python3 -m mlx_lm --version 2>/dev/null
ls ~/.cache/huggingface/hub 2>/dev/null | head        # cached models (HF_HOME overrides)
curl -s http://127.0.0.1:8080/health                  # something already on the default port?
memory_pressure | tail -3
```

## Decision flow

1. Not Apple Silicon, or the user wants a GUI: use LM Studio (`lm-studio` skill) which runs MLX models too. Intel Macs are unsupported by MLX's Metal path.
2. No install: `references/install.md` (venv, `pip install mlx-lm`, optional `mlx-vlm`).
3. Try a model: `mlx_lm.generate` or `mlx_lm.chat` with an `mlx-community/...-4bit` repo. Size it first with `references/apple-silicon.md` (RAM, wired limit).
4. Serve an API: `mlx_lm.server` for text (`references/serving.md`), `mlx_vlm.server` for images/audio/omni (`references/vision.md`). Both are unauthenticated by default in mlx-lm; mlx-vlm binds `0.0.0.0` by default.
5. Make or shrink a model: `references/convert-quantize.md`. Quality check with `mlx_lm.perplexity`.
6. Teach a model: `references/fine-tuning.md` (`mlx_lm.lora`, `mlx_lm.fuse`). Adapter to GGUF: `references/combos/lora-to-gguf.md`.
7. Swap several MLX models behind one endpoint: `references/combos/llama-swap.md`.
8. Slow, swapping, or the wired-limit warning: `references/apple-silicon.md`, then `references/troubleshooting.md`. Updates: `references/updating.md`.

## Quick reference

```bash
python3 -m venv ~/.venvs/mlx && . ~/.venvs/mlx/bin/activate && pip install mlx-lm
mlx_lm.generate --model mlx-community/Llama-3.2-3B-Instruct-4bit --prompt "Say hi" --max-tokens 64
mlx_lm.server --model mlx-community/Llama-3.2-3B-Instruct-4bit --host 127.0.0.1 --port 8080 --max-tokens 4096
curl -s http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
```

| Command                                                                    | Purpose                                                                                    |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `mlx_lm.generate` / `mlx_lm.chat`                                          | One-shot generation / chat REPL (default model `mlx-community/Llama-3.2-3B-Instruct-4bit`) |
| `mlx_lm.server`                                                            | OpenAI-style HTTP server, default `127.0.0.1:8080`                                         |
| `mlx_lm.convert`                                                           | Convert and quantize HF weights to MLX                                                     |
| `mlx_lm.lora` / `mlx_lm.fuse`                                              | Train an adapter / merge it (optional upload or GGUF export)                               |
| `mlx_lm.perplexity`, `mlx_lm.evaluate`, `mlx_lm.benchmark`                 | Quality and speed checks                                                                   |
| `mlx_lm.cache_prompt`, `mlx_lm.manage`                                     | Prompt cache files / scan and delete cached models                                         |
| `mlx_vlm.generate`, `mlx_vlm.server`, `mlx_vlm.convert`, `mlx_vlm.chat_ui` | Vision, audio and omni models                                                              |

## Rules

- **Ask before changing the system.** `pip install`, `sudo sysctl iogpu.wired_limit_mb=N`, large downloads, `--upload-repo` and any non-loopback bind need approval and an undo path (`sudo sysctl iogpu.wired_limit_mb=0` restores the default).
- **Servers are not hardened.** Upstream: `mlx_lm.server` "is not recommended for production as it only implements basic security checks". It has no auth, and a request's `model` field can make it load another repo or local path. Keep it on `127.0.0.1` or behind a gateway.
- **Never print secrets.** Hugging Face tokens come from `hf auth login` or `HF_TOKEN`; mlx-vlm's `--api-key` shows in `ps`, so prefer a gateway or keep it off a shared host.
- **Leave RAM for macOS.** Raising the wired limit near total RAM can freeze the Mac. Keep at least 8 GB free on 32 GB+ machines.
- **`--max-tokens` defaults to 512** in `mlx_lm.server`; agents get truncated replies. Raise it.
- **Verify upstream.** MLX moves fast: pin versions in scripts.

## Workflows

- [ ] Install in a venv and check native arm64 Python -> `references/install.md`
- [ ] Run a 4-bit model, compare RAM against `hw.memsize` -> `references/apple-silicon.md`
- [ ] Serve and test `/health`, `/v1/models`, a chat completion -> `references/serving.md`
- [ ] Convert or quantize, then perplexity-check -> `references/convert-quantize.md`
- [ ] Fine-tune with LoRA, evaluate, fuse -> `references/fine-tuning.md`
- [ ] Verify: the server answers on loopback, `memory_pressure` is green, no swap growth (`sysctl vm.swapusage`).

## Reference index

- `references/install.md`: venv, packages, extras, versions, native Python.
- `references/serving.md`: `mlx_lm.server` flags, endpoints, request fields, caching, launchd.
- `references/vision.md`: `mlx-vlm` generate, server, endpoints, auth, conversion.
- `references/convert-quantize.md`: `mlx_lm.convert` flags, modes, recipes, AWQ/GPTQ/DWQ, publishing.
- `references/fine-tuning.md`: `mlx_lm.lora` data formats, memory tips, fuse, serve adapters.
- `references/apple-silicon.md`: discovery, memory sizing, wired limit, thermals.
- `references/updating.md`: upgrade and pin; `references/troubleshooting.md`: symptoms and fixes.
- `references/combos/lora-to-gguf.md`: export a fused adapter to GGUF (limits). `combos/llama-swap.md`: swap MLX models with llama-swap.
- `assets/mlx-lm-server.launchd.plist`: launchd job for `mlx_lm.server`.

## Companion skills

- `lm-studio`: GUI and daemon that also runs MLX models. Install: `npx skills add ScaleDockHQ/llm-skills --skill lm-studio`.
- `local-llms`: compare local runtimes. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `model-quantization`: quant formats across engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `fine-tuning-llms`: training strategy and adapter serving. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `llama-swap`: model swapping proxy. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `hugging-face`: hub auth and caches. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
