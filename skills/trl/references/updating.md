# Updating TRL

> Verified against huggingface/trl releases v1.12.0 to v1.15.0 (v1.15.0 published 2026-10-08), 2026-10-11

## Cadence

TRL ships roughly every one to two weeks: v1.12.0 (2026-08-26), v1.13.0 (2026-09-10), v1.14.0 (2026-09-25), v1.14.1 (2026-09-29), v1.14.2 (2026-10-06), v1.15.0 (2026-10-08). Read the release notes before bumping: https://github.com/huggingface/trl/releases

## v1.15.0 highlight

SFT, DPO, KTO, GRPO, RLOO and distillation score tokens with a fused LM head (Triton kernel, no `[batch, seq, vocab]` logits tensor), on by default. Upstream reports 52% to 82% lower peak memory at 8,192 tokens; the gain is largest for small models with large vocabularies. It needs Triton on a GPU (Linux with CUDA, ROCm or XPU). SFT's default `chunked_nll` loss was already memory-light and is unchanged.

## Upgrade routine

1. Record `trl env` and the config of a run that worked.
2. New venv: `uv venv && uv pip install -U trl peft` (and `"trl[vllm]"` if used; vLLM stays within 0.21.0 to 0.31.0 for v1.15.0).
3. Run a tiny smoke run (few steps, small model) with the old config.
4. Check for moved or renamed fields by reading release notes and the docs of the new version, especially for anything under `trl.experimental`.
5. Compare eval metrics before trusting the new environment for long runs.

Pin exact versions in your project. Stable trainers keep their import path; experimental ones can be renamed or removed.
