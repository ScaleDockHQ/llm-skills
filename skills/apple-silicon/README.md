# Apple Silicon

Size, tune and operate an Apple Silicon Mac (MacBook, Mac mini, Mac Studio) for local LLM inference: native arm64 runtimes, a unified-memory budget, the GPU wired-memory limit, thermals and sleep, running it as an always-on server, and when to cluster several Macs.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill apple-silicon
```

## Rules

- **Native arm64 only.** Rosetta binaries cannot use Metal or MLX.
- **Ask before `sudo sysctl iogpu.wired_limit_mb`,** and name the value and the undo.
- **Shrink the model first.** Do not raise the wired limit to make a model fit.
- **Loopback by default.** Share through Tailscale or a gateway, not `0.0.0.0`.

## References

- [`references/hardware-and-os.md`](references/hardware-and-os.md): chips, OS requirements, Rosetta, Intel Macs.
- [`references/memory.md`](references/memory.md): budget formula, wired limit, KV levers.
- [`references/runtimes-on-mac.md`](references/runtimes-on-mac.md): Ollama, LM Studio, llama.cpp, MLX.
- [`references/power-and-thermals.md`](references/power-and-thermals.md): throttling, benchmarking, `powermetrics`.
- [`references/operating.md`](references/operating.md): sleep, launchd, exposure, disk.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/updating.md`](references/updating.md): macOS and runtime updates.

## Companion skills

- `mlx`, `lm-studio`, `ollama`, `llama-cpp`: runtimes.
- `local-llms`, `choosing-hardware`: choosing and sizing.
- `mac-cluster-exo-mlx`, `tailscale`: clustering and remote access.

## License

MIT
