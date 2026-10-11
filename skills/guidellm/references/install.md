# GuideLLM: install

> Verified against GuideLLM 0.8.1 (PyPI, GitHub README and docs at tag v0.8.1), 2026-10-11

## Status

- Repository: https://github.com/vllm-project/guidellm (vLLM project). Apache-2.0, not archived, active: v0.8.1 on 2026-10-08, v0.8.0 on 2026-09-30, v0.7.4 on 2026-09-16, commits to `main` on 2026-10-11.
- PyPI `guidellm`, `requires-python >=3.10,<4.0`; upstream docs state Python 3.10 to 3.13 on Linux or macOS.
- Releases are frequent and the CLI has been reworked (0.7: `guidellm run`, registry `kind=` options; 0.8: `--override`, knee profile, warnings). See `updating.md`.

## Install (venv, pinned)

```bash
python3 -m venv ~/.venvs/guidellm-0.8.1
. ~/.venvs/guidellm-0.8.1/bin/activate
pip install "guidellm[recommended]==0.8.1"
guidellm --help
guidellm env | head
```

`[recommended]` is the extra upstream uses in its install instructions; without extras you may lack optional dependencies (check `pip show guidellm` and the project's `pyproject.toml` for extras on your version). From source: `pip install 'guidellm[recommended] @ git+https://github.com/vllm-project/guidellm.git@v0.8.1'`.

## Container

```bash
podman run --rm -it -v "./results:/results:rw" \
  -e GUIDELLM__SPEC__BACKEND='{"kind": "openai_http", "target": "http://localhost:8000"}' \
  -e GUIDELLM__SPEC__PROFILE='{"kind": "sweep"}' \
  -e GUIDELLM__SPEC__CONSTRAINTS='[{"kind": "max_duration", "seconds": 30}]' \
  -e GUIDELLM__SPEC__DATA='[{"kind": "synthetic_text", "prompt_tokens": 256, "output_tokens": 128}]' \
  ghcr.io/vllm-project/guidellm:v0.8.1
```

Image tags (upstream): `vX.Y.Z` immutable release (multi-arch amd64/arm64 from v0.7.0), `stable` newest full release, `latest` newest release tag (may be a pre-release), `nightly` tip of `main`. Do not use the architecture-suffixed tags. Pin `vX.Y.Z`. Inside a container, `localhost` is the container: use the host's address or `--network host` to reach a server on the host.

## Variants

- **vLLM in-process backend** (`vllm_python_async`, `vllm_python_batch`): no HTTP server. Use the GuideLLM + vLLM image (based on `vllm/vllm-openai`) or install GuideLLM into an existing vLLM environment, because vLLM's dependency set is the harder one. See `data-and-backends.md`.
- **Kubernetes/OpenShift job:** upstream example `docs/en/examples/kubernetes-openshift-job.md`. Applying manifests changes the cluster: ask first.

## Network use

- The tokenizer (and the model's metadata) loads from the Hugging Face Hub or a local path; HF datasets download on first use. Set `HF_TOKEN` for gated repos from a `0600` file or environment.
- Synthetic text samples from a bundled public-domain text unless `source` says otherwise.

## Settings

Environment variables with the `GUIDELLM__` prefix configure defaults; `guidellm env` shows what applies. Documented ones: `GUIDELLM__DEFAULT_RESULTS_DIR` (output directory), `GUIDELLM__LOGGING__CONSOLE_LOG_LEVEL`, `GUIDELLM__MP_CONTEXT_TYPE` (`fork` default, `spawn` for macOS), and `GUIDELLM__SPEC__BACKEND|PROFILE|CONSTRAINTS|DATA` (JSON, as in the container example).

Official sources: https://github.com/vllm-project/guidellm#quick-start, `docs/en/getting-started/install.md`.
