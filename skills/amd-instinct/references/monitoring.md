# Monitoring

> Verified against AMD SMI 27.1.0 CLI docs and ROCm 10.1.0 release notes (breaking changes), 2026-10-11

`amd-smi` replaces `rocm-smi`. The standard ROCm 10.1 build no longer builds or installs `rocm-smi-lib`.

## Commands

```bash
amd-smi version
amd-smi list                    # GPU, BDF, UUID, KFD_ID, NODE_ID, partition ID
amd-smi static --gpu 0          # ASIC, board, VRAM, driver
amd-smi metric                  # power, clocks, temperature, memory, usage
amd-smi monitor -putm           # live table (power, utilization, temperature, memory)
amd-smi process --gpu 0 1       # compute processes per GPU
amd-smi firmware                # firmware versions
amd-smi bad-pages               # retired pages
amd-smi topology                # links between GPUs
amd-smi --rocm-smi              # legacy rocm-smi-style output for old scripts
amd-smi metric --json           # machine-readable (also --csv)
```

- `--gpu` takes an index, a BDF or a UUID. `--json`, `--csv` and `--file` are available on most subcommands.
- Metrics are cached; `AMDSMI_GPU_METRICS_CACHE_MS` (default 100) controls the cache, 0 disables it.
- CPU subcommands (`--cpu-*`, `static --smu`) need the `amd_hsmp` kernel module with HSMP enabled in BIOS; without it, CPU discovery is skipped without failing GPU commands.
- `amd-smi event` is not supported on WSL and can hang there.

## What to watch

- VRAM used against engine KV cache size, to catch fragmentation and leaked processes (`amd-smi process`).
- Temperature, power and clock throttling under sustained load (`amd-smi metric`).
- `amdgpu` errors in `dmesg`, retired pages (`bad-pages`), and RAS entries (`amd-smi ras`).
- Utilisation per GPU in a tensor-parallel group: one idle GPU means a stuck rank or a topology mix-up.

## Prometheus and Grafana

Use the `llm-observability` skill for the stack. Engines (vLLM, SGLang) expose `/metrics` themselves. For GPU metrics, run an exporter built on AMD SMI (for example AMD's device-metrics-exporter); this skill has not verified a specific exporter version, so check its release page before pinning.
