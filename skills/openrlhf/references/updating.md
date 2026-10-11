# Updating OpenRLHF

> Verified against OpenRLHF/OpenRLHF v0.11.2 (GitHub releases, README.md news, setup.py), 2026-10-11

## Cadence

Actively maintained. Recent releases: v0.11.2 (2026-09-14), v0.11.1 (2026-09-10), v0.11.0 (2026-08-13), v0.10.4 (2026-06-08). Check before pinning:

```bash
gh api repos/OpenRLHF/OpenRLHF/releases/latest --jq '.tag_name,.published_at'
curl -s https://pypi.org/pypi/openrlhf/json | jq -r '.info.version'
pip show openrlhf 2>/dev/null | head -3
```

## Upgrade steps

1. Record `pip freeze | grep -Ei 'openrlhf|vllm|deepspeed|ray|torch|transformers'`, your launch scripts and the container tag.
2. Read release notes from your version to the target.
3. Use a fresh container or venv; keep the old one until one train-and-merge cycle passes.
4. `pip install -U 'openrlhf[vllm]==<version>'` (the extra pins vLLM; `vllm_latest` floats).
5. Diff your flags against the matching `examples/scripts/*.sh`, then run a few-step smoke test.

## Changes visible in current upstream

- Dotted flag groups (`--actor.*`, `--ds.*`, `--vllm.*`, `--rollout.*`, `--train.*`, `--ckpt.*`, `--algo.*`, `--logger.*`, `--data.*`, `--eval.*`); SFT/RM/DPO use `--model.*`.
- Agent-based execution for all RL (single-turn default, multi-turn via `--train.agent_func_path`); async (0.8.0), VLM RL (0.10), FlashREINFORCE (2026/9).
- A Molt backend (NVIDIA-NeMo labs, Automodel-based) is advertised as an alternative to DeepSpeed for very large models; not covered here.
