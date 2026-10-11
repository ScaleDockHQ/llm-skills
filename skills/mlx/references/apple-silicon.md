# MLX on Apple Silicon: memory sizing, wired limit, thermals

> Verified against mlx-lm 0.32.0 (README "Large Models", mlx_lm/utils.py wired-limit helper) and mlx 0.32.3 install docs, 2026-10-11

macOS behaviour not stated in upstream docs is marked (OS) or (community).

## Discover

```bash
uname -m                                   # arm64
sysctl -n machdep.cpu.brand_string         # e.g. "Apple M3 Max"
sysctl -n hw.memsize                       # total unified memory, bytes
sw_vers -productVersion                    # macOS 14+ for MLX; 15+ for mlx-lm's automatic wiring
sysctl iogpu.wired_limit_mb                # 0 = system default (not unlimited)
memory_pressure | tail -3                  # system-wide memory pressure
sysctl vm.swapusage                        # swap in use (growth during generation means "does not fit")
pmset -g therm                             # throttling warnings
sysctl -n sysctl.proc_translated           # 1 = this shell runs under Rosetta (bad: MLX needs native arm64)
```

## Sizing

Unified memory is shared by CPU and GPU. Rough budget (arithmetic, not an upstream rule): weights in GB are about parameters in billions times bits per weight divided by 8, plus the KV cache (grows with context and batch) plus 4 GB or more for macOS and apps. A 4-bit 8B model is roughly 4.5-5 GB of weights. If `memory_pressure` is yellow or red, or swap grows while generating, pick a smaller model or quant, or cut context. Do not "fix" it by raising the wired limit further.

Memory levers inside mlx-lm: a smaller `--prefill-step-size` (default 2048) lowers peak memory on long prompts; `--max-kv-size n` on `mlx_lm.generate` caps the rotating KV cache; `--kv-bits 4|8` quantizes the KV cache (the server then stops batching; keep prefill small, see `serving.md`).

## The wired limit (`iogpu.wired_limit_mb`)

mlx-lm wires the memory used by the model and cache itself (macOS 15 or higher). If a model is large relative to RAM, mlx-lm prints:

> [WARNING] Generating with a model that requires ...

It will then likely be slow. If the model does fit in RAM, README's remedy is to raise the system wired-memory limit:

```bash
sysctl iogpu.wired_limit_mb                 # read, no sudo
sudo sysctl iogpu.wired_limit_mb=N          # N in MB: larger than the model, smaller than total RAM
sudo sysctl iogpu.wired_limit_mb=0          # revert to the system default
```

Rules for the agent:

- It changes system state and needs `sudo`: **ask first**, state N and how to revert.
- Pick N from the real model size plus KV cache plus headroom, not "total minus a little". Leave at least 8 GB for macOS on 32 GB+ machines, more with a browser, IDE or VM open. Too high can starve macOS: heavy swapping, freezes or a kernel panic (community reports, not upstream).
- It takes effect immediately; restart the MLX process so it uses the new limit. (OS)
- The setting resets at reboot (community; Apple does not document it). Persisting it through `/etc/sysctl.conf` or a root LaunchDaemon is possible but not recommended: every boot then runs with less headroom.
- It does not create memory; it only changes how much RAM the GPU may lock.

## Thermals and power

- Fanless MacBook Air models throttle in sustained generation. Benchmark with fixed lengths and cool-down gaps. (community)
- Benchmark on AC power and outside Low Power Mode (`pmset -g | grep lowpowermode`); results otherwise are not comparable. (OS)
- Read-only GPU power sampling: `sudo powermetrics --samplers gpu_power -i 1000 -n 5` (needs sudo). (OS)

## Practical notes

- Native arm64 Python only. Under Rosetta, MLX fails to import or install (MLX docs: "non-native Python").
- Docker Desktop on macOS has no GPU passthrough, so containers run CPU-only (OS): run MLX on the host.
- Do not benchmark with other models resident (check `lms ps` if LM Studio is running, `ps` for other servers).
- Swap use during generation: choose a smaller model/quant.

## Official links

- mlx-lm Large Models: https://github.com/ml-explore/mlx-lm#large-models
- MLX install: https://ml-explore.github.io/mlx/build/html/install.html
- mlx-lm utils (wired limit helper): https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/utils.py
