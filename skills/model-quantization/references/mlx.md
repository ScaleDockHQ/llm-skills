# MLX quantization with mlx-lm

> Verified against ml-explore/mlx-lm v0.31.3 (mlx_lm/convert.py, mlx_lm/server.py), 2026-10-11

## How it plugs into this stack

- Use MLX when the target runs on Apple Silicon: `mlx_lm.server`, LM Studio's MLX engine, or other MLX apps. For llama.cpp or Ollama on a Mac produce GGUF instead (`gguf.md`).
- In: HF safetensors. Out: an MLX directory (`config.json` with a `quantization` block, safetensors, tokenizer), made with `mlx_lm.convert --hf-path <model> --mlx-path <dir> -q`.
- macOS has no systemd or cgroup memory cap; convert with other large apps closed and see `memory-safety.md` for what to do instead.
- Quality check with `mlx_lm.perplexity` on base and quant using identical settings (`quality-checks.md`).
- `--upload-repo` creates a public repo if missing and replaces the card body; prefer converting locally, writing the card and publishing private first (`publishing.md`).

Depth: install the mlx skill (npx skills add ScaleDockHQ/llms-skills --skill mlx)
