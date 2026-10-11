# Install

> Verified against KTransformers v0.7.1 (kt-kernel README, `doc/en/kt-kernel/AVX2-Tutorial.md`, `kt-kernel/install.sh`; PyPI kt-kernel and sglang-kt 0.7.0.post4), 2026-10-11

## Pick a path

| Situation                                                                  | Path                                                                  |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Typical Linux x86-64 box with NVIDIA GPU                                   | `pip install kt-kernel sglang-kt` in a fresh venv                     |
| AMD (BLIS) CPU prefill, ARM (KML), custom CUDA, portable or modified build | Source build with `kt-kernel/install.sh`                              |
| Everything from one checkout                                               | `./install.sh` at the repo root (kt-kernel plus the sglang submodule) |

Wheels exist for Python 3.10, 3.11 and 3.12 on Linux x86-64 (manylinux_2_17). The CUDA runtime is bundled statically (no toolkit needed
at runtime) and works with CUDA 11.8+ and 12.x drivers; CUDA 11.0 to 11.7 drivers are unsupported. The GPU part covers compute capability
8.0 to 9.0 (A100/A30, RTX 30, RTX 40, H100/H200); V100 and Turing (T4, RTX 20) are not supported. The wheel runs CPU-only too (CUDA features switch off).
Blackwell GPUs (RTX 50, B200) are not in the wheel's listed architectures: upstream tutorials mention RTX 5090 hardware but this skill
did not verify which install path supports it. Check `kt doctor` and the issue tracker first.

## pip install

```bash
python3 -m venv ~/kt-venv && . ~/kt-venv/bin/activate
pip install kt-kernel sglang-kt          # pin: kt-kernel==X sglang-kt==X (same version)
pip uninstall -y sglang 2>/dev/null      # the official sglang lacks --kt-* flags; sglang-kt replaces it
kt version
python -c "import kt_kernel; print(kt_kernel.__version__, kt_kernel.__cpu_variant__)"
```

`sglang-kt` pulls a pinned stack (torch 2.9.1, torchaudio 2.9.1, flashinfer 0.6.3, torch_memory_saver, torchao); use a dedicated venv and
do not mix with another torch. `pip install "kt-kernel[sglang]"` is the extra that adds `sglang-kt`.

CPU variants bundled in the wheel are picked at runtime: AMX (Sapphire Rapids+), AVX512+BF16 (Ice Lake server, Zen 4+), AVX512+VBMI,
AVX512+VNNI, AVX512 base, AVX2 (Haswell+, Zen+).

```bash
export KT_KERNEL_CPU_VARIANT=avx2        # force a variant (testing or debugging)
export KT_KERNEL_DEBUG=1                 # show detection at import time
```

## Source build

```bash
git clone --recursive https://github.com/kvcache-ai/ktransformers.git && cd ktransformers
git checkout v0.7.1 && git submodule update --init --recursive
conda create -n kt python=3.11 -y && conda activate kt        # or a venv
./install.sh                    # root: kt-kernel + sglang submodule; `kt-kernel/install.sh` builds kt-kernel only
./install.sh deps               # system packages only (cmake, libhwloc-dev, pkg-config)
./install.sh build              # build and install only
```

`install.sh` runs `apt` for build dependencies (needs sudo on Debian-based systems): review it before running. It detects the CPU
and compiles `-march=native`, so the result may not run on other or older CPUs. For portable builds:

```bash
export CPUINFER_CPU_INSTRUCT=AVX512    # NATIVE (default), AVX512, AVX2, FANCY (Ice Lake+/Zen 4+)
export CPUINFER_ENABLE_AMX=OFF
./install.sh build --manual
```

Other build variables: `CPUINFER_BUILD_TYPE` (Release, Debug, RelWithDebInfo), `CPUINFER_PARALLEL`, `CPUINFER_VERBOSE`,
`CPUINFER_ENABLE_AVX512_VNNI` / `_BF16` / `_VBMI` (override detection; VBMI is required for the FP8 MoE path),
`CPUINFER_ENABLE_ONEDNN_VNNI=ON` (oneDNN 3.9+ INT8 BRGEMM on non-AMX AVX512) with `KT_INT8_VNNI_BACKEND=auto|onednn|native`,
`CPUINFER_ENABLE_BLIS=ON` for AMD BLIS (`doc/en/kt-kernel/amd_blis.md`), `KT_RAWINT4_BACKEND=avx2` to force AVX2 RAWINT4,
`CPUINFER_PIP_NO_DEPS=1` to keep the existing Python stack. Manual build: `pip install -e .` or `pip install .` from `kt-kernel/`.

Force AVX2 on a machine that has AVX512 or AMX:

```bash
export KT_RAWINT4_BACKEND=avx2 CPUINFER_CPU_INSTRUCT=AVX2 CPUINFER_ENABLE_AMX=OFF
./install.sh kt-kernel --manual
```

## Verify

```bash
kt version                       # CLI, Python, platform, CUDA, kt-kernel (variant), sglang versions
kt doctor
python -c "from kt_kernel import KTMoEWrapper; print('ok')"
python -m sglang.launch_server --help | grep -- --kt-      # the flags your build actually has
```

## Docker

Upstream ships a `docker/` directory (Dockerfile and packaging scripts that produce images named `sglang-v<ver>_ktransformers-v<ver>_<cpu>_<cuda>_<mode>_<timestamp>`, with an infer mode and an SFT mode) and an old `doc/en/Docker.md` for `approachingai/ktransformers:0.2.1`, which predates the kt-kernel design: do not use it.

The one documented 0.7-era image is model-specific: `approachingai/ktransformers:DSV4-specific` for DeepSeek-V4-Flash (SM_86, SM_89 and SM_120 GPUs validated). Run it with `--gpus all --ipc host --cap-add SYS_NICE`, the model mounted read-only at `/model`, and the environment variables in `templates/docker-compose-dsv4.yml`. The floating tag moves; Docker Hub also lists commit-pinned tags such as `DSV4-specific-6b8a81c` (seen at verification, so re-check). For other models there is no verified pinnable image: use pip in a venv, or build your own on `nvidia/cuda` with the pinned wheels, mounting weights read-only and binding to loopback.

## Uninstall

`pip uninstall kt-kernel sglang-kt ktransformers`, delete the venv. Config and caches live in `~/.ktransformers` (`config.yaml`, `models/`, `cache/`).
