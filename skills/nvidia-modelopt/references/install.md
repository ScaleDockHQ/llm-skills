# Installing NVIDIA Model Optimizer

> Verified against NVIDIA Model Optimizer 0.47.0 (PyPI `nvidia-modelopt` metadata, README.md, docs/source/getting_started/_installation_for_Linux.rst, examples/hf_ptq/README.md, examples/hf_ptq/requirements.txt, CHANGELOG.rst), TensorRT-LLM v1.2.1 release notes, 2026-10-11

Upstream: [NVIDIA/Model-Optimizer](https://github.com/NVIDIA/Model-Optimizer), Apache-2.0, not archived, last push 2026-10-11 (GitHub API). PyPI `nvidia-modelopt` 0.47.0 was released 2026-09-23; GitHub also has a `0.48.0rc0` pre-release (2026-10-08), which this skill does not use. The repo was renamed from `NVIDIA/TensorRT-Model-Optimizer`; the old name redirects (checked with the GitHub API) and upstream announced the rebrand to "NVIDIA Model Optimizer" on 2025-12-08.

## System requirements (0.47.0, from the Linux install doc)

| Item         | Requirement            |
| ------------ | ---------------------- |
| OS           | Linux                  |
| Architecture | x86_64, aarch64 (SBSA) |
| Python       | `>=3.10,<3.15`         |
| CUDA         | 12.x, 13.x             |
| PyTorch      | `>=2.8`                |
| TensorRT-LLM | optional, `>=1.0`      |

PyPI metadata for 0.47.0 lists extras `onnx`, `hf`, `puzzletron`, `mlflow`, `all`, and dev extras. The `hf` extra adds `transformers`-side dependencies (`accelerate`, `datasets`, `huggingface_hub`, `peft`, `sentencepiece`, `diffusers`, `nltk`, `deepspeed` on Linux).

## Venv install (HF LLM quantization)

```bash
python3 -m venv ~/venvs/modelopt && . ~/venvs/modelopt/bin/activate
# If you need a specific CUDA build of PyTorch, install it first (https://pytorch.org/get-started/locally/)
pip install -U "nvidia-modelopt[hf]"
python -c "import modelopt; print(modelopt.__version__)"
```

`[hf]` is what upstream's `hf_ptq` README uses (`pip install -U nvidia-modelopt[hf]` plus the example requirements). Upstream's main README suggests `nvidia-modelopt[all]` for everything. The first use of the PyTorch quantization APIs compiles fast kernels with your torch and CUDA, which "may take a few minutes"; pre-compile with `python -c "import modelopt.torch.quantization.extensions as ext; ext.precompile()"`.

## Example scripts: clone the matching tag

`hf_ptq.py` lives in the repo, not in the wheel. Check out the tag that matches the installed package (0.47.0 here); recipes and flags change between releases.

```bash
git clone https://github.com/NVIDIA/Model-Optimizer ~/src/Model-Optimizer
cd ~/src/Model-Optimizer && git checkout 0.47.0
pip install -r examples/hf_ptq/requirements.txt
ls examples/hf_ptq
```

The 0.47.0 `examples/hf_ptq/requirements.txt` lists `compressed-tensors`, `fire`, `flash-attn>=2.6.0`, `mlflow-skinny>=2.9`, `psutil`, `transformers_stream_generator` and `zstandard`. `flash-attn` can compile from source and needs a CUDA toolchain; if the build is slow or fails, install the rest first and see if your model needs it (advice). (unverified) behaviour of `flash-attn` on aarch64 / DGX Spark.

In 0.47.0 the old `examples/llm_ptq` symlink and the `examples/vlm_ptq` forwarder were removed (changelog); use `examples/hf_ptq`, with `--vlm` for vision-language models. Other projects' docs, including vLLM's and TensorRT-LLM's quantization pages, still say `examples/llm_ptq` or `TensorRT-Model-Optimizer`.

## NVIDIA containers

Upstream's recommended environment for full deployment dependencies is the TensorRT-LLM container with ModelOpt pre-installed, then upgrade ModelOpt inside it with pip:

- `nvcr.io/nvidia/tensorrt-llm/release:<version>` (the HF PTQ README names `release:1.2.0` as an example)
- `nvcr.io/nvidia/pytorch:<version>-py3`
- `nvcr.io/nvidia/nemo:<version>` (Megatron-Bridge and Megatron-LM flows)
- `nvcr.io/nvidia/tensorrt:<version>-py3` (ONNX and TensorRT flows)

Review the container license terms before pulling. For TensorRT binaries upstream also documents `PIP_CONSTRAINT=""` and `LD_LIBRARY_PATH` additions. Which tags have arm64 builds for DGX Spark is (unverified): check the NGC catalog.

## DGX Spark and Blackwell notes

- ModelOpt supports `aarch64 (SBSA)`, so a CUDA PyTorch on the Spark's arm64 Linux is the expected path. GB10 reports compute capability 12.1 (`nvidia-smi --query-gpu=compute_cap --format=csv`).
- TensorRT-LLM v1.2.1 release notes list "DGX Spark Support (Beta)" with only single-node configurations and a limited model list validated. TensorRT-LLM's quantization hardware matrix names Blackwell sm120 and sm100/103 for NVFP4; whether sm121 gets native FP4 GEMMs in a given vLLM or SGLang build is (unverified): read the engine's startup log for the selected GEMM backend.
- Calibration is GPU-heavy and holds the whole BF16 model; stop other model servers first and cap memory (`model-quantization` skill, memory-safety reference).

## Verify

```bash
python -c "import modelopt, modelopt.torch.quantization as mtq; print(modelopt.__version__, mtq.NVFP4_DEFAULT_CFG is not None)"
cd ~/src/Model-Optimizer/examples/hf_ptq && python hf_ptq.py --help | head -30
```

Third-party notices: upstream warns that Model Optimizer downloads and installs additional open-source projects; review their licenses.
