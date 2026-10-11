# Updating TensorRT-LLM

> Verified against TensorRT-LLM v1.2.1 (released 2026-04-20) and v1.3.0rc29 release notes, NGC `release` tag list, PyPI, `main` (1.4.0rc0), Dynamo v1.5.1 `container/context.yaml`, 2026-10-11

## Where versions come from

| Source                      | What it tells you                                                                                                                               | Command                                                                                                      |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| GitHub releases             | Stable tags and rc tags (the latest non-pre release was `v1.2.1`, 2026-04-20; `v1.3.0rc29`, 2026-09-29, is the newest rc)                       | `gh api repos/NVIDIA/TensorRT-LLM/releases --jq '.[0:6][] \| [.tag_name,.prerelease,.published_at] \| @tsv'` |
| NGC `release` tags          | What you can actually pull; rc tags weekly, plain tags for QA-tested monthly releases (upstream docs)                                           | See the tag-list snippet in `install.md`                                                                     |
| PyPI                        | `tensorrt_llm` latest non-pre is 1.2.1; rc wheels need `--pre`                                                                                  | `curl -s https://pypi.org/pypi/tensorrt-llm/json \| jq -r .info.version`                                     |
| Release notes in the repo   | `docs/source/release-notes.md`                                                                                                                  | read before every bump                                                                                       |
| NVIDIA's DGX Spark playbook | Image pin and YAML keys NVIDIA tests on GB10 (single node rc13, two node rc5 at writing)                                                        | diff the playbook README against your YAML                                                                   |
| Dynamo                      | Dynamo 1.5.1 pins TensorRT-LLM 1.3.0rc25 in `container/context.yaml`; its runtime image is `nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1` | see `combos/dynamo.md`                                                                                       |

Policy for this skill: pin stable `1.2.1` by default; pin an exact rc only for a model or feature that needs it, and record why. Never use `latest` or an unpinned rc.

## What changed across lines (read these before a bump)

- v1.2.1 (patch): fixed a KV cache corruption issue (#12770) and upgraded xgrammar and flashinfer. Prefer it over 1.2.0.
- 1.3.0rc29 notes list breaking changes: the AutoDeploy integration and its entry points were removed (so `--backend _autodeploy` is gone), an obsolete `cpp_only` CMake option was removed, public PyTorch moves to 2.14, Triton to 3.8, C++ to 20. The Responses API now treats explicit null optional fields as unset, media data URIs are validated and private URL fetches require opt-in (security hardening for multimodal).
- `main` (1.4.0rc0): `--backend` is deprecated and only `pytorch` is accepted (the legacy TensorRT engine flow is not available there), `--set` overrides and `--served_model_name` exist, parsers were expanded (`gemma4`, `glm4`, `minimax_m2`, ...), install prerequisites moved to CUDA 13.4 and torch 2.14 for pip.
- Flags tagged beta or prototype (including `--config` itself in the 1.2.1 `serve` help) are the most likely to change.

## Safe upgrade procedure

1. Record the current state: `docker images | grep tensorrt-llm`, `curl -s :8000/version`, the YAML in version control, and a benchmark baseline (`performance-tuning.md`).
2. Read the release notes between your tag and the target for breaking items and for your model.
3. Check disk: images are large (not measured here; check `docker system df`). Pull on **every** node, with the tag pinned: `docker pull nvcr.io/nvidia/tensorrt-llm/release:<new>`; compare image IDs per node (`docker image inspect --format '{{.Id}}'`).
4. Dry-run the new image off to the side on another port or GPU if memory allows: `docker run --rm ... trtllm-serve --help | head` to diff flags, then start with the existing YAML and read startup warnings about unknown or renamed keys (invalid or renamed keys may be rejected or ignored depending on the tag; not verified).
5. Re-read the model's deployment guide or playbook YAML for changed keys (`kv_cache_config`, `cuda_graph_config`, `moe_config`, parser names).
6. Restart in a maintenance window. Multi-node: stop all containers, start all on the new tag, never mix tags across ranks.
7. Verify: `/health`, `/version`, one request per modality and tool-calling path, then re-benchmark and compare with the baseline.
8. Rollback: keep the previous image and YAML; restart with the old tag. Do not delete old images until the new one has served real traffic.

For pip installs: use a fresh venv per version, constrain torch (`install.md`), and uninstall old CUTLASS DSL packages when the guide says so.

## Updating checkpoints, not just the engine

NVFP4 and FP8 checkpoints from NVIDIA are re-published as ModelOpt improves; pin `--revision` (commit) for reproducibility. A newer image may require re-quantized weights for new kernels (check model card notes), and Model Optimizer's README requires TensorRT-LLM 1.2 or later for NVFP4 inference.

## Official links

- Releases: https://github.com/NVIDIA/TensorRT-LLM/releases
- Release notes: https://nvidia.github.io/TensorRT-LLM/release-notes.html
- NGC tags: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/tensorrt-llm/containers/release/tags
