# Updating and rolling back

> Verified against TabbyAPI main (docs/01.-Getting-Started.md, pyproject.toml) and ExLlamaV3 v1.6.1 (releases, README), 2026-10-11

TabbyAPI is a rolling release without tagged releases, ExLlamaV3 is tagged (v1.6.1 on 2026-10-10; v1.6.0 2026-10-07, v1.5.4 2026-10-03: frequent). TabbyAPI enforces the latest exllamav3 version it was tested with (set by `unsafe_launch: false`, the default), so update them together.

## Before updating

1. Note what runs: image digest (`docker inspect --format '{{index .RepoDigests 0}}' <container>`) or `git -C tabbyAPI rev-parse HEAD` and `pip list | grep -i -E 'exllamav3|torch'`.
2. Read the exllamav3 release notes (`gh release view <tag> -R turboderp-org/exllamav3`) and the diff of `config_sample.yml` for renamed or removed keys (`git diff <old> <new> -- config_sample.yml`).
3. Keep the old image digest or venv. Have a fixed prompt set to compare outputs and speed.

## Docker

```bash
docker pull ghcr.io/theroyallab/tabbyapi:latest     # or :cu13
docker image ls --digests ghcr.io/theroyallab/tabbyapi
# restart with the same run/compose command, then smoke test /health and a chat completion
```

Pin by digest in compose (`image: ghcr.io/theroyallab/tabbyapi@sha256:...`) so a pull never changes you silently. Rollback: run the previous digest. Custom exllamav3 (dev branch, source build) means building the image yourself.

## Start script and scripts

In `update_scripts/`: `update_deps` (dependencies only) and `update_deps_and_pull` (dependencies plus `git pull`). They exit after running; then start with `start.sh`. `start.sh --nowheel` or plain `pip install .` skips wheel (torch, exllamav3) updates.

## Manual

```bash
cd tabbyAPI && git pull
pip install -U .[cu12]     # .[cu13] for CUDA 13, .[rocm] ... for AMD (see install.md)
```

Any `pip install -U .[<gpu-lib>]` overwrites a custom exllamav3 wheel. If you installed a custom wheel, update with `pip install .` and then reinstall your wheel.

## ExLlamaV3 alone

Pick the wheel for your CUDA, torch and Python from the releases page (for example `cu128`/`cp312`), or build from source (`install.md`). After a torch upgrade the extension recompiles at first import (minutes); clear a stale cache if import fails (`troubleshooting.md`).

## After updating

- Clear `~/.cache/torch_extensions/**/exllamav3_ext` if you see import errors after a torch or CUDA change.
- Reload models; re-converted or newly supported architectures may need a newer exllamav3 than your quant was made with (EXL3 quants stay loadable across versions in general, but upstream does not promise this; test).
- Run the quality gate and compare speed. If worse, roll back and report upstream with logs.

## Fork (MiaAI-Lab)

`git fetch`, read `git log HEAD..origin/main`, stop serving, pull, let `start.sh` rebuild. It tracks upstream selectively; do not assume it contains the newest upstream release.
