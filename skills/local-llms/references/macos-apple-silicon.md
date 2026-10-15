# macOS on Apple Silicon

> Verified against the `apple-silicon` skill (mlx-lm 0.32.0, mlx 0.32.3, llama.cpp b11557, Ollama v0.40.3, LM Studio 0.4.26), 2026-10-11

The platform depth (unified-memory budget, `iogpu.wired_limit_mb`, Rosetta checks, thermals, sleep and launchd, Intel Macs) moved to the `apple-silicon` skill. Install: `npx skills add ScaleDockHQ/llm-skills --skill apple-silicon`.

## What stays here

- Apple Silicon shares one memory pool between CPU and GPU; decode speed follows memory bandwidth, prefill follows GPU compute.
- Quick discovery: `uname -m`, `sysctl -n machdep.cpu.brand_string hw.memsize`, `sysctl iogpu.wired_limit_mb`, `memory_pressure | tail -2`.
- Install paths per runtime: Ollama (`install.sh` or `Ollama.dmg`, macOS 14+), LM Studio (`.dmg`, macOS 14+), llama.cpp (`brew install llama.cpp`), mlx-lm (`pip install mlx-lm` in a native arm64 venv).
- Ports on localhost: Ollama `:11434`, LM Studio `:1234`, llama-server `:9931` (this skill's convention), `mlx_lm.server` `:8080`.
- Raising `iogpu.wired_limit_mb` needs `sudo`: ask first and state the undo (`sudo sysctl iogpu.wired_limit_mb=0`). Details in the `apple-silicon` skill.
- Docker Desktop on macOS has no GPU passthrough.
