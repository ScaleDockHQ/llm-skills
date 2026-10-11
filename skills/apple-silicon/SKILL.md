---
name: apple-silicon
description: Size, tune and operate Apple Silicon Macs (M-series MacBook, Mac mini, Mac Studio) for local LLM inference with Metal and MLX. Use for unified memory sizing, iogpu.wired_limit_mb, "[WARNING] Generating with a model that requires", kIOGPUCommandBufferCallbackErrorOutOfMemory, Rosetta or x86_64 binaries, thermal throttling, keeping a Mac awake as an LLM server, Thunderbolt 5 RDMA. Picks runtime (Ollama, LM Studio, llama.cpp, MLX); not their flags.
license: MIT
compatibility: macOS 14+ on Apple Silicon (M1 or newer), zsh, curl and jq. Intel Macs are CPU-only. sudo sysctl changes, power settings, launchd services, installs and network exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Apple Silicon

Get a Mac from unknown state to a stable local inference host: native arm64 runtimes, a memory budget that fits unified memory, the GPU wired-memory limit understood, thermals and sleep handled, and a clear way to run it as an always-on server.

**Scope:** the platform. Runtime flags and recipes belong to the product skills (`mlx`, `lm-studio`, `ollama`, `llama-cpp`); choosing between runtimes belongs to `local-llms`; sizing across hardware belongs to `choosing-hardware`; clustering several Macs belongs to `mac-cluster-exo-mlx`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets and nothing needs sudo.

```bash
uname -m; sw_vers -productVersion; sysctl -n sysctl.proc_translated   # arm64, macOS version, 1 = shell under Rosetta (bad)
sysctl -n machdep.cpu.brand_string hw.memsize                          # chip and RAM (bytes)
system_profiler SPHardwareDataType SPDisplaysDataType | grep -E 'Model Name|Chip|Cores|Memory|Metal'
sysctl iogpu.wired_limit_mb                                            # 0 = system default GPU wired limit, not unlimited
memory_pressure | tail -2; sysctl vm.swapusage                         # free percentage, swap in use
pmset -g therm; pmset -g | grep -E 'lowpowermode|^ sleep'              # throttling notes, low power mode, sleep
pmset -g batt | head -2                                                # AC or battery
rdma_ctl status 2>/dev/null                                            # Thunderbolt 5 RDMA enabled or disabled (macOS 26.2+)
for b in ollama lms llama-server mlx_lm.server; do command -v $b && file "$(command -v $b)" | grep -o 'arm64\|x86_64'; done
```

## Decision flow

1. Intel Mac or `proc_translated` = 1: stop and fix first. MLX needs native arm64, Metal needs an arm64 binary. `references/hardware-and-os.md`.
2. Pick a runtime for the job: GUI and JIT loading (LM Studio), CLI and always-on daemon (Ollama), exact flags and API keys (`llama-server`), native MLX formats and fine-tuning (`mlx-lm`). Table in `references/runtimes-on-mac.md`.
3. Size the model before loading: weights + KV + headroom for macOS and apps against unified memory. `references/memory.md`.
4. "Requires ..." warning, GPU out-of-memory or slow load on a model that fits in RAM: the wired limit. Ask before `sudo sysctl`. `references/memory.md`.
5. Slow after a while, fan noise, battery: thermals and power. `references/power-and-thermals.md`.
6. Always-on server (sleep, login items, launchd, LAN exposure): `references/operating.md`.
7. More memory than one Mac has: `mac-cluster-exo-mlx` (Thunderbolt 5, RDMA, exo). Remote access to a single Mac: `tailscale`.
8. Anything failing: `references/troubleshooting.md`. Updating macOS or runtimes: `references/updating.md`.

## Rules

- **Ask before changing the system.** `sudo sysctl iogpu.wired_limit_mb`, `pmset`, launchd services, firewall changes and installs need approval, the exact value, and the undo command.
- **Native arm64 only.** Never run x86_64 binaries or Python under Rosetta; they cannot use Metal or MLX.
- **Docker Desktop has no GPU passthrough on macOS.** Containers run on CPU; run inference on the host.
- **Memory is shared.** Leave real headroom for macOS, the browser and the IDE; swap growth during generation means the model does not fit.
- **Do not raise the wired limit to fix a model that does not fit.** Use a smaller quant or context first.
- **Benchmark on AC power and outside Low Power Mode,** with fixed lengths and a cool-down between runs.
- **Loopback by default.** Bind to `0.0.0.0` only with a token and a reason (`tailscale` or `llm-gateway` for sharing).
- **Verify upstream.** Versions, OS requirements and flags change; re-read the runtime's docs and release notes.

## Workflows

- [ ] Baseline: run Discover; record chip, RAM, macOS, wired limit, runtimes -> `references/hardware-and-os.md`
- [ ] Choose runtime and install the native build -> `references/runtimes-on-mac.md`
- [ ] Memory budget for the target model and context -> `references/memory.md`
- [ ] Wired limit only if the model fits RAM but warns or refuses (with approval) -> `references/memory.md`
- [ ] Power, sleep and thermals for the intended use -> `references/power-and-thermals.md`
- [ ] Always-on service and exposure -> `references/operating.md`
- [ ] Verify: runtime reports the Apple GPU or MLX, `memory_pressure` is green, swap does not grow during a long generation, `pmset -g therm` shows no warnings, and the server answers on loopback.

## Reference index

- `references/hardware-and-os.md`: chips, OS requirements per runtime, Rosetta, Intel Macs.
- `references/memory.md`: unified-memory budget, wired limit, KV cache levers.
- `references/runtimes-on-mac.md`: Ollama, LM Studio, llama.cpp, MLX install, ports, paths.
- `references/power-and-thermals.md`: fanless limits, Low Power Mode, benchmarking, `powermetrics`.
- `references/operating.md`: sleep, login items, launchd, logs, disk, LAN exposure.
- `references/troubleshooting.md`: symptom to fix.
- `references/updating.md`: macOS and runtime updates, re-checking limits.

## Companion skills

- `mlx`, `lm-studio`, `ollama`, `llama-cpp`: runtimes. Install: `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
- `local-llms`: choose a runtime, benchmark, share on a LAN. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `choosing-hardware`: size models across hardware. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `mac-cluster-exo-mlx`: several Macs as one cluster. Install: `npx skills add ScaleDockHQ/llms-skills --skill mac-cluster-exo-mlx`.
- `tailscale`: private remote access. Install: `npx skills add ScaleDockHQ/llms-skills --skill tailscale`.
