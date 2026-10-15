---
name: local-llms
description: Run LLMs locally on a laptop or desktop (macOS, Windows, Linux) with Ollama, LM Studio, llama.cpp (llama-server) or MLX (mlx-lm). Use when the user wants to install a local runtime, pick and size a model or GGUF/MLX quant for their RAM or VRAM (weights + KV cache + context length), serve an OpenAI- or Anthropic-compatible endpoint on localhost, connect a coding agent or chat app to it, share it on the LAN or over Tailscale safely, benchmark tokens per second, update, free disk space, or troubleshoot slow, CPU-offloaded, or failing models. Covers Apple Silicon (Metal, MLX, unified memory, GPU wired-memory limit), NVIDIA (CUDA), AMD (ROCm, Vulkan), Intel, Windows native vs WSL2, Linux drivers and systemd user services, ports 11434/1234/9931/8080, and keeping secrets out of output. Not for dedicated servers or multi-user hosting (use self-hosted-llms).
license: MIT
compatibility: Personal machines (macOS on Apple Silicon, Windows 10/11, Linux desktops). Discovery commands need a shell (bash/zsh or PowerShell); benchmarking needs curl and jq. Installs, sysctl changes, firewall rules and LAN exposure require the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.1.1"
---

# Local LLMs

Run open-weight LLMs on the user's own laptop or desktop and expose them as a local API that other tools can use.

**Scope:** personal machines with one user, usually one GPU or unified memory. For dedicated servers, multi-GPU boxes, DGX Spark, or serving many users, use **self-hosted-llms**. To decide between local, self-hosted, and cloud, use **choosing-llm-hosting**.

Work through the steps in order. Load a reference only when a step names it.

## 1. Discover first

Run these read-only commands before you recommend anything. Install nothing yet.

**macOS**

```bash
uname -m; sw_vers -productVersion
sysctl -n machdep.cpu.brand_string; sysctl -n hw.memsize          # chip, RAM bytes
system_profiler SPHardwareDataType SPDisplaysDataType            # memory, GPU cores
sysctl iogpu.wired_limit_mb                                      # 0 = default GPU wired limit
df -h ~                                                          # free disk
```

**Linux**

```bash
uname -m; head -4 /etc/os-release; free -h; df -h ~
lspci | grep -i -E 'vga|3d|display'
nvidia-smi --query-gpu=name,memory.total,memory.used,driver_version --format=csv
rocm-smi --showproductname --showmeminfo vram    # or: amd-smi static
vulkaninfo --summary; groups
```

**Windows (PowerShell)**

```powershell
$env:PROCESSOR_ARCHITECTURE; (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion
nvidia-smi --query-gpu=name,memory.total,memory.used,driver_version --format=csv
Get-PSDrive C
```

**Runtimes already installed or running (any OS)**

```bash
command -v ollama lms llama-server llama mlx_lm.server     # Windows: Get-Command ollama, lms, llama-server
ollama list; ollama ps
lms ls; lms ps; lms server status
curl -s http://127.0.0.1:11434/api/version                 # Ollama
curl -s http://127.0.0.1:1234/v1/models                    # LM Studio
curl -s http://127.0.0.1:9931/health                       # llama-server (current default port)
curl -s http://127.0.0.1:8080/health                       # mlx_lm.server, or older llama-server
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(11434|1234|9931|8080)\b'   # Linux: ss -ltnp; Windows: Get-NetTCPConnection -State Listen
```

Don't print API keys, tokens, or the contents of key files. Check that a key exists, never what it is.

**Ask only what you can't discover:** what the model is for (chat, coding agent, RAG/embeddings, vision), the context length they need, GUI or CLI, whether other devices must reach it, and how much disk they're willing to use.

## 2. Decide

**Runtime from OS and accelerator** (details: `references/choosing-a-runtime.md`)

| Machine              | Default                                       | Alternatives                                                |
| -------------------- | --------------------------------------------- | ----------------------------------------------------------- |
| Apple Silicon Mac    | LM Studio (GUI) or Ollama (CLI)               | mlx-lm for MLX models; llama-server for flags or an API key |
| Windows + NVIDIA     | Ollama or LM Studio (native CUDA)             | llama.cpp CUDA zip; WSL2 only if the toolchain lives there  |
| Windows/Linux + AMD  | Ollama (ROCm or Vulkan) or LM Studio (Vulkan) | llama.cpp Vulkan or ROCm build                              |
| Linux + NVIDIA       | Ollama (systemd service)                      | llama-server as a systemd user unit                         |
| Intel GPU / CPU only | llama.cpp (Vulkan/SYCL/CPU)                   | LM Studio, Ollama (CPU)                                     |

**Model size vs memory** (`references/sizing.md`): weights + KV cache at the needed context × parallel slots + overhead + OS headroom must fit in VRAM (or the Metal wired limit). If it doesn't fit, use a smaller quant, then a shorter context or quantized KV, then a smaller model. Partial CPU offload comes last.

**GUI vs CLI:** a GUI user gets LM Studio. A CLI or agent user gets Ollama or llama-server. If they need exact flags or an API key, use llama-server.

**Share on LAN?** Default to no. If yes, follow `references/sharing-on-lan.md`: SSH tunnel or Tailscale Serve first, an API key always.

## Rules

- **Size before you download.** Weights + KV cache + OS headroom must fit in GPU or unified memory. Compute it, don't guess.
- **Bind to localhost unless you mean it.** Every runtime defaults to `127.0.0.1`; only change that with the user's explicit consent and auth in place.
- **One runtime per port.** Ollama 11434, LM Studio 1234, llama-server 9931 (8080 on older builds), mlx_lm.server 8080. Check listeners before starting a server.
- **Measure before and after.** Every change gets the same fixed benchmark protocol.
- **Prefer the native accelerator path.** Metal/MLX on Apple Silicon, CUDA on NVIDIA, ROCm or Vulkan on AMD. Never an x86 binary under Rosetta.
- **Confirm it's on the GPU.** Check `ollama ps`, the load logs, or `--list-devices` before blaming the model.
- **Ask before changing the system.** Installers, `sudo sysctl`, firewall rules, services, and lingering all need approval and an undo path.
- **Secrets never touch output.** Generate keys into `0600` files, reference them by path or environment variable, and never echo, log, or commit them.

## Workflows

### Install a runtime

- [ ] Discovery done; runtime chosen from the table above.
- [ ] Driver prerequisites met (`references/windows.md`, `references/linux-desktop.md`, `references/macos-apple-silicon.md`).
- [ ] Install with the official method from the runtime reference (`references/ollama.md`, `references/lm-studio.md`, `references/llamacpp.md`, `references/mlx.md`), after the user approves.
- [ ] Verify the binary is native (`file "$(command -v <bin>)"`) and the GPU is visible (`llama-server --list-devices`, Ollama log, `lms runtime ls`).

### Pick and size a model

- [ ] Use case and needed context known.
- [ ] Usable memory computed; weights + KV cache + headroom fit (`references/sizing.md`).
- [ ] Pick the format for the runtime: GGUF (Ollama, LM Studio, llama.cpp) or MLX (mlx-lm, LM Studio on a Mac).
- [ ] Pick a quant: the largest of Q8_0 / Q6_K / Q5_K_M / Q4_K_M (or MLX 8/6/4-bit) that fits fully on the GPU.
- [ ] Check free disk before downloading. LM Studio: `lms load --estimate-only`.

### Run and serve an OpenAI-compatible endpoint

- [ ] Port free (one runtime per port).
- [ ] Start bound to `127.0.0.1` with an explicit context size:
  - Ollama: `OLLAMA_CONTEXT_LENGTH` → `http://127.0.0.1:11434/v1`
  - LM Studio: `lms load <m> --context-length N` then `lms server start` → `http://127.0.0.1:1234/v1`
  - llama.cpp: `llama-server -m|-hf ... -c N --host 127.0.0.1 --port 9931 -a local-model` → `http://127.0.0.1:9931/v1`
  - MLX: `mlx_lm.server --model ... --max-tokens N` → `http://127.0.0.1:8080/v1`
- [ ] Smoke test: `curl -s <base>/models`, then one `chat/completions` request.
- [ ] Optional background service: Ollama/LM Studio login items, `assets/llama-server.service` (Linux user unit), `assets/llama-server.launchd.plist` (macOS).
- [ ] Optional Ollama defaults: `assets/Modelfile.example`.

### Connect a client

- [ ] Give the client the base URL including `/v1`, the model name exactly as `/v1/models` reports it, and a key from a file or environment variable (or any placeholder string for keyless local servers).
- [ ] Anthropic-protocol clients: Ollama, LM Studio, and llama-server serve `/v1/messages` (base URL without `/v1`).
- [ ] For per-tool setup (Claude Code, Codex, OpenCode, Aider, Cursor, Continue, Cline/Roo/Kilo, Open WebUI, LobeHub, SDKs), use **llm-clients**. To put several backends behind one endpoint, use **llm-gateway**.

### Share on LAN securely

- [ ] User explicitly wants it; prefer an SSH tunnel or `tailscale serve` (never `funnel`).
- [ ] Runtime-enforced key (llama-server `--api-key-file`, LM Studio Require Authentication) or an authenticating proxy. Ollama and mlx_lm.server have no auth.
- [ ] Firewall scoped to the subnet and port; undo documented; 401 without a key and 200 with it, verified from a second device (`references/sharing-on-lan.md`).

### Benchmark

- [ ] Fixed protocol from `references/benchmarking.md`: AC power, one server, model fully on the GPU, warmup, same prompt/max tokens, median of N runs.
- [ ] `scripts/bench.sh --base-url URL --model NAME [--runs N] [--warmup N] [--max-tokens N] [--prompt-tokens N] [--concurrency N] [--key-file PATH] [--timeout SECONDS]` (env `LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY`; `--help` for details). It reports median TTFB and decode tok/s, plus prefill tok/s with `--prompt-tokens` and aggregate tok/s with `--concurrency`.
- [ ] Record versions, quant, context, flags, and power state with the results.
- [ ] For quality rather than speed, use **llm-evals**.

### Update

- [ ] Benchmark first, so you have a baseline.
- [ ] Ollama: app auto-update, or re-run the install script on Linux. LM Studio: in-app update, or `lms daemon update` (with the daemon down) and `lms runtime update`. llama.cpp: `brew upgrade` / `winget upgrade` / a new release. MLX: `pip install -U mlx-lm` in its venv.
- [ ] Re-run the smoke test and the benchmark. Watch for changed defaults (for example, llama-server's default port).

### Clean up disk

- [ ] Inventory first: `ollama ls`; `lms ls`; `hf cache ls`; `llama-server -cl`; `du -sh` on the model directories.
- [ ] Delete only what the user confirms: `ollama rm <m>`; LM Studio My Models; `hf cache rm <repo>` / `hf cache prune`.
- [ ] Move stores rather than deleting them when space is the issue (`OLLAMA_MODELS`, LM Studio models directory, `HF_HOME`, `LLAMA_CACHE`).

### Troubleshoot

- [ ] Re-run discovery and read the runtime's logs.
- [ ] Match the symptom in `references/troubleshooting.md`: wrong port, CPU offload, wired limit, context too small, template/tool-call errors, 401/403, CORS.
- [ ] Change one thing at a time; re-run the smoke test and benchmark.

## Reference index

| File                                | Load when                                                    |
| ----------------------------------- | ------------------------------------------------------------ |
| `references/choosing-a-runtime.md`  | Comparing Ollama, LM Studio, llama.cpp, MLX (plus Jan)       |
| `references/sizing.md`              | Will it fit: quants, KV cache formula, headroom, offloading  |
| `references/macos-apple-silicon.md` | Unified memory, Metal, MLX, `iogpu.wired_limit_mb`, thermals |
| `references/windows.md`             | CUDA, AMD ROCm/Vulkan, WSL2 vs native, firewall prompts      |
| `references/linux-desktop.md`       | Drivers, CUDA/ROCm/Vulkan builds, systemd user services      |
| `references/ollama.md`              | Ollama install, environment variables, endpoints, pitfalls   |
| `references/lm-studio.md`           | LM Studio GUI, `lms` CLI, llmster headless, API tokens       |
| `references/llamacpp.md`            | `llama-server` install, flags, auth, router mode             |
| `references/mlx.md`                 | `mlx-lm` install, `mlx_lm.server` flags                      |
| `references/sharing-on-lan.md`      | SSH tunnel, Tailscale Serve, API keys, firewall rules        |
| `references/benchmarking.md`        | Fixed protocol with `scripts/bench.sh`, fair comparisons     |
| `references/troubleshooting.md`     | Symptom → cause → fix                                        |
| `assets/`                           | systemd user unit, launchd plist, Ollama Modelfile           |

## Companion skills

Install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- **choosing-llm-hosting**: local vs self-hosted vs cloud.
- **self-hosted-llms**: dedicated servers, vLLM/SGLang, DGX Spark, multi-user serving.
- **cloud-llms**: hosted APIs and GPU clouds.
- **llm-clients**: connect agents, IDEs, and chat UIs to the endpoint.
- **llm-gateway**: one endpoint over several backends (LiteLLM and similar).
- **llama-cpp**, **ollama**, **lm-studio**, **mlx**: runtime depth.
- **llama-swap**: model swapping across local runtimes.
- **model-quantization**: produce your own GGUF/MLX/EXL3 quants.
- **fine-tuning-llms**, **llm-evals**, **llm-observability**, **self-hosted-genmedia** (image, video, and speech).
