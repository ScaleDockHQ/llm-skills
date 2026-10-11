# Updating verl

> Verified against verl-project/verl v0.9.1 (GitHub releases, docs/start/install.rst, docker/README.md), 2026-10-11

## Cadence

Actively developed (default branch pushed daily in October 2026). Releases: v0.9.1 (2026-09-20). Check before pinning:

```bash
gh api repos/verl-project/verl/releases/latest --jq '.tag_name,.published_at'
gh api repos/verl-project/verl/releases --jq '.[:5][]|.tag_name+" "+.published_at'
git -C <verl checkout> describe --tags
```

## Upgrade steps

1. Record: git tag, `uv.lock` hash or image tag, and your launch script.
2. Read the release notes between your tag and the target.
3. New checkout or new image tag; do not upgrade a machine mid-run.
4. `git checkout <tag>`; run with the same `uv run --frozen --all-packages --extra ...` prefix.
5. Re-diff your script against the matching `examples/` script; run a few-step smoke test and compare reward and `rollout_probs_diff_mean` with the old run.

## Changes visible in current docs

- Python env is uv-driven with one committed `uv.lock`; no install step (older docs used pip and conda).
- Docker images are built on vLLM and SGLang release images since v0.6.0; Docker image tags track vLLM/SGLang versions.
- vLLM older than 0.18.0 is unusable; the lock pins vllm 0.24.0, sglang 0.5.12, Megatron core_v0.18.0.
- Repo home is `verl-project/verl` (was `volcengine/verl`).
- Use `*_micro_batch_size_per_gpu` keys; plain `*_micro_batch_size` is being deprecated.
