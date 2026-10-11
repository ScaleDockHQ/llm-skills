# Updating PEFT

> Verified against PEFT v0.21.2, 2026-10-11

## Cadence

PEFT releases every few weeks: v0.21.2 on 2026-10-01 (latest on 2026-10-11). Releases: https://github.com/huggingface/peft/releases

## Compatibility facts

- An adapter saved by a newer PEFT can fail to load in an older one with `unexpected keyword argument`; upgrade rather than editing the config (`troubleshooting.md`).
- Trainers pin PEFT ranges. LLaMA-Factory v0.9.5 pins `peft<=0.18.1`; Check the trainer's `pyproject.toml` before upgrading inside its environment.
- Config fields change: newer PEFT adds LoRA variants and initializations. Read the `LoraConfig` docstring for your version.

## Upgrade routine

1. Record `pip list | grep -iE 'peft|transformers|accelerate|trl|bitsandbytes'` and keep one adapter that worked.
2. New venv: `uv venv && uv pip install -U peft` (plus the versions your trainer allows).
3. Reload the old adapter with `PeftModel.from_pretrained` and generate on fixed prompts; compare with the old environment.
4. Run a tiny training smoke test (few steps, small model).
5. Re-check merge and save paths if you use them.

Pin exact versions in your project and store `peft.__version__` next to each adapter.
