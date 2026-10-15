---
name: cpu-inference
description: Run, size and tune LLM inference on CPUs only (x86 AVX2/AVX-512/AMX, AArch64 servers with NEON and KleidiAI, Intel Macs) with llama.cpp. Use for no-GPU servers, VMs, "llama-server is slow on CPU", threads and NUMA (--numa, -t, --cpu-mask), GGML_NATIVE, illegal instruction, tokens per second from memory bandwidth, MoE on RAM-heavy hosts. Not for GPU, Apple Silicon or engine flag depth.
license: MIT
compatibility: Linux x86_64 or arm64, Windows, and Intel Macs; bash, curl and jq. Package installs, source builds, sysctl and hugepage changes, and services need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# CPU inference

Get a CPU-only host to a measured, tuned and honest baseline: the right llama.cpp build for the CPU's instruction sets, a model and quant that fit RAM and the memory-bandwidth budget, thread and NUMA settings that help, and clear expectations for tokens per second.

**Scope:** the platform (CPU hosts and VMs). Engine flags and API depth belong to `llama-cpp`; Ollama on CPU belongs to `ollama`; a MoE-focused CPU engine belongs to `ik-llama-cpp`; Apple Silicon belongs to `apple-silicon`; sizing across hardware belongs to `choosing-hardware`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
uname -sm; nproc; lscpu | grep -E 'Model name|Architecture|Thread|Core|Socket|NUMA node|L3|Flags' | cut -c1-160
lscpu | grep -o -w -E 'avx2|avx512[a-z0-9_]*|avx_vnni|amx[a-z0-9_]*|asimddp|i8mm|sve2?|bf16' | sort -u | tr '\n' ' '
free -h; numactl --hardware 2>/dev/null | head -8                 # RAM and NUMA layout
cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null       # THP mode
command -v llama-server llama-bench && llama-server --version 2>&1 | head -2
sysctl -n machdep.cpu.brand_string hw.memsize 2>/dev/null         # macOS (Intel Mac)
```

## Decision flow

1. Decide whether CPU is the right target at all: bandwidth math and expected speed first. `references/sizing.md`. If a GPU or Apple Silicon box exists, use it.
2. Pick the binary: a release archive (`ubuntu-x64`, `ubuntu-arm64`, `win-cpu-x64`, `win-cpu-arm64`, `macos-x64`) or the CPU `server` image for a first run; build from source with `-DGGML_NATIVE=ON` on the target machine for the best kernels. `references/build-and-install.md`.
3. Binary built on one machine and run on another: `GGML_NATIVE=OFF` or dynamic CPU backends; "illegal instruction" means a mismatch. `references/build-and-install.md`.
4. Tune: threads (`-t`, `-tb`), affinity, NUMA, locked memory, batch sizes. Change one knob at a time and measure with `llama-bench`. `references/tuning.md`.
5. Large MoE models on a big-RAM host: expert placement and quant choice. `references/sizing.md`.
6. Slow, killed, swapping, or wrong output: `references/troubleshooting.md`. Updates: `references/updating.md`.

## Rules

- **Ask before changing the system.** Installs, source builds, `sysctl`, hugepage settings and services need approval and an undo path.
- **Decode is memory-bandwidth-bound.** More threads past the point where bandwidth saturates does not help and can hurt; measure, do not assume.
- **Build or select for the CPU you run on.** An AVX-512 or AMX build on a CPU without it crashes with an illegal-instruction error.
- **Never size to the last GB.** Leave headroom for the OS, KV cache and page cache; swap use means the model does not fit.
- **Bind loopback.** Put a token or gateway in front before exposing `llama-server` (`llm-gateway`, `tailscale`).
- **Report honest numbers.** Quote prefill and decode tokens per second separately, with threads, quant, context and the build `system_info` line.
- **Verify upstream.** Build options and flags change between llama.cpp releases; confirm with `llama-server --help` on the installed build.

## Workflows

- [ ] Baseline: run Discover; record CPU, flags, cores, NUMA nodes, RAM -> `references/hardware-and-features.md`
- [ ] Expectation: weights size and bandwidth ceiling for the target model -> `references/sizing.md`
- [ ] Build or install the right binary -> `references/build-and-install.md`
- [ ] Measure with `llama-bench`, then tune threads and NUMA -> `references/tuning.md`
- [ ] Verify: startup `system_info` lists the expected instruction sets, `llama-bench` shows stable prefill and decode numbers, no swap use during a long generation, the server answers on loopback.

## Reference index

- `references/hardware-and-features.md`: instruction sets that matter, how to read them, x86 versus AArch64.
- `references/build-and-install.md`: binaries, Docker, source builds, KleidiAI, BLAS, portable builds.
- `references/tuning.md`: threads, affinity, NUMA, mlock, batch sizes, benchmarking.
- `references/sizing.md`: bandwidth ceiling, quant choice, KV cache, MoE on RAM.
- `references/troubleshooting.md`: symptom to fix.
- `references/updating.md`: updating builds and re-measuring.

## Companion skills

- `llama-cpp`: the engine, flags, API and server config. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `ik-llama-cpp`: fork focused on CPU and MoE performance. Install: `npx skills add ScaleDockHQ/llm-skills --skill ik-llama-cpp`.
- `ollama`: simplest CPU-capable runtime. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
- `gguf-quantization`: pick or make a quant. Install: `npx skills add ScaleDockHQ/llm-skills --skill gguf-quantization`.
- `choosing-hardware`: size models across hardware. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `apple-silicon`: Macs with unified memory. Install: `npx skills add ScaleDockHQ/llm-skills --skill apple-silicon`.
