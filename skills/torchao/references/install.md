# Installing torchao

> Verified against torchao v0.18.0 (README, release notes, compatibility table issue 2919, PyPI), 2026-10-11

## Pair torchao with PyTorch

torchao contains compiled kernels built against one torch version. A mismatch can end with `Fatal Python error: Aborted` on `import torchao`. Upstream's compatibility table (https://github.com/pytorch/ao/issues/2919) lists, per release, the torch it was built with and the torch versions its Python-only API supports:

| torchao | built with torch | Python API also works on |
| ------- | ---------------- | ------------------------ |
| 0.17.0  | 2.11.0+          | 2.11, 2.10, 2.9          |
| 0.16.0  | 2.10.0           | 2.10, 2.9, 2.8           |
| 0.15.0  | 2.9.1            | 2.9.1, 2.8, 2.7.1        |
| 0.14.1  | 2.9.0            | 2.9.0, 2.8, 2.7.1        |
| 0.13.0  | 2.8.0            | 2.8, 2.7.1, 2.6          |

The 0.18.0 release notes state the minimum PyTorch is now 2.11 (older versions were removed from the code); the table had no 0.18.0 row when read, so treat torch 2.11 or newer as the floor and re-read the table before pinning. Optional `fbgemm_gpu` supports one torch version per release; follow its own matrix.

## Install

```bash
python3 -m venv ~/venvs/torchao && . ~/venvs/torchao/bin/activate
pip install torchao                                                    # latest stable (0.18.0 on 2026-10-11)
pip install torchao --index-url https://download.pytorch.org/whl/cu126 # or cu129, xpu, cpu
python3 -c "import torch, torchao; print(torch.__version__, torchao.__version__)"
```

Install the torch build for your accelerator first and keep it. Ask before installing. Nightly: `pip install --pre torchao --index-url https://download.pytorch.org/whl/nightly/cu128`; a nightly torchao needs a nightly torch.

Transformers integration needs torchao 0.15.0 or newer: `pip install --upgrade torchao transformers accelerate`.

## Optional kernels

- **MSLK** provides faster float8 and NVFP4 inference kernels: `pip install mslk --index-url https://download.pytorch.org/whl/cu130`. Use stable MSLK with stable torchao, nightly with nightly.
- **MXFP8 MoE training** kernels need `apache-tvm-ffi` and pinned `nvidia-cutlass-dsl` packages (upstream README lists the exact versions).
- **gemlite** is required by the `UIntxWeightOnlyConfig` prototype configs (Triton kernels).

## Build from source

Needs `--no-build-isolation`: `USE_CUDA=1 pip install -e . --no-build-isolation` (`USE_XPU=1` for Intel XPU, `USE_CPP=0` to skip C++ extensions).
