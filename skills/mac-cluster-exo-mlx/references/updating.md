# Updating a Mac cluster

> Verified against exo v1.0.71 (Homebrew cask 1.0.71), mlx 0.32.3 and mlx-lm 0.32.0 on PyPI, 2026-10-11

Update one thing at a time on all nodes together and keep a baseline to compare against.

- **macOS:** RDMA discovery needs identical OS versions on every node. Update all nodes to the same release, then re-run `rdma_ctl status` and `ibv_devices` (the RDMA state can need re-checking after an update). Updates need the user's approval.
- **exo app:** `brew upgrade --cask exo` or download the latest build on every node; restart together. From source: `git pull`, rebuild the dashboard, `uv sync --extra mlx`, restart.
- **MLX path:** keep `mlx` and `mlx-lm` at the same versions on every node (`python3 -m pip list | grep -i '^mlx'` on each).
- **After any change:** run the same fixed prompt and compare tokens per second with the saved baseline; check `memory_pressure` per node.
- **Rollback:** keep the previous exo app or the previous pinned `pip install mlx==<v> mlx-lm==<v>` available until the new version matches the baseline.
