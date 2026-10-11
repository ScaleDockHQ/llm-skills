# GPT-QModel: install

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

Package `gptqmodel` on PyPI (repo ModelCloud/GPTQModel, Apache-2.0). Latest release v7.5.0 (2026-09-15); `main` carries 7.6.0-dev model additions.

## Requirements (from `requirements.txt` and `pyproject.toml`)

- Python `>=3.10` (3.10 to 3.14 classified; upstream also optimizes for free-threaded 3.13t).
- `torch>=2.8.0`, `transformers>=5.14.0`, `accelerate>=1.13.0`, `safetensors>=0.7.0`, `datasets>=3.6.0`, `ninja>=1.13.0` (first-use JIT kernel compilation), `maturin`, `torchao`, `tokenicer`, `logbar`, `device-smi` and others. These are pulled in by the install; use a clean venv so they do not downgrade a serving environment.
- A C++ toolchain and CUDA toolkit may be required for JIT kernels; `python3-dev` for some source installs (`apt install python3-dev`).

## Install

```bash
python3 -m venv ~/venvs/gptqmodel && . ~/venvs/gptqmodel/bin/activate
pip install torch --index-url https://download.pytorch.org/whl/cu128       # pick your CUDA index at pytorch.org
pip install -v gptqmodel                    # or: uv pip install -v gptqmodel
python -c "import gptqmodel;print(gptqmodel.__version__)"
```

Optional extras (from `pyproject.toml`): `vllm`, `sglang`, `bitblas`, `bitsandbytes`, `hf` (optimum), `eval` (Evalution), `triton`, `marlin-cuda12`, `marlin-cuda`, `openai` (uvicorn, fastapi, pydantic for `serve`), `mlx` (mlx, mlx_lm). Example: `pip install -v "gptqmodel[vllm,sglang,bitblas]"`. Installing `vllm` or `sglang` as extras pins their own torch versions; install them in a separate environment when you only need to serve.

From source:

```bash
git clone https://github.com/ModelCloud/GPTQModel.git && cd GPTQModel
pip install -v .            # extras: pip install -v ".[vllm,sglang,bitblas]"
```

Apple Silicon (MLX path): `pip install "gptqmodel[mlx]"`.

## Environment variables (README)

| Variable                                      | Effect                                                                                                                         |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `GPTQMODEL_USE_MODELSCOPE=True`               | Load models from ModelScope instead of the Hugging Face Hub                                                                    |
| `GPTQMODEL_FP32_ACCUM` (default `1`)          | fp32 accumulation in some AWQ and ParoQuant CUDA/Triton kernels; `0` is speed-first. Runtime only; does not change checkpoints |
| `GPTQMODEL_MARLIN_USE_FP32` (default enabled) | fp32 accumulation in Marlin                                                                                                    |
| `GPTQMODEL_CACHE_DIR`                         | Versioned user cache (default `~/.cache/gptqmodel`; `XDG_CACHE_HOME/gptqmodel` when set per upstream)                          |
| `GPTQMODEL_TORCH_EXTENSIONS_DIR`              | Relocate the JIT kernel cache (default `~/.cache/gptqmodel/torch_extensions`)                                                  |
| `GPTQMODEL_TORCH_OPS_LOCK_TIMEOUT`            | Seconds to wait for another process's build (default 600 or 5x the kernel's compile baseline)                                  |
| `GPTQMODEL_CUTLASS_DIR`                       | Use an already-installed read-only CUTLASS 4.7.1 checkout for Machete                                                          |
| `GPTQMODEL_OFFLINE=1`                         | No downloads; needs that checkout or a verified cache hit                                                                      |
| `GPTQMODEL_MACHETE_PRECOMPILED_LIBRARY`       | Path to a compatible Machete shared library (an invalid explicit path is an error, not a fallback to JIT)                      |

Prewarm the Machete extension before an offline or sandboxed run: `python -c "from gptqmodel import extension; extension.load('machete')"`.

Multiple processes on one host can share the JIT cache: builds are serialized by a cross-process file lock.

## Logging and Triton

```python
from logbar import LogBar
LogBar.shared().setLevel("WARNING")
```

If a script imports several Triton users (gptqmodel, vllm, sglang) on free-threaded Python 3.13+, apply `from gptqmodel import TritonPatch; TritonPatch.apply()` at the very top (upstream operational note).

## Verify

```bash
python -c "from gptqmodel import GPTQModel, GPTQConfig, BACKEND; print('ok')"
```
