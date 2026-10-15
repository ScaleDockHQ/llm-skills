# Apple Silicon: hardware and OS requirements

> Verified against MLX docs (install), Ollama docs (macOS), LM Studio docs (system requirements), llama.cpp release b11557 and docs/build.md, 2026-10-11

## What matters for LLM inference

- **One memory pool.** CPU and GPU share unified memory, so a Mac with a lot of RAM loads models that need a large discrete GPU on a PC. The usable share is not all of it (`memory.md`).
- **Decode is bandwidth-bound,** so Pro, Max and Ultra chips (more memory bandwidth) decode faster than base chips at the same model size. Prefill depends on GPU compute and is the usual weak spot against NVIDIA. Read the exact bandwidth and GPU core count for the chip from Apple's tech specs page for that model; do not infer it from the chip name.
- **MoE models fit the platform:** only active experts are read per token, so a large MoE in a big pool decodes faster than a dense model of the same size.

## Read the machine

```bash
sysctl -n machdep.cpu.brand_string hw.memsize
system_profiler SPHardwareDataType SPDisplaysDataType | grep -E 'Model Name|Chip|Total Number of Cores|Memory|Metal'
sw_vers -productVersion
```

## OS requirements per runtime

| Runtime            | Requirement (upstream docs)                                                             |
| ------------------ | --------------------------------------------------------------------------------------- |
| MLX (PyPI)         | Apple silicon, native Python 3.10+, macOS 14.0+                                         |
| mlx-lm             | Python 3.11+ (PyPI metadata); automatic wiring of model memory needs macOS 15+          |
| LM Studio          | Apple Silicon (M1 to M4 listed), macOS 14.0+, 16 GB+ RAM recommended                    |
| Ollama             | macOS 14 (Sonoma) or newer; Apple M series (CPU and GPU) or x86 (CPU only)              |
| llama.cpp          | Metal build is on by default for arm64; prebuilt `macos-arm64` and `macos-x64` archives |
| Thunderbolt 5 RDMA | macOS 26.2+, a Thunderbolt 5 Mac (see `mac-cluster-exo-mlx`)                            |

## Intel Macs

CPU only. Ollama runs on CPU, LM Studio and MLX do not support them, llama.cpp ships a `macos-x64` build. Treat an Intel Mac as a `cpu-inference` target (install: `npx skills add ScaleDockHQ/llm-skills --skill cpu-inference`).

## Rosetta

An x86_64 binary or Python under Rosetta cannot use Metal or MLX and shows up as "100% CPU".

```bash
sysctl -n sysctl.proc_translated          # 1 = this shell runs under Rosetta
file "$(command -v llama-server)"         # must say arm64
python3 -c 'import platform; print(platform.machine())'   # must print arm64
```

Fix: reinstall the arm64 build (Homebrew under `/opt/homebrew`, not `/usr/local`), recreate the virtual environment with a native Python.

## Official links

- https://ml-explore.github.io/mlx/build/html/install.html
- https://docs.ollama.com/macos
- https://lmstudio.ai/docs/app/system-requirements
- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
