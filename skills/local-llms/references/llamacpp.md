# llama.cpp (`llama-server`)

> Verified against llama.cpp b11555 (common/common.h, tools/server/README.md; default port 9931 since b11521, 8080 in v0.6.0 and earlier), 2026-10-11

## What it is and when to choose it

llama.cpp is the C/C++ inference engine for GGUF models. Ollama, LM Studio, Jan, and others build on it. `llama-server` is its HTTP server: OpenAI- and Anthropic-compatible endpoints, a built-in web UI, an optional API key, Prometheus metrics, and a router mode for multiple models. Choose it when you want exact control of flags, an API key, the newest model support, or a backend the friendlier apps don't ship (SYCL, a specific ROCm, OpenVINO).

## Install

- **macOS/Linux:** `brew install llama.cpp` (Metal on macOS). Also MacPorts (`sudo port install llama.cpp`), Nix (`nix profile install nixpkgs#llama-cpp`), and conda-forge (`conda install -c conda-forge llama.cpp`).
- **Windows:** `winget install llama.cpp`.
- **Official installer:** `curl -LsSf https://llama.app/install.sh | sh` (macOS/Linux) or `irm https://llama.app/install.ps1 | iex` (Windows). This installs a single `llama` binary into `~/.local/bin`, used as `llama serve -hf <repo>` and `llama cli -hf <repo>`. It probes for CUDA/ROCm at install time. The rest of this page uses `llama-server`; `llama serve` is the equivalent subcommand *(argument parity with `llama-server` is assumed; confirm with `llama serve --help`)*.
- **Release archives** (https://github.com/ggml-org/llama.cpp/releases), named `llama-<build>-bin-<os>-<backend>-<arch>`:
  - macOS: `macos-arm64`, `macos-x64`
  - Windows: `win-cuda-<ver>-x64` (plus `cudart-llama-bin-win-cuda-<ver>-x64.zip` in the same folder), `win-vulkan-x64`, `win-rocm-<ver>-x64`, `win-sycl-x64`, `win-cpu-x64`, `win-cpu-arm64`, `win-vulkan-arm64`
  - Linux: `ubuntu-x64` (CPU), `ubuntu-vulkan-x64`, `ubuntu-cuda-<ver>-x64` (plus the `cudart-` tarball), `ubuntu-rocm-<ver>-x64`, `ubuntu-sycl-fp16-x64`, and arm64 variants
- **Docker:** `ghcr.io/ggml-org/llama.cpp:server` and `:server-cuda`.

## Minimal working config

```bash
# Download from Hugging Face (defaults to Q4_K_M if present) and serve on localhost
llama-server -hf ggml-org/<model>-GGUF:Q4_K_M -c 32768 --host 127.0.0.1 --port 9931

# Local file, explicit GPU layers, API key from a file, stable model name
llama-server -m ~/models/<model>-Q4_K_M.gguf -c 32768 -ngl all \
  --host 127.0.0.1 --port 9931 --api-key-file ~/.config/llama-server/keys -a local-model
```

## How it plugs in

| Item | Value |
| --- | --- |
| Default bind | `127.0.0.1:9931` (`--host`, `--port`; env `LLAMA_ARG_HOST`, `LLAMA_ARG_PORT`). **Builds before b11521 (including the v0.6.0 release) use 8080, and the Docker examples pass `--port 8080`** |
| Health | `GET /health` (also `/v1/health`), public: `503` while loading, `200 {"status":"ok"}` when ready |
| OpenAI-compatible | `http://localhost:9931/v1`: `/v1/models`, `/v1/chat/completions`, `/v1/completions`, `/v1/responses`, `/v1/embeddings` |
| Anthropic-compatible | `/v1/messages`, `/v1/messages/count_tokens` |
| Other | `/props`, `/slots`, `/metrics` (with `--metrics`), `/tokenize`, `/infill`, `/reranking`; web UI at `/` |
| Auth | `--api-key KEY[,KEY2]` (env `LLAMA_API_KEY`) or `--api-key-file PATH` (one key per line, `#` comments). Clients send `Authorization: Bearer <key>` (Anthropic clients: `x-api-key`) |
| TLS | `--ssl-key-file`, `--ssl-cert-file` |

Prefer `--api-key-file` to `--api-key`: command lines show up in `ps` output and shell history.

## Flags worth knowing

| Flag | Meaning |
| --- | --- |
| `-m, --model FNAME` / `-hf <user>/<model>[:quant]` | Local GGUF / Hugging Face download (`HF_TOKEN` for gated repos) |
| `-c, --ctx-size N` | Context size. `0` = the model's trained maximum (default) |
| `-ngl, --n-gpu-layers N\|auto\|all` | Layers on the GPU (default `auto`) |
| `--fit on\|off` | Auto-adjust unset arguments to fit device memory (default `on`); `--fit-target MiB` sets the margin (default 1024) |
| `-fa, --flash-attn on\|off\|auto` | Flash attention (default `auto`) |
| `-ctk` / `-ctv TYPE` | KV cache type: `f16` (default), `q8_0`, `q4_0`, ... |
| `-np, --parallel N` | Server slots (default auto) |
| `--jinja` / `--no-jinja` | Jinja chat templates (enabled by default; needed for tool calling) |
| `--chat-template-file` | Override a broken embedded template |
| `--reasoning-format`, `--reasoning-budget N` | Control thinking output |
| `-a, --alias NAME` | Model name returned by `/v1/models` and accepted in requests |
| `-cmoe, --cpu-moe` / `-ncmoe, --n-cpu-moe N` | Keep MoE expert weights in system RAM |
| `-ot, --override-tensor PATTERN=BUFTYPE` | Place specific tensors on specific devices |
| `-dev, --device` / `--list-devices` | Choose or list backends/devices |
| `-t, --threads N` | CPU threads |
| `--metrics` | Prometheus `/metrics` |
| `--sleep-idle-seconds N` | Unload the model after N idle seconds; it reloads on the next request |
| `--models-dir PATH`, `--models-preset INI` | Router mode (start without `-m` to serve several models) |
| `--no-webui` | Disable the built-in UI |
| `--offline` | Use the cache only, no network |
| `--log-file FNAME`, `-v` | Logging |

Nearly every flag has a `LLAMA_ARG_*` environment variable, which is handy in service files. `llama-server --help` is the authority for the binary you have installed.

## Operating

- Foreground: run it in a terminal; Ctrl-C stops it.
- Background: `templates/llama-server.service` (Linux systemd user unit) or `templates/llama-server.launchd.plist` (macOS LaunchAgent).
- Logs: stdout/stderr, or `--log-file`. Under systemd, `journalctl --user -u llama-server -f`.
- Update: `brew upgrade llama.cpp`, `winget upgrade llama.cpp`, re-run the llama.app installer, or download a newer release. Builds are published several times a day; update on purpose, not constantly.
- Model cache for `-hf`: controlled by `LLAMA_CACHE`; `-cl, --cache-list` lists it.
- Benchmark the engine alone: `llama-bench -m model.gguf` (it ships alongside). For end-to-end HTTP numbers, use `scripts/bench.sh`.

## Known pitfalls

- **Wrong port:** clients configured for `:8080` won't reach a current build on `:9931`. Pass `--port` explicitly and write it down.
- **Tool calls fail or come back as plain text:** the template is missing or broken. Keep `--jinja`, try `--chat-template-file`, and update to a newer build.
- **`--host 0.0.0.0` without `--api-key-file`:** anyone on the network can use it, and the web UI too. Since `/health` is always public, a health check succeeding proves nothing about auth.
- **CUDA zip without cudart:** missing DLLs, or a silent CPU fallback.
- **Out of memory at load:** lower `-c`, use `-ctk q8_0 -ctv q8_0`, or let `--fit on` reduce `-ngl`.
- `--agent` / `--ui-mcp-proxy` enable tools and a CORS proxy. Upstream says not to enable them in untrusted environments.

## Official links

- Server README (all flags and endpoints): https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Install: https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md
- Build: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- Releases: https://github.com/ggml-org/llama.cpp/releases
- Installer: https://llama.app
