# MLX

Run, serve, convert, quantize and fine-tune models on Apple Silicon with Apple's MLX stack: `mlx-lm` (text LLMs, `mlx_lm.server`, convert, LoRA, fuse) and `mlx-vlm` (vision, audio and omni models, `mlx_vlm.server`). Includes memory sizing and the GPU wired-memory limit for large models on a Mac.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill mlx
```

## Rules

- **Ask before changing the system.** `pip install`, `sudo sysctl iogpu.wired_limit_mb=N`, big downloads, Hub uploads and non-loopback binds need approval and an undo path.
- **The servers are not hardened.** `mlx_lm.server` has no auth and loads whatever `model` a request names; `mlx_vlm.server` binds `0.0.0.0` by default. Keep both on `127.0.0.1`.
- **Never print secrets.** Hugging Face tokens stay in `hf auth login` or `HF_TOKEN`.
- **`mlx_lm.server --max-tokens` defaults to 512.** Raise it for agents.
- **Leave RAM for macOS** when raising the wired limit.

## References

- [`references/install.md`](references/install.md): venv, packages, versions, native Python.
- [`references/serving.md`](references/serving.md): `mlx_lm.server` flags, endpoints, caching, launchd.
- [`references/vision.md`](references/vision.md): `mlx-vlm` generate, server, convert.
- [`references/convert-quantize.md`](references/convert-quantize.md): `mlx_lm.convert`, modes, recipes, publishing.
- [`references/fine-tuning.md`](references/fine-tuning.md): `mlx_lm.lora`, data, memory, fuse.
- [`references/apple-silicon.md`](references/apple-silicon.md): sizing, wired limit, thermals.
- [`references/updating.md`](references/updating.md) and [`references/troubleshooting.md`](references/troubleshooting.md).
- [`references/combos/lora-to-gguf.md`](references/combos/lora-to-gguf.md), [`references/combos/llama-swap.md`](references/combos/llama-swap.md): pairings with their caveats.
- [`assets/mlx-lm-server.launchd.plist`](assets/mlx-lm-server.launchd.plist): LaunchAgent for `mlx_lm.server`.

## Companion skills

- `lm-studio`: GUI and daemon that also runs MLX models.
- `local-llms`: compare local runtimes.
- `model-quantization`: quant formats across engines.
- `fine-tuning-llms`: training strategy and adapter serving.
- `llama-swap`: model swapping proxy.
- `hugging-face`: hub auth and caches.

## License

MIT
