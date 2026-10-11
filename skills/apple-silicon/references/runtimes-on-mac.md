# Runtimes on a Mac

> Verified against Ollama v0.40.3, LM Studio 0.4.26, llama.cpp b11557 (Homebrew 0.6.0 formula), mlx 0.32.3, mlx-lm 0.32.0, 2026-10-11

Depth lives in the product skills; this table is the platform-side view. Check `command -v <bin>` and `file` for arm64 first.

| Runtime   | Native install on Apple Silicon                                                                       | Default port and API                          | Models and logs                                                          | Skill       |
| --------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------ | ----------- |
| Ollama    | `curl -fsSL https://ollama.com/install.sh \| sh` or `Ollama.dmg` (Metal; macOS 14+); also in Homebrew | `127.0.0.1:11434`, native + OpenAI-compatible | `~/.ollama/models`; logs `~/.ollama/logs/server.log`, `app.log`          | `ollama`    |
| LM Studio | `.dmg` from lmstudio.ai (macOS 14+); MLX engine for MLX models, llama.cpp/Metal for GGUF; `lms` CLI   | `:1234`, OpenAI, Anthropic and native REST    | the app's My Models tab (usually under `~/.lmstudio/`); `lms log stream` | `lm-studio` |
| llama.cpp | `brew install llama.cpp` (Metal on) or the `macos-arm64` release archive                              | you choose (`--port`), OpenAI-compatible      | `-hf` downloads use their own cache; GGUF files anywhere                 | `llama-cpp` |
| MLX       | `pip install mlx-lm` in a native arm64 venv (Python 3.11+), or `conda install -c conda-forge mlx-lm`  | `mlx_lm.server`, `127.0.0.1:8080`             | Hugging Face cache `~/.cache/huggingface/hub` (`HF_HOME` overrides)      | `mlx`       |

## Choosing

- Start with LM Studio for a GUI and JIT loading; Ollama for a CLI, an always-on daemon and a large ecosystem of clients.
- Use MLX builds when one exists for the model and you want the native path or LoRA fine-tuning; use GGUF with Metal when you need exact flags, an API key (`llama-server --api-key-file`) or a quant MLX lacks.
- Very low-bit IQ quants can be slower on Metal than K-quants of similar size; Q4_K_M to Q6_K are the safe range (community).
- Flash attention is `auto` in llama.cpp and Ollama; leave it unless debugging.

## Checks

```bash
llama-server --version; llama-server --list-devices          # should list the Apple GPU (Metal)
lms ps; ollama ps                                             # what is resident right now
hf cache ls 2>/dev/null | head                                # huggingface_hub CLI cache listing
```

Do not run two runtimes with big models resident at once: they compete for the same unified memory and for the wired limit.

## Official links

- https://docs.ollama.com/macos
- https://lmstudio.ai/docs/app/system-requirements
- https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md
- https://github.com/ml-explore/mlx-lm
