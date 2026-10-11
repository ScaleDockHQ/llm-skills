# macOS on Apple Silicon

> Verified against macOS 15+ (`iogpu.wired_limit_mb` via mlx-lm 0.32.0 README), mlx 0.32.3, llama.cpp b11555, Ollama v0.40.3, LM Studio 0.4.26, 2026-10-11

## What it is and when to choose it

Apple Silicon Macs (M-series) share one pool of unified memory between the CPU and GPU. That means a Mac with a lot of RAM can load models that would need a large discrete GPU on a PC. Decode speed depends mostly on memory bandwidth, which is higher on Pro, Max, and Ultra chips. Prompt processing (prefill) depends on GPU compute and is usually the weak spot compared with NVIDIA.

Intel Macs: Ollama runs CPU-only, LM Studio does not support them, and MLX requires Apple Silicon. llama.cpp's `macos-x64` build is the remaining option.

## Discover

```bash
uname -m                                   # arm64 = Apple Silicon
sysctl -n machdep.cpu.brand_string         # e.g. "Apple M3 Max"
sysctl -n hw.memsize                       # total RAM in bytes
system_profiler SPHardwareDataType SPDisplaysDataType   # chip, memory, GPU cores
sw_vers -productVersion                    # macOS version
sysctl iogpu.wired_limit_mb                # 0 = system default GPU wired limit
memory_pressure                            # current memory pressure summary
pmset -g therm                             # thermal/performance throttling warnings
```

## Install (native accelerator path)

- **Ollama:** `curl -fsSL https://ollama.com/install.sh | sh`, or the `Ollama.dmg` app. Uses Metal. Requires macOS 14+.
- **LM Studio:** the `.dmg` from lmstudio.ai. Requires macOS 14+. Uses MLX for MLX models and llama.cpp/Metal for GGUF.
- **llama.cpp:** `brew install llama.cpp` (Metal enabled), or the `llama-<build>-bin-macos-arm64.tar.gz` release.
- **mlx-lm:** `pip install mlx-lm` in a virtual environment, or `conda install -c conda-forge mlx-lm`. Requires Python 3.11+.

Do not run the x86_64 version of a binary or Python under Rosetta. It cannot use Metal or MLX. Check with `file "$(command -v llama-server)"` (it should say `arm64`). `sysctl -n sysctl.proc_translated` prints `1` if the current shell is running under Rosetta.

## Minimal working config

```bash
# GGUF with Metal (all layers on GPU is the default on Apple Silicon)
llama-server -hf ggml-org/<model>-GGUF:Q4_K_M -c 16384 --host 127.0.0.1 --port 9931

# MLX
mlx_lm.server --model mlx-community/<model>-4bit --host 127.0.0.1 --port 8080
```

## GPU wired-memory limit (`iogpu.wired_limit_mb`)

By default macOS caps how much unified memory the GPU may *wire*, meaning pin so it can't be paged out. Models larger than that cap load slowly, are refused, or spill to the CPU. mlx-lm's README documents raising it:

```bash
sysctl iogpu.wired_limit_mb                 # read; 0 means "system default", not unlimited
sudo sysctl iogpu.wired_limit_mb=N          # N in MB: larger than the model, smaller than total RAM
sudo sysctl iogpu.wired_limit_mb=0          # revert to the default
```

Behavior and risks:
- It takes effect immediately. Restart the runtime so it picks up the new limit.
- It resets at reboot. Persisting it (`/etc/sysctl.conf` or a root LaunchDaemon) is possible but not recommended, because every boot then runs with less headroom. *(Reset-on-reboot and persistence methods come from community sources, not Apple documentation.)*
- Setting it close to total RAM can starve macOS and lead to heavy swapping, freezes, or a kernel panic. Leave at least 8 GB for the system on 32 GB+ machines, and more if you keep a browser, IDE, or VM open.
- It does not create memory. It only changes how much of the existing RAM the GPU may lock.
- It changes system state and needs `sudo`. **Ask the user before running it**, and say how to revert it.
- mlx-lm wires model memory itself (macOS 15+). If you see `[WARNING] Generating with a model that requires ...`, the model is larger than the wired limit.

## How it plugs in

Same as each runtime: Ollama `:11434`, LM Studio `:1234`, llama-server `:9931`, mlx_lm.server `:8080`, all on localhost by default. The macOS Application Firewall asks to "accept incoming network connections" the first time a binary listens on a non-loopback address. Decline the prompt unless you intend to share on the LAN.

## Operating

- Ollama app logs: `~/.ollama/logs/server.log`. Models: `~/.ollama/models`.
- LM Studio models: the directory shown in the app's **My Models** tab, where you can also change it (usually under `~/.lmstudio/`). Logs: `lms log stream`.
- Hugging Face cache (llama.cpp `-hf` uses its own cache, `mlx-lm` uses the HF cache): `~/.cache/huggingface/hub` unless `HF_HOME` is set. List and clean it with `hf cache ls`, `hf cache rm`, and `hf cache prune` (huggingface_hub CLI).
- Background service: Ollama and LM Studio register login items. For llama-server, use `templates/llama-server.launchd.plist`.

## Thermals and power

- MacBook Air models have no fan and throttle during sustained generation. Benchmark with fixed run lengths and a cool-down between runs (`benchmarking.md`).
- On battery, macOS may lower performance, so benchmark on AC power. In Low Power Mode (`pmset -g | grep lowpowermode`), results are not comparable.
- To watch GPU power and frequency: `sudo powermetrics --samplers gpu_power -i 1000 -n 5` (read-only, needs sudo).

## Tuning knobs worth knowing

- Prefer MLX builds or GGUF Q4_K_M–Q6_K. Very low-bit IQ quants can be slower on Metal than K-quants of a similar size.
- Flash attention is `auto` in llama.cpp and Ollama. Leave it unless you are debugging.
- `mlx_lm.server --prefill-step-size` lowers peak memory during long prompts.
- Close memory-heavy apps before loading a model that is close to the limit.

## Known pitfalls

- Docker Desktop on macOS has no GPU passthrough, so containers run on the CPU only.
- A runtime that reports "100% CPU" on an M-series Mac usually means an x86_64 binary under Rosetta, or a model larger than the wired limit.
- Swap use (`sysctl vm.swapusage`) during generation means the model doesn't fit. Choose a smaller quant instead of raising the wired limit further.

## Official links

- mlx-lm (large models / wired limit): https://github.com/ml-explore/mlx-lm#large-models
- MLX: https://github.com/ml-explore/mlx
- Ollama macOS: https://docs.ollama.com/macos
- LM Studio system requirements: https://lmstudio.ai/docs/app/system-requirements
- llama.cpp Metal build: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#metal-build
