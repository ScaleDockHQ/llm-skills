# SGLang Diffusion: updating

> Verified against SGLang Diffusion v0.5.21 (GitHub releases, PyPI, Docker Hub tags), 2026-10-11

SGLang releases every two to three weeks (v0.5.19 on 2026-09-05, v0.5.20 on 2026-09-18, v0.5.21 on 2026-10-02). Diffusion flags and the model registry change quickly; read the release notes first.

```bash
pip list 2>/dev/null | grep -Ei '^(sglang|sgl-kernel|diffusers|cache-dit) '
gh release list -R sgl-project/sglang --limit 5
uv venv --python 3.12 .venv-new && source .venv-new/bin/activate
uv pip install "sglang[diffusion]==X.Y.Z" --prerelease=allow
sglang serve --help | head -3
```

- Pin the version, in a new venv, and keep the old one until a smoke test passes (one image, one video).
- Docker: change the `lmsysorg/sglang` tag (never `latest` or `dev` in production), pull, recreate.
- Re-diff your flag list against `sglang serve --help`: options are renamed (for example component-scoped quantization options superseded older ones; the old transformer spellings remain as aliases).
- The `diffusion` extra pins versions of diffusers, cache-dit and others; installing LLM-serving extras into the same venv can conflict, so use a separate venv per workload.
- Rollback: reinstall the previous version or tag. Model weights in the Hugging Face cache are unaffected; materialized overlay repos are re-created.
