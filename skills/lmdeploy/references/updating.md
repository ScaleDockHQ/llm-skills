# Updating

> Verified against LMDeploy v0.18.0 (GitHub releases v0.15.0-v0.18.0, PyPI, Docker Hub), 2026-10-11

Releases come roughly monthly: v0.15.0 (2026-07-31), v0.16.0 (08-19), v0.17.0 (09-01), v0.18.0 (09-28). Read the notes
before every bump: <https://github.com/InternLM/lmdeploy/releases>.

## Procedure

- [ ] Record the current version (`lmdeploy --version` or image ID) and a benchmark baseline.
- [ ] Read the release notes between the two versions; look for flag, parser, API and kernel changes.
- [ ] Install the new version in a new venv or pull the new image tag on every node; do not upgrade in place on a
      serving host.

```bash
python3 -m venv ~/venvs/lmdeploy-new && ~/venvs/lmdeploy-new/bin/pip install lmdeploy==X.Y.Z
docker pull openmmlab/lmdeploy:vX.Y.Z-cu12.8 && docker image inspect --format '{{.Id}}' openmmlab/lmdeploy:vX.Y.Z-cu12.8
```

- [ ] Start on a spare port; run `/health`, `/v1/models`, a chat, a tool call, a stream, a structured-output call.
- [ ] Re-benchmark; compare quality on your own prompts (sampling defaults and parsers can change).
- [ ] Swap the tag in one place (compose, unit file, manifest); keep the old environment or image until verified.
- [ ] Multi-node: same version and image ID everywhere (Ray and engine ranks must match).

## Notes from v0.18.0 (2026-09-28)

From the release notes, items that can change behaviour:

- Tool parameters now stream incrementally; `tool_choice="required"` was fixed; tool choice handling corrected for
  Intern-S and GPT-OSS.
- Falls back to the model's generation config when none is given (fix): sampling can differ from older runs.
- Multimodal requests to text-only models are now rejected.
- New `request-only` cache usage metric: `gpu_cache_usage_perc` meaning changed on the PyTorch engine
  (`LMDEPLOY_ENABLE_REQUEST_CACHE_USAGE_METRIC=0` restores total occupancy).
- TurboMind moved to C++20 (source builds need a C++20 host compiler); the legacy OpenAI API client was removed.
- Features: DFlash speculative decoding for Qwen3.5, input/output logprobs, checkpoint-engine weight updates.

Image tags published for v0.18.0: `v0.18.0-cu12.8` and `v0.18.0-cu13.0`. Earlier docs and examples still say
`latest`; do not use it in production.

## Roll back

Reinstall the previous pinned version or point the unit/compose back at the previous tag. Model files do not change.
