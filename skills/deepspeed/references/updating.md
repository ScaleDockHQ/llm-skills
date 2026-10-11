# Updating DeepSpeed

> Verified against DeepSpeed v0.19.7, 2026-10-11

## Cadence

Releases every few weeks: v0.19.4 (2026-08-06), v0.19.5 (2026-08-10), v0.19.6 (2026-08-27), v0.19.7 (2026-09-16). Release notes list many small fixes per release (AutoTP, AutoEP, Ulysses, ZeRO norms, Muon, op builders): https://github.com/deepspeedai/DeepSpeed/releases

## Compatibility facts

- Trainers pin ranges: LLaMA-Factory v0.9.5 requires `deepspeed>=0.10.0,<=0.18.4`; Axolotl, TRL and Transformers have their own constraints. Check the trainer's pins before upgrading inside its environment.
- The `pin_memory` default for offload changed to `true`; revisit memlock limits after upgrading.
- Ops are JIT-compiled per environment; after upgrading torch or CUDA clear or relocate `~/.cache/torch_extensions` (or set `TORCH_EXTENSIONS_DIR`).
- Checkpoints from different DeepSpeed versions are generally resumable, but test resume on a small run first (inferred); use Universal Checkpointing for changed parallelism.

## Upgrade routine

1. Record `ds_report` output and the config of a run that worked.
2. New venv: PyTorch, then `uv pip install -U deepspeed` (or the trainer's pinned range).
3. Run `ds_report`; compare ops and versions.
4. Smoke-run a small model for a few steps with the old config, including a checkpoint save, a resume and a `zero_to_fp32.py` conversion.
5. Read release notes for config keys you use (`zero_optimization`, offload, bf16 options).
6. Compare loss curves before trusting long runs.

Pin exact versions in your project.
