# Updating torchao

> Verified against torchao v0.18.0 (GitHub releases v0.16.0 to v0.18.0, PyPI, compatibility table), 2026-10-11

## Where releases come from

- PyPI `torchao` (0.18.0, released 2026-08-03) and https://github.com/pytorch/ao/releases (v0.16.0 2026-02-10, v0.17.0 2026-03-30, v0.18.0 2026-08-03). BSD-3-Clause; the repo is not archived and active as of 2026-10-11.
- 0.18.0 highlights: NVFP4 linear training prototype, minimum PyTorch 2.11, removal of the v1 tensor-subclass and layout system, `NF4Tensor` moved, `Int4WeightOnlyOpaqueTensorConfig` renamed `PrototypeInt4WeightOnlyConfig`.

## Check what you have

```bash
python3 -m pip show torchao torch transformers | grep -E '^(Name|Version):'
gh api repos/pytorch/ao/releases/latest --jq '.tag_name,.published_at'
gh issue view 2919 -R pytorch/ao --json body --jq .body | head -25     # torch pairing table
```

## Upgrade safely

1. Read release notes between your version and the target; look under "BC-Breaking / Deprecations" and "Renamed / moved APIs" (`gh api repos/pytorch/ao/releases/tags/<tag> --jq .body`).
2. Fresh venv; upgrade torch and torchao together to a paired set (`install.md`). Upgrade Transformers and vLLM to versions that support it.
3. Re-run a small model with the same config; compare output, memory, and compiled speed with the old environment.
4. Checkpoints saved by an older torchao: reload and re-save with the new version, or keep the old environment for them.
