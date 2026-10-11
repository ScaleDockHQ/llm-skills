# Updating LLM Compressor

> Verified against llm-compressor 0.14.0 (PyPI, GitHub releases 0.13.0 and 0.14.0, docs/getting-started/install.md), compressed-tensors 0.19.0 (PyPI, releases), vLLM v0.31.0, 2026-10-11

## Where releases come from

- PyPI `llmcompressor` (latest 0.14.0, released 2026-09-22) and GitHub releases/tags at https://github.com/vllm-project/llm-compressor/releases. Patch tags with four numbers exist (for example `0.12.0.2`), and the GitHub "latest" release is the one to trust (`gh api repos/vllm-project/llm-compressor/releases/latest --jq .tag_name`); the first entries of the release list are not sorted by version.
- `compressed-tensors` is pinned exactly by each llmcompressor release (0.14.0 requires `compressed-tensors==0.19.0`), so upgrade llmcompressor and let pip move it.
- Project status checked 2026-10-11: not archived, active pushes, Apache-2.0.

## Check what you have

```bash
. ~/venvs/llmc/bin/activate
pip show llmcompressor compressed-tensors transformers torch | grep -E '^(Name|Version):'
pip index versions llmcompressor 2>/dev/null | head -2
gh api repos/vllm-project/llm-compressor/releases/latest --jq '.tag_name,.published_at'
```

## Upgrade safely

1. Read the release notes between your version and the target (`gh api repos/vllm-project/llm-compressor/releases/tags/<tag> --jq .body`). Look for removed or renamed modifiers, import paths, scheme names and `transformers` or `torch` pin changes.
2. Create a fresh venv; do not upgrade in place next to vLLM:

   ```bash
   python3 -m venv ~/venvs/llmc-new && . ~/venvs/llmc-new/bin/activate
   pip install -U llmcompressor
   ```

3. Re-run a small model (a 0.5B to 1B model with the same scheme) and compare the output config and a smoke prompt against the old checkpoint.
4. Test the new checkpoint on the vLLM version you serve with. Newer compressed-tensors checkpoints can need a newer vLLM.
5. Switch the production script only after the small run and the vLLM check pass; keep the old venv until then.

## Changes seen between 0.12 and 0.14 (from release notes)

- 0.13.0: `REAPPruningModifier`; arbitrary bit-width presets (W2 to W8 with A4, A8 or A16) with dense packing in compressed-tensors; observer lifecycle refactor that cuts memory on large models; experimental `oneshot` support for pre-quantized models whose targeted layers are not yet quantized.
- 0.14.0: Triton GPTQ kernel and layer batching (Hessian offloading removed); expanded MSE and iMatrix observers for NVFP4; REAP with DDP; model-free PTQ unified into `ModelFreePtqConverter` with mixed precision and KV-cache support; MoE helpers (`patch_moe_mappings()`, `repack_moe()`).
- Imports in current examples use `from compressed_tensors.offload import dispatch_model` and `from llmcompressor.utils import load_context`; older blog posts and notebooks use other paths such as `llmcompressor.transformers`. Prefer the examples at your installed tag (`git clone --branch <tag>`).

## Updating vLLM

See the `vllm` skill. After a vLLM upgrade, re-run the smoke prompts on your checkpoints and read the `Selected <kernel>` startup lines, since kernel selection changes between versions.

## Update this skill's facts

Re-read the upstream docs and `examples/` at the new tag, re-check the PyPI pins listed in `install.md` and the scheme names in compressed-tensors `quant_scheme.py`, then update each reference's `> Verified against ...` line and the skill's version.
