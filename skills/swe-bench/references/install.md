# Install SWE-bench

> Verified against swebench 5.0.2 (PyPI wheel contents) and upstream docs on main, 2026-10-11

## Requirements

- Python >=3.10 (the 5.0.2 wheel declares `Requires-Python: >=3.10`; some upstream docs still say 3.9+, trust the wheel).
- Docker, running, with your user allowed to use it. Evaluation cannot run without Docker (or Modal).
- Upstream recommends x86_64, about 120GB free disk, 16GB RAM and 8 cores. arm64 is experimental; on Apple Silicon or other ARM hosts build images locally with `--task-repo` (Docker Buildx).
- Docker Desktop on macOS: give it 8 CPUs, 16GB RAM and a 120GB disk image in Resources.

## Maintenance status

MIT licensed, not archived, last upstream push 2026-09-18. v5.0.0 to v5.0.2 appeared on PyPI 2026-08-17/18; git tags stop at v5.0.1 and there is no `v5.0.2` tag, so source docs on `main` do not map one-to-one to a release.

## Install pinned from PyPI

```bash
python3 -m venv ~/.venvs/swebench && . ~/.venvs/swebench/bin/activate
pip install "swebench==5.0.2"
swebench --help
```

The 5.0.2 wheel registers these commands (read from its `swebench.cli` package): `eval`, `report`, `images` (`build`, `check`, `clean`, `push`) and `dataset` (`build`, `check`, `diff`, `push`, `collect`). The dataset aliases in the wheel are `full`, `verified`, `multilingual` and `multimodal`.

## PyPI versus main

Upstream docs on `main` also describe `swebench infer` (mini-SWE-agent wrapper), `swebench submit ...` (leaderboard and HuggingFace upload), a `lite` alias and run metadata in `run.json`. None of these are in the 5.0.2 wheel. To use them, install from a clone and say so in your notes:

```bash
git clone https://github.com/SWE-bench/SWE-bench.git && cd SWE-bench
git rev-parse HEAD            # record the commit
pip install -e .
swebench --help               # confirm the subcommands you need exist
```

On PyPI 5.0.2 use the HuggingFace id for Lite: `SWE-bench/SWE-bench_Lite`.

## Task repo (needed for local image builds)

```bash
git clone --depth 1 https://github.com/SWE-bench/swe-bench-tasks.git ./swe-bench-tasks
```

Pass `--task-repo ./swe-bench-tasks` to `swebench eval` to build images from the task repo instead of pulling published ones. Without it, images are pulled from a registry, so a stale published image can mask a broken build.

## Extras

`pip install "swebench[submit]"` is mentioned upstream for `swebench submit hf` (main only). The wheel lists `datasets`, `inference`, `test` and `docs` extras; the `inference` extra pulls torch and flash-attn, which you rarely want.

## Docker checks (read-only)

```bash
docker --version && docker info --format '{{.NCPU}} cpus, {{.MemTotal}} bytes'
docker system df
```
