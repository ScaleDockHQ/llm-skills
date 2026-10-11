# Updating HQQ

> Verified against hqq v0.2.8.post1 (PyPI, GitHub releases v0.2.7.post1 to v0.2.8.post1, commit history), 2026-10-11

## Where releases come from

- PyPI `hqq` and https://github.com/dropbox/hqq/releases: `0.2.7.post1` 2025-06-12, `v0.2.8` 2025-08-18, `v0.2.8.post1` 2025-10-20. Upstream recommends installing from git for the latest changes; the most recent `master` commit read was 2026-02-26.
- Project status checked 2026-10-11: not archived, Apache-2.0, low release cadence.

## Check what you have

```bash
python3 -m pip show hqq transformers torch | grep -E '^(Name|Version):'
gh api repos/dropbox/hqq/releases/latest --jq '.tag_name,.published_at'
gh api repos/dropbox/hqq/commits --jq '.[0].commit.author.date'
```

## Upgrade safely

1. Read the release notes and recent commits touching the solver, backends and `hqq.utils`.
2. Fresh venv: `pip install -U hqq` (or the git URL), same PyTorch build.
3. Re-quantize a small model with the same config; compare output, VRAM and tokens per second with the old environment. Quantized outputs can change when the solver changes.
4. Reload any saved checkpoint with the new version before deleting the old environment.
