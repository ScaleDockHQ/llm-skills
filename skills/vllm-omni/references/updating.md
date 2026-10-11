# vLLM-Omni: updating

> Verified against vLLM-Omni v0.30.0 (vLLM 0.30.0) (GitHub releases, PyPI and Docker Hub tags), 2026-10-11

Releases track vLLM minor versions and ship often (0.28.0, 0.29.0rc1, 0.30.0rc1, 0.30.0 on 2026-09-25, 0.31.0rc1 on 2026-10-06). Read the release notes before upgrading; model support and flags move between versions.

## Rules

1. Upgrade vLLM and vLLM-Omni together, to the same major.minor (`vllm==0.30.0` with `vllm-omni==0.30.0`). vLLM-Omni 0.28.x needs vLLM 0.28.x.
2. Use stable tags. `rc` wheels and `nightly` images follow main.
3. Use a fresh environment for a new pair: kernels are built per CUDA and PyTorch combination.

```bash
pip list 2>/dev/null | grep -Ei '^(vllm|vllm-omni) '
gh release list -R vllm-project/vllm-omni --limit 5
uv venv --python 3.12 --seed .venv-new && source .venv-new/bin/activate
uv pip install vllm==X.Y.Z --torch-backend=auto && uv pip install vllm-omni==X.Y.Z
```

Docker: change the tag (`vllm/vllm-omni:vX.Y.Z`), pull and recreate. Smoke test with one request per task you serve. Rollback: switch the unit or container back to the previous venv or tag. Model weights are in the Hugging Face cache and are unaffected.

Also re-check: stage-config or deploy YAML keys you override, CLI flags in your service files, and the model's recipe (recipes.vllm.ai) after a version bump.
