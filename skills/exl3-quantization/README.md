# EXL3 quantization

Agent skill for producing EXL3 quants with ExLlamaV3's `convert.py`: choose a fractional bitrate, set head, embedding, vision and MTP bits, convert and resume (multi-GPU too), optionally run the experimental optimized-recipe pipeline (`sc_trace`, `sc_measure`, `sc_optimize`) with in-domain calibration, evaluate with perplexity and KL divergence, and publish a bitrate ladder as Hub branches.

Verified against ExLlamaV3 v1.6.1 on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill exl3-quantization
```

## Rules

- **Ask before changing the system.** Long GPU jobs, installs and uploads need approval.
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a `0600` file.
- **Resuming is explicit** (`-r`); `-o` is overwritten if it exists; the work dir holds a full output copy.
- **Pin the ExLlamaV3 version** and record command, bitrate and calibration data in the model card.

## References

- [`references/convert.md`](references/convert.md): every `convert.py` argument, resume, multi-GPU.
- [`references/bitrates-and-calibration.md`](references/bitrates-and-calibration.md): sizing, ladders, special-tensor bits, calibration.
- [`references/optimized-recipes.md`](references/optimized-recipes.md): the experimental recipe pipeline.
- [`references/evaluation.md`](references/evaluation.md): perplexity, KLD, qbench, smoke test.
- [`references/post-processing.md`](references/post-processing.md): `util/` tools.
- [`references/publishing.md`](references/publishing.md): per-bitrate branches and model card.
- [`references/updating.md`](references/updating.md): updates and requantizing.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/convert-then-serve-tabbyapi.md`](references/combos/convert-then-serve-tabbyapi.md): convert, check, serve.
- [`scripts/convert-ladder.sh`](scripts/convert-ladder.sh): convert several bitrates in sequence.

## Companion skills

- `exllamav3`: install and serve with TabbyAPI.
- `model-quantization`: choose a format and method.
- `choosing-hardware`: size VRAM.
- `gguf-quantization`: the llama.cpp equivalent.

## License

MIT
