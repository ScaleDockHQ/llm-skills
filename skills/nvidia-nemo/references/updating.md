# Updating and migrating NeMo

> Verified against NVIDIA-NeMo/Automodel v0.6.0, Megatron-Bridge v0.6.2, RL v0.7.0, Run v0.11.1, 2026-10-11

Three repos release independently; versions do not line up. Record the exact tag or container of each in your run notes.

## Check versions

```bash
for r in Automodel RL Megatron-Bridge Run; do gh api repos/NVIDIA-NeMo/$r/releases/latest --jq '"'$r' "+.tag_name+" "+.published_at'; done
python3 -c 'import importlib.metadata as m; print(m.version("nemo-automodel"))'
git -C nemo-rl describe --tags
```

## Upgrade

- **Automodel (PyPI):** `uv pip install -U nemo-automodel`; clone: `git pull && uv sync --frozen`. Read `docs/breaking-changes` first. Known: 0.4.0 CLI/recipe section, 0.5.0 FSDP2 float32 `reduce_dtype` and root sharding of frozen multimodal modules.
- **NeMo RL:** `git pull && git submodule update --init --recursive`, then run once with `NRL_FORCE_REBUILD_VENVS=true`. Config keys change between releases: diff `examples/configs/*.yaml` against yours.
- **Megatron-Bridge:** re-sync the submodule (`uv sync --locked`). Deprecated model families are removed in 0.7.0: convert them with an older release first.
- **Containers:** pick a new tag from the NGC catalog, pull, and rerun your smoke config before long jobs.

## Migrating from NeMo 2.x or Aligner

NeMo 2.x LLM recipes map to Megatron-Bridge (`docs/nemo2-migration-guide.md`) or Automodel. NeMo Aligner is superseded by NeMo RL. The legacy `NVIDIA/NeMo` repo now redirects to `NVIDIA-NeMo/Speech`.
