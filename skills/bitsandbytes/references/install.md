# Installing bitsandbytes

> Verified against bitsandbytes 0.50.2 (docs/source/installation.mdx, README, PyPI metadata), 2026-10-11

## Requirements

- Python 3.10 or newer; PyTorch 2.4 or newer (PyPI `requires_python >=3.10`, `torch>=2.4,<3`). Windows ARM64 needs Python 3.12+.
- Backends with official support: NVIDIA CUDA, AMD ROCm, Intel XPU, Intel Gaudi, CPU, Apple Silicon (CPU backend, macOS arm64 wheel).
- The PyPI wheel carries the native libraries; no separate CUDA toolkit is needed at runtime beyond what PyTorch brings.

## Hardware by feature

| Backend     | Requirement                                                                               | Notes                                                                                       |
| ----------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| NVIDIA CUDA | Compute capability 6.0+ for NF4/FP4 and 8-bit optimizers                                  | LLM.int8() needs 7.5+ (Turing, T4 or newer).                                                |
| AMD ROCm    | CDNA (gfx908, gfx90a, gfx942, gfx950, gfx1250) and RDNA (gfx101X, 103X, 110X, 115X, 120X) | Needs ROCm-enabled PyTorch.                                                                 |
| Intel XPU   | Data Center GPU Max, Arc A-Series, Arc B-Series                                           | PyTorch 2.6.0 minimum.                                                                      |
| Intel Gaudi | Gaudi2, Gaudi3                                                                            | Gaudi v1.21 with PyTorch 2.6.0; 4-bit partial, 8-bit optimizers unsupported (README table). |
| CPU         | Linux x86-64 needs AVX2 (AVX512 optimized), aarch64, Windows, macOS arm64                 |                                                                                             |

## Install

```bash
python3 -m venv ~/venvs/bnb && . ~/venvs/bnb/bin/activate
pip install bitsandbytes            # or: uv pip install bitsandbytes
python3 -m bitsandbytes             # diagnostics and sanity check
```

Install a PyTorch build that matches the accelerator first (CUDA, ROCm, XPU wheel index); bitsandbytes picks its native library from what PyTorch reports. Ask before installing.

PyPI wheels ship CUDA builds for toolkit 11.8 to 12.6, 12.8 and 13.0 to 13.2 on Linux x86-64; the exact SM targets differ per row (the 12.8 and 13.x builds add sm100 and sm120). The Linux build needs glibc 2.24 or newer (2.34 for XPU).

### NVIDIA Spark and Jetson

- NVIDIA Spark (ARM64): install PyTorch from the NVIDIA index (`pip install torch --index-url https://pypi.nvidia.com/nvtorch_oot/`), then `pip install bitsandbytes`.
- Jetson (L4T, JetPack): the aarch64 wheels do not work (symbol-not-found at the first CUDA op). Build on the device: `cmake -DCOMPUTE_BACKEND=cuda -DCOMPUTE_CAPABILITY=87 . && make -j4 && pip install .` (87 for Orin, 72 for Xavier), or use a third-party index such as Jetson AI Lab.

## Build from source

CUDA (Linux): CMake 3.22.1+, GCC 11 or newer, CUDA Toolkit 11.8+.

```bash
git clone https://github.com/bitsandbytes-foundation/bitsandbytes.git && cd bitsandbytes/
cmake -DCOMPUTE_BACKEND=cuda -S .
make
pip install -e .
```

ROCm: CMake 3.31.6+, ROCm 6.3 or newer, `cmake -DCOMPUTE_BACKEND=hip -S .` (add `-DBNB_ROCM_ARCH="gfx90a;gfx942"` to target architectures). CPU only: `pip install -e .` from a checkout. Resolve duplicate CUDA paths in `PATH` and `LD_LIBRARY_PATH` before compiling.

## Preview wheels

Upstream publishes a rolling wheel from `main` under the release tag `continuous-release_main`. The file name always says `1.33.7.preview`; the real version installed is the dev version. Add `--no-deps` so a custom PyTorch build is not replaced. Use it only to test an unreleased fix, and record it.

## Native library selection

bitsandbytes looks for `libbitsandbytes_cuda{major}{minor}` (or `_rocm`) from `torch.version.cuda` (or `torch.version.hip`) and falls back to the closest shipped version with a warning. Force one with a digits-only variable:

```bash
export BNB_CUDA_VERSION=128    # or BNB_ROCM_VERSION=72
```

## Check the install

```bash
python3 -m bitsandbytes 2>&1 | tail -25
python3 -c "import bitsandbytes as bnb; print(bnb.__version__)"
```
