# Updating vLLM

> Verified against vLLM v0.31.0 (docs `contributing/deprecation_policy.md`, `deployment/docker.md`, `getting_started/installation`), 2026-10-11

## Cadence and risk

- vLLM releases often; deprecations and removals happen on minor (Y in X.Y.Z) releases, with a deprecation
  period first (`contributing/deprecation_policy.md`). Patch releases are the safer upgrade.
- Always read the GitHub release notes for every minor you skip: https://github.com/vllm-project/vllm/releases
- Pin an exact version or image digest in production. Never run `latest` or `nightly` on a box that must stay up.

## Changes seen when moving to v0.31.0 (checked in source)

| Old                                               | v0.31.0                                                                        |
| ------------------------------------------------- | ------------------------------------------------------------------------------ |
| `--swap-space`                                    | Removed (no swap preemption in V1)                                             |
| `VLLM_ATTENTION_BACKEND` env var                  | `--attention-backend` flag                                                     |
| `guided_json`, `guided_regex`, ... request params | `structured_outputs` request field                                             |
| `message.reasoning_content`                       | `message.reasoning`                                                            |
| `--gpu-memory-utilization` 0.9 default            | 0.92 default; per-instance budget                                              |
| Ray as multi-node default                         | `mp` is the default executor; add `--distributed-executor-backend ray` for Ray |
| Flags with `_`                                    | Use the hyphenated form                                                        |

If a flag fails with `unrecognized arguments`, run `vllm serve --help=all` (or `--help=<group>`) on the new
version and compare against `references/serve-config.md`.

## Procedure

1. Record the current state: `vllm --version` or `docker image inspect --format '{{.Id}}' <image>` on every
   node; keep the working command and a benchmark result (`performance-tuning.md`).
2. Pull the new tag while serving: `docker pull vllm/vllm-openai:<new>` on every node. Multi-node clusters need
   identical versions and image IDs on every node; compare IDs after pulling.
3. Read the release notes and diff the flags you pass.
4. Announce downtime, stop the server, change the tag in one place (compose file, systemd unit, `models.d`
   script, K8s manifest), start it, wait for `/health`.
5. Smoke test: one chat completion, one tool call, one streamed reasoning request if you use those.
6. Rerun the benchmark and compare. Roll back by restoring the old tag (keep the old image until verified).

Python installs: `uv pip install -U vllm --torch-backend=auto` into a **fresh venv** is safer than upgrading in
place, because the PyTorch and CUDA wheels change between versions.

## Compile and cache

`~/.cache/vllm` holds `torch.compile` artifacts; a new version recompiles on first start (slow). Do not copy
caches across versions. If a start fails with strange compile errors after an upgrade, move the cache aside
and retry.

## NGC image

`nvcr.io/nvidia/vllm:<YY.MM>-py3` bundles its own vLLM, which may lag upstream; check the NVIDIA release notes
for the bundled version. See `references/install.md` for tags and known issues.
