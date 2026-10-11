# exo: updating

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: GitHub releases (latest v1.0.71, assets are the macOS app), `pyproject.toml` (source version 0.3.70), `src/exo/main.py`.

- The release tags track the macOS app (`v1.0.x`); the Python package version is separate. Read both when comparing.
- The discovery namespace defaults to the version, so update **every** node, then restart. Mixed versions split into separate clusters. Pin one with `--namespace` only when you accept the risk of protocol mismatch.
- RDMA needs identical macOS versions across devices; do not update one Mac's OS alone.
- App: `brew upgrade --cask exo` or the new DMG. Source: `git pull`, rebuild the dashboard, `uv sync --extra <mlx|mlx-cpu|mlx-cuda12|mlx-cuda13>`, restart.
- Record the previous release or commit first so you can roll back: `gh api repos/exo-explore/exo/releases/latest --jq .tag_name`, `git rev-parse HEAD`.
- After updating re-run `/state`, one preview, one chat call and the benchmark.
