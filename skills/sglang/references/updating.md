# SGLang: updating

> Verified against SGLang v0.5.21 (GitHub release notes v0.5.21 highlights; release dates v0.5.18 to v0.5.21; docs: get-started/install; Docker Hub tags; PyPI), 2026-10-11

Releases are frequent (v0.5.18 2026-08-22, v0.5.19 2026-09-05, v0.5.20 2026-09-18, v0.5.21 2026-10-02): roughly every two weeks. Pin an exact version and update deliberately.

## What to check before bumping

```bash
gh api repos/sgl-project/sglang/releases --jq '.[0:5][]|[.tag_name,.published_at]|@tsv'
gh release view v0.5.21 --repo sgl-project/sglang | head -80
curl -s "https://hub.docker.com/v2/repositories/lmsysorg/sglang/tags?page_size=20&name=cu130" | jq -r '.results[]|[.name,.last_updated]|@tsv'
curl -s https://pypi.org/pypi/sglang/json | jq -r .info.version
```

Read the release notes for: removed or renamed flags, changed defaults (attention backend, CUDA graph settings, mem fraction heuristics), new minimum CUDA/driver, PyTorch/FlashInfer bumps, parser name changes, and model-specific fixes for your model.

v0.5.21 highlights per the release notes: the prefix cache now runs on a Rust core by default; PD instances can switch between prefill and decode without restart; new `/v1/decisions` API; `/v1/score` scores all candidates in one request; more accurate results under PP, DP attention and CP. Watch cache behavior and PD role handling after upgrading.

Known breaking changes seen in the 0.5.19 to 0.5.21 window (from the docs):

- CUDA 12 builds retired after v0.5.19 (`-cu129`); CUDA 13 required from v0.5.20. Check the driver supports CUDA 13 before pulling.
- CUDA graph flags reorganized: `--cuda-graph-max-bs-decode` (not `--cuda-graph-max-bs`), `--cuda-graph-bs-decode`, per-phase backends; `--disable-cuda-graph` deprecated.
- `uv` older than 0.12.0 silently installs 0.5.9 without `--prerelease=allow`.
- Metric names evolved (`inter_token_latency_seconds`); rerun your dashboards and alert rules.
- Tool and reasoning parser names keep growing; `auto` can pick differently after an upgrade: pin explicit names.

## Procedure (Docker, all nodes)

1. Choose the target tag (for example `v0.5.21-cu130`). Never move production to `latest` or `dev`.
2. Record the current state: `docker image inspect <current> --format '{{index .RepoDigests 0}}'`, `curl /server_info` (version, args; do not share launch_command), and the current benchmark numbers.
3. Pre-pull on every node while serving: `docker pull lmsysorg/sglang:<tag>`. Compare image IDs across nodes.
4. Diff flags: run `docker run --rm lmsysorg/sglang:<tag> python3 -m sglang.launch_server --help > /tmp/new.help` and compare with the old image's help; fix removed flags in your wrapper, compose file, systemd unit or llama-swap entry.
5. Restart in a downtime window (all ranks together for multi-node and PD: prefill, decode and router must run compatible versions).
6. Verify: `/health` 200, `/server_info` version, chat completion, tool call, structured output, a short `bench_serving` run vs baseline, `/metrics` present.
7. Keep the old tag available for rollback: change the pinned tag back and restart. Remove old images only after a day of stable operation (`docker image prune` is destructive; ask first).

## Procedure (pip/uv)

```bash
source ~/venvs/sglang/bin/activate
uv pip freeze > ~/sglang-freeze-$(date +%F).txt     # rollback record
uv pip install --prerelease=allow "sglang==0.5.21"
sglang version
```

Prefer a fresh venv per version (`~/venvs/sglang-0.5.21`) and switch a symlink: upgrades pull new torch/flashinfer/sgl-kernel builds that are painful to unwind. Also upgrade `sglang-router` if you use it (it versions separately).

## Compiled caches

After an upgrade, first startup recompiles kernels and autotunes FlashInfer (minutes). Persist `SGLANG_CACHE_DIR` and `~/.cache/flashinfer` on a volume to avoid paying that on each container recreate; clear them if you see stale-kernel errors (`rm -rf ~/.cache/flashinfer`).

## Dev and nightly

`lmsysorg/sglang:dev*`, `nightly-*` and the nightly wheel index are for testing a fix before release. Pin by date-sha tag (`nightly-dev-cu13-YYYYMMDD-<sha>`) if you must, and file the reason in your runbook.

## Docs date discipline

When refreshing this skill, re-read the upstream docs at the new tag (the `docs/docs/` tree in the repo mirrors docs.sglang.io), then update the `> Verified against` lines.
