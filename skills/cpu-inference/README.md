# CPU inference

Run, size and tune LLM inference on CPU-only hosts (x86 AVX2, AVX-512 and AMX, AArch64 servers with NEON and KleidiAI, Intel Macs) with llama.cpp: the right build for the CPU, a bandwidth-based speed ceiling, thread and NUMA tuning, quant and MoE sizing, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill cpu-inference
```

## Rules

- **Decode is memory-bandwidth-bound.** Measure threads; more is not always faster.
- **Build for the CPU you run on.** SIGILL means a build and CPU mismatch.
- **Leave headroom.** Swap use means the model does not fit.
- **Loopback by default.** Add a token or gateway before sharing.

## References

- [`references/hardware-and-features.md`](references/hardware-and-features.md): instruction sets and how to read them.
- [`references/build-and-install.md`](references/build-and-install.md): binaries, Docker, source builds, KleidiAI, BLAS.
- [`references/tuning.md`](references/tuning.md): threads, NUMA, mlock, batch sizes, `llama-bench`.
- [`references/sizing.md`](references/sizing.md): bandwidth ceiling, quants, MoE on RAM.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/updating.md`](references/updating.md): updates and re-measuring.

## Companion skills

- `llama-cpp`, `ik-llama-cpp`, `ollama`: engines.
- `gguf-quantization`, `choosing-hardware`: quants and sizing.
- `apple-silicon`: Macs.

## License

MIT
