# Installing DeepSpeed

> Verified against DeepSpeed v0.19.7, 2026-10-11

## What it is and status

[DeepSpeed](https://github.com/deepspeedai/DeepSpeed) (Apache-2.0, now under the `deepspeedai` organization) is actively maintained: v0.19.7 released 2026-09-16 (v0.19.6 on 2026-08-27, v0.19.5 on 2026-08-10), last push 2026-10-11. Core dependencies at v0.19.7: `torch>=2.0.0`, `ninja`, `numpy`, `pydantic>=2.0.0`, `hjson`, `psutil`, `einops`, `msgpack`, `packaging>=20.0`, `py-cpuinfo`, `tqdm`. PyPI declares no `python_requires` for this release.

## Requirements (upstream README)

- PyTorch must be installed **before** DeepSpeed; PyTorch >= 2.0 for full features, ideally the latest stable.
- A CUDA or ROCm compiler (`nvcc` or `hipcc`) to compile C++/CUDA extensions ("ops").
- Best-tested GPUs: NVIDIA Pascal, Volta, Ampere, Hopper; AMD MI100 and MI200. Contributed accelerators: Huawei Ascend NPU (`npu`), Intel Gaudi 2 (`hpu`), Intel Xeon (`cpu`), Intel Data Center GPU Max (`xpu`), Tecorigin (`sdaa`).

## Install

```bash
uv venv && source .venv/bin/activate
uv pip install torch                 # pick the CUDA build for your platform first
uv pip install deepspeed             # or: pip install deepspeed
ds_report
```

By default all ops are built just-in-time (JIT) on first use with torch's C++ extension loader and ninja, and cached in `~/.cache/torch_extensions/`. Use one cache per environment when Python or CUDA differ: `TORCH_EXTENSIONS_DIR=./torch-extensions deepspeed ...`.

## Pre-build ops (optional)

```bash
DS_BUILD_OPS=1 pip install deepspeed          # all compatible ops
DS_BUILD_CPU_ADAM=1 DS_BUILD_FUSED_ADAM=1 pip install deepspeed
```

Options include `DS_BUILD_AIO`, `DS_BUILD_CPU_ADAM`, `DS_BUILD_CPU_LION`, `DS_BUILD_FUSED_ADAM`, `DS_BUILD_FUSED_LAMB`, `DS_BUILD_QUANTIZER`, `DS_BUILD_TRANSFORMER_INFERENCE` and others (see the advanced install tutorial). Pre-building needs PyTorch present and only builds ops compatible with the machine. For a wheel reusable on identical machines: `DS_BUILD_OPS=1 python -m build --wheel --no-isolation`. Multi-node source installs can use the repo's `install.sh` with a hostfile.

Build for the GPUs you have to avoid `no kernel image is available for execution on the device`: `TORCH_CUDA_ARCH_LIST="8.6" pip install ...` (list from https://developer.nvidia.com/cuda-gpus; also speeds up the build).

## CUDA toolkit must match PyTorch

DeepSpeed compiles with the system toolkit, not the one inside PyTorch wheels. If `nvcc --version` differs from `python -c 'import torch; print(torch.version.cuda)'`, the op builder raises "Installed CUDA version ... does not match the version torch was compiled with". Fix by installing a matching toolkit or torch build. Major versions must match; minor mismatches warn. `DS_SKIP_CUDA_CHECK=1` skips the check at your own risk. With several toolkits installed, put the right one first:

```bash
export CUDA_HOME=/usr/local/cuda-<ver>
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

(Transformers' debugging guide covers older compiler pairing and prebuilds.) Do not edit system toolkits without approval; prefer a conda or container toolchain.

## Platforms

- **Windows:** many features work for training and inference; async IO (AIO) and GDS do not. Needs PyTorch, Visual C++ build tools and `build_win.bat` per the README.
- **ARM / DGX Spark:** upstream docs read for this skill do not state support (unverified). v0.19.x release notes mention an ARM SVE CPU-Adam kernel; GPU op availability on aarch64 must be checked with `ds_report`.
- **From source:** `git clone https://github.com/deepspeedai/DeepSpeed && cd DeepSpeed && pip install .` (JIT mode, quick); a conda `environment.yml` with the toolchain is provided.

## Verify

```bash
ds_report                       # or: python -m deepspeed.env_report
python -c 'import deepspeed; print(deepspeed.__version__)'
```

`ds_report` shows which ops are installed or compatible, torch, CUDA and nvcc versions, and missing system packages for specific features. Include it in bug reports.
