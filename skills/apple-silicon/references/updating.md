# Updating

> Verified against Homebrew formulae (llama.cpp 0.6.0, ollama 0.40.3), PyPI (mlx 0.32.3, mlx-lm 0.32.0), LM Studio cask 0.4.26, 2026-10-11

Record state first, change one thing at a time, and re-run the same benchmark afterwards.

```bash
sw_vers -productVersion; sysctl iogpu.wired_limit_mb
brew list --versions llama.cpp ollama 2>/dev/null
python3 -m pip list 2>/dev/null | grep -i -E '^(mlx|mlx-lm|mlx-vlm) '
lms version 2>/dev/null; ollama --version 2>/dev/null
```

- **macOS:** read the release notes, then re-check three things after the update: the runtime still reports the Apple GPU, `sysctl iogpu.wired_limit_mb` (it may be back at 0), and `rdma_ctl status` if you cluster. Updates need the user's approval and a backup point (Time Machine).
- **Homebrew runtimes:** `brew update && brew upgrade llama.cpp`; pin with `brew pin <formula>` when a version is known-good.
- **MLX:** `pip install -U mlx mlx-lm` inside the virtual environment; keep `mlx` and `mlx-lm` compatible (see the `mlx` skill).
- **Ollama and LM Studio:** update from the app or installer; models are kept.
- **Cluster nodes:** macOS versions must match exactly across nodes for RDMA discovery (`mac-cluster-exo-mlx`).
