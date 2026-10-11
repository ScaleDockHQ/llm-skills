# Diffusers: updating

> Verified against Diffusers v0.41.0 (GitHub releases v0.39.0 to v0.41.0, docs installation, contribution release policy as cited in the v0.41.0 notes), 2026-10-11

## Release cadence and policy

Releases: v0.39.0 (2026-07-03), v0.40.0 (2026-08-20), v0.41.0 (2026-10-06). The v0.41.0 notes say Diffusers now follows the Transformers philosophy: minor releases are coordinated around new model integrations and also include other merged changes; patch releases are for fixes only. v0.41.0 added Qwen-Image 2.1 and deprecated ONNX support (use Optimum for ONNX Runtime), and removed previously deprecated APIs, including the `LuminaText2ImgPipeline` and `Lumina2Text2ImgPipeline` aliases (use `LuminaPipeline` and `Lumina2Pipeline`). New models usually need the new minor release.

## Before

```bash
python3 -c 'import diffusers;print(diffusers.__version__)'; pip freeze | rg -i 'diffusers|torch|transformers|accelerate|peft|huggingface'
gh release list -R huggingface/diffusers -L 5
```

Generate one fixed-seed reference image per pipeline you rely on.

## Update

- Release: `uv pip install -U "diffusers[torch]"`; upgrade `transformers`, `accelerate`, `peft` and `huggingface_hub` together (0.41.0 requires `huggingface-hub>=1.32,<2`).
- Pinned: `uv pip install "diffusers==0.41.0"`.
- `main`: `uv pip install -U git+https://github.com/huggingface/diffusers`; for an editable clone `git pull` in the clone.
- Do it in a copy of the environment (`uv venv` plus the same requirements) so rollback is deleting a directory.

## After

1. Run `diffusers-cli env`, then regenerate the reference image; small numerical drift is normal across versions and hardware.
2. Search code for removed or renamed APIs: `torch_dtype` (docs now use `dtype`), the Lumina aliases, ONNX pipelines.
3. Re-run `diffusers-cli run --help` and compare flags used in scripts.
4. Re-check quantization and compile paths; they depend on versions of `bitsandbytes`, `torchao` and PyTorch.

## Roll back

Reinstall the previous pinned version in the old environment; Hub caches are not changed by an upgrade.
