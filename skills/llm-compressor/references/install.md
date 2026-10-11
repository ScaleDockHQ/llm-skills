# Installing LLM Compressor

> Verified against llm-compressor 0.14.0 (PyPI metadata, docs/getting-started/install.md, docs/faq/faq.md), compressed-tensors 0.19.0, vLLM v0.31.0, 2026-10-11

Upstream: [vllm-project/llm-compressor](https://github.com/vllm-project/llm-compressor), Apache-2.0, not archived, last push 2026-10-09 (checked with the GitHub API). PyPI package `llmcompressor`, latest 0.14.0 (released 2026-09-22), Python `>=3.10`.

## Pinned dependencies (llmcompressor 0.14.0)

From the PyPI metadata of the 0.14.0 wheel:

| Package              | Constraint          |
| -------------------- | ------------------- |
| `torch`              | `>=2.10.0,<=2.14.0` |
| `transformers`       | `>=5.15.0,<=5.17.0` |
| `datasets`           | `>=4.8.4,<=5.0.1`   |
| `accelerate`         | `>=1.15.0,<=1.15.0` |
| `compressed-tensors` | `==0.19.0`          |
| `auto-round`         | `>=0.14.1,<=0.15.1` |

`pip` resolves these for you. If you pre-installed a CUDA build of PyTorch, keep it inside that range or `pip` replaces it.

## Venv install

Linux is the recommended OS for GPU work. Keep it in its own venv, separate from the vLLM you serve with: upstream's FAQ says vLLM and LLM Compressor "should be used in separate environments as they may have dependency mismatches".

```bash
python3 -m venv ~/venvs/llmc && . ~/venvs/llmc/bin/activate
python -m pip install --upgrade pip
pip install llmcompressor            # or: pip install llmcompressor==0.14.0
python -c "import llmcompressor, compressed_tensors; print('ok')"
pip show llmcompressor compressed-tensors transformers torch | grep -E '^(Name|Version):'
```

Other upstream install paths: `pip install git+https://github.com/vllm-project/llm-compressor.git` (main branch, ahead of the release), and a local clone with `pip install -e .[dev]` (needed to run the repo's `examples/` unmodified).

## Get the upstream examples (optional)

The `examples/` folder is the best source for model-specific recipes. Pin it to the release tag you installed:

```bash
git clone --branch 0.14.0 --depth 1 https://github.com/vllm-project/llm-compressor.git ~/src/llm-compressor
ls ~/src/llm-compressor/examples
```

Folders at 0.14.0 include `quantization_w4a16`, `awq`, `quantization_w8a8_fp8`, `quantization_w8a8_int8`, `quantization_w4a4_fp4`, `quantization_w4a4_mxfp4`, `quantization_w4a16_fp4`, `quantization_w4a8_fp8`, `quantization_kv_cache`, `quantizing_moe`, `multimodal_vision`, `multimodal_audio`, `big_models_with_sequential_onloading`, `disk_offloading`, `model_free_ptq`, `reap_expert_pruning`, `transform`, `autoround`, `imatrix`.

## Hardware and platform notes

- Calibration needs an NVIDIA GPU for anything but tiny models. The sequential pipeline (the default for calibrated recipes) onloads one decoder layer at a time, so a 24 GB GPU can quantize large models given enough CPU RAM or disk (`big-models.md`).
- DGX Spark / other arm64 machines: the package is pure Python on top of PyTorch and compressed-tensors, but a CUDA-enabled `torch` wheel for arm64 must be installable in the range above. (unverified) on GB10: no upstream statement found about arm64 or GB10, so run the import check and a small-model recipe before planning a big job.
- Unified-memory machines share RAM between CPU and GPU: calibration loads the full model on CPU first, so cap memory and stop serving (`model-quantization` skill, memory-safety reference).
- Gated models need a Hub login: `hf auth login` or `HF_TOKEN` in the environment. Never echo the token.

## Serving environment

Install vLLM in a different venv (or container) and point it at the saved directory (`vllm-integration.md`). For evaluation, upstream's vLLM guide installs `vllm` and `lm-eval[api]>=0.4.12` together in the serving venv.

## Verify the install

```bash
python - <<'PY'
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier
print("imports ok")
PY
```

If this fails with a `transformers` or `torch` error, compare against the pins above (`troubleshooting.md`).
