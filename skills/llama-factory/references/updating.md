# Updating LLaMA-Factory

> Verified against LLaMA-Factory v0.9.5, 2026-10-11

## Cadence

Releases are infrequent (latest v0.9.5, 2026-05-30; `main` is `0.9.6.dev0` with commits on 2026-10-10). `main` moves faster than releases: pin ranges in `pyproject.toml` already differ between v0.9.5 and `main` (for example `transformers` upper bound 5.6.0 vs 5.8.0). Releases: https://github.com/hiyouga/LLaMA-Factory/releases

## Upgrade routine

1. Record `llamafactory-cli env` and keep the YAML of a run that worked.
2. In a new directory: `git clone --depth 1 https://github.com/hiyouga/LlamaFactory.git` (or `git checkout v0.9.5`), new `uv` venv, `uv pip install -e .`.
3. Diff `pyproject.toml` pins and `requirements/*.txt` against the old checkout.
4. Re-run `examples/train_lora/qwen3_lora_sft.yaml` as a smoke test, then your own YAML for a few steps.
5. Check that renamed or removed YAML keys still load: unknown keys are expected to fail at parse time (inferred), so read the error and the new `examples/`.
6. Compare eval metrics before trusting the new environment for long runs.

Docker: pull a specific tag, never rely on a moving `latest` for a long project.

## Version caveats seen on 2026-10-11

- PEFT latest is 0.21.2 but LLaMA-Factory pins `peft<=0.18.1`; DeepSpeed latest is 0.19.7 against `deepspeed<=0.18.4`. Follow the pins until upstream raises them.
- The README's requirements table is older than `pyproject.toml`; trust `pyproject.toml`.
