# Update and pin MLX packages

> Verified against mlx 0.32.3, mlx-lm 0.32.0 (PyPI), mlx-vlm 0.7.6, GitHub release lists, 2026-10-11

## Where releases come from

- PyPI is the source of truth: `mlx-lm` 0.32.0 (uploaded 2026-10-01), `mlx` 0.32.3, `mlx-vlm` 0.7.6.
- GitHub: `ml-explore/mlx-lm` has tag `v0.32.0`, while its latest _GitHub release_ object is `v0.31.3`. Check tags, not just "Releases". `mlx-vlm` releases v0.7.6 (2026-10-05); `ml-explore/mlx` releases v0.32.3 (2026-09-29).
- `main` moves daily. Docs on `main` (README, SERVER.md) can describe flags newer than your pip version: compare with `--help`.

## Check

```bash
pip list 2>/dev/null | grep -Ei '^(mlx|mlx-lm|mlx-vlm|transformers) '
pip index versions mlx-lm 2>/dev/null | head -1
python -m mlx_lm --version
```

## Upgrade

```bash
. ~/.venvs/mlx/bin/activate
pip install -U mlx-lm              # and mlx-vlm if used
python -m mlx_lm --version
mlx_lm.generate --model mlx-community/Llama-3.2-3B-Instruct-4bit --prompt "ping" --max-tokens 8
```

A new architecture failing to load is most often fixed by upgrading mlx-lm (and `transformers`). mlx-lm requires `transformers>=5.7.0` and mlx-vlm `>=5.14.0` at these versions, so keep them in one venv only if the ranges agree; otherwise use two venvs.

Restart any running server (`launchctl kickstart -k gui/$(id -u)/com.example.mlx-lm-server` if you used the plist, or stop and restart manually). Loaded models do not hot-reload.

## Pin

```bash
pip freeze | grep -Ei '^(mlx|mlx-lm|mlx-vlm|transformers)==' > ~/.venvs/mlx/requirements-pin.txt
pip install -r ~/.venvs/mlx/requirements-pin.txt        # reproduce later
```

Roll back: `pip install 'mlx-lm==0.31.3'` (the last GitHub-released version before 0.32.0) after a regression, then restart.

## Models and caches

MLX models are Hugging Face repos: updating a model means re-downloading a newer revision. List and prune the cache with `hf cache ls`, `hf cache rm <repo>`, `hf cache prune`, or `mlx_lm.manage --scan` / `--delete --pattern <glob>` (mlx-lm). Ask before deleting.

## Official links

- https://github.com/ml-explore/mlx-lm/tags
- https://pypi.org/project/mlx-lm/#history
- https://github.com/Blaizzy/mlx-vlm/releases
- https://github.com/ml-explore/mlx/releases
