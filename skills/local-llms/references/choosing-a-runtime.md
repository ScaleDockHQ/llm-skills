# Choosing a local runtime

> Verified against Ollama v0.40.3, llama.cpp b11555 (default port 9931 since b11521; the v0.6.0 release still uses 8080), LM Studio 0.4.26, mlx-lm 0.32.0, Jan v0.8.6, 2026-10-11

This page helps you choose between the four main runtimes for running LLMs on a personal laptop or desktop. Each runtime has its own reference page in this folder; this one only compares them.

## The short answer

| Situation                                                                                                  | Pick                           | Why                                                                                                    |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------ |
| You want the simplest install, a CLI, and an API that most tools already know                              | **Ollama**                     | One installer per OS, background service, model library, OpenAI- and Anthropic-compatible endpoints    |
| You want a GUI to browse, download, and chat, and also a local server                                      | **LM Studio**                  | Desktop app with Hugging Face search, a memory estimate before loading, `lms` CLI, optional API tokens |
| You want full control of flags, any GGUF from Hugging Face, an API key, and the newest model support first | **llama.cpp (`llama-server`)** | The upstream engine that Ollama and LM Studio build on. Every knob is exposed                          |
| You have an Apple Silicon Mac and want the fastest native path or MLX-format models                        | **MLX (`mlx-lm`)**             | Apple's array framework. Runs MLX-quantized models from the `mlx-community` Hugging Face org           |

LM Studio also runs MLX models on Apple Silicon through its MLX engine, so a GUI user on a Mac does not need to install `mlx-lm` separately.

## Comparison

|                          | Ollama                                                 | LM Studio                                          | llama.cpp                                         | mlx-lm                                             |
| ------------------------ | ------------------------------------------------------ | -------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------- |
| Interface                | CLI and menu-bar/tray app                              | GUI, `lms` CLI, headless `llmster` daemon          | CLI binaries and built-in web UI                  | Python CLI                                         |
| Model formats            | Ollama library, GGUF import, safetensors import        | GGUF; MLX on Apple Silicon                         | GGUF                                              | MLX safetensors                                    |
| Default bind             | `127.0.0.1:11434`                                      | `127.0.0.1:1234`                                   | `127.0.0.1:9931`                                  | `127.0.0.1:8080`                                   |
| OpenAI-compatible base   | `http://localhost:11434/v1`                            | `http://localhost:1234/v1`                         | `http://localhost:9931/v1`                        | `http://localhost:8080/v1`                         |
| Anthropic `/v1/messages` | Yes                                                    | Yes                                                | Yes                                               | No                                                 |
| Built-in API key         | No                                                     | Yes (API tokens, toggle in server settings)        | Yes (`--api-key`, `--api-key-file`)               | No                                                 |
| Accelerators             | Metal, CUDA, ROCm, Vulkan                              | Metal/MLX, CUDA, Vulkan, CPU (runtimes selectable) | Metal, CUDA, HIP/ROCm, Vulkan, SYCL, CPU and more | Metal (Apple Silicon only)                         |
| Multiple models          | Loads several, unloads idle ones (`OLLAMA_KEEP_ALIVE`) | Just-in-time loading with TTL auto-unload          | Router mode (`llama-server` with no model)        | One model per server, plus an optional draft model |

The llama.cpp default port changed from 8080 to 9931 in build b11521 (2026-10-09). Older builds (including the v0.6.0 release), many blog posts, and the official Docker examples (which pass `--port 8080`) use 8080. Check the startup log line or `--help` instead of assuming.

## Decision rules

1. **Apple Silicon Mac.** Start with LM Studio (GUI) or Ollama (CLI). Use `mlx-lm` when an MLX build of the model exists and you want the native path. Use `llama-server` when you need an API key or exact flags. See `macos-apple-silicon.md`.
2. **Windows with NVIDIA.** Ollama or LM Studio run natively with CUDA. Use the `llama.cpp` CUDA zip when you want flags. Use WSL2 only if your other tooling lives there. See `windows.md`.
3. **Windows or Linux with AMD.** Check the ROCm support list first. If your GPU is not on it, use a Vulkan build: Ollama enables Vulkan by default, LM Studio has a Vulkan runtime, and llama.cpp ships Vulkan binaries. See `windows.md` or `linux-desktop.md`.
4. **Linux desktop with NVIDIA.** All four options work except MLX. Ollama installs a systemd service. `llama-server` fits a systemd user unit (`assets/llama-server.service`).
5. **You need an API key, for example to share on the LAN.** Use `llama-server --api-key-file` or LM Studio with authentication enabled. Ollama and `mlx_lm.server` have no built-in key, so put an authenticating proxy in front or keep them on localhost. See `sharing-on-lan.md`.
6. **A coding agent with long prompts.** Raise the context window: Ollama defaults to as little as 4k on small-VRAM machines. Size the KV cache first (`sizing.md`).

## Others

- **Jan** (v0.8.6) is an open-source desktop chat app built on llama.cpp. Its OpenAI-compatible local server listens on `localhost:1337`. It is a good choice if you want a fully open-source GUI. Its settings are not covered in depth here.
- **Docker** images exist for Ollama (`ollama/ollama`) and llama.cpp (`ghcr.io/ggml-org/llama.cpp:server`). On macOS, Docker Desktop has no GPU passthrough, so containers run on the CPU only. Prefer native installs on Macs.

## Official links

- Ollama: https://ollama.com and https://docs.ollama.com
- LM Studio: https://lmstudio.ai/docs
- llama.cpp: https://github.com/ggml-org/llama.cpp
- mlx-lm: https://github.com/ml-explore/mlx-lm
- Jan: https://github.com/janhq/jan
