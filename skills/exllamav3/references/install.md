# Install ExLlamaV3 and TabbyAPI

> Verified against ExLlamaV3 v1.6.1 and TabbyAPI main (20d66e2), 2026-10-11

Pick one path. All of them need approval before running. TabbyAPI pins the exllamav3 version it was tested with (its `pyproject.toml` extras `cu12`, `cu13`, `rocm`), so installing TabbyAPI installs a matching wheel; install exllamav3 by hand only for library use or a custom build.

## Platform matrix

| Platform                         | Path                                                              | Notes                                                             |
| -------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------- |
| Linux x86_64, NVIDIA, CUDA 12.8  | `ghcr.io/theroyallab/tabbyapi:latest` or `pip install -U .[cu12]` | cu12 extra pins torch 2.9.0+cu128, Python 3.10 to 3.13            |
| Linux x86_64, NVIDIA, CUDA 13    | `:cu13` image or `.[cu13]`                                        | torch 2.11.0+cu130 with exllamav3 cu132 wheel, Python 3.12+       |
| Windows, NVIDIA                  | `start.bat` or `.[cu12]`/`.[cu13]`                                | wheels are `win_amd64`; `triton-windows` is a dependency          |
| Linux x86_64, AMD RDNA1 to RDNA4 | `:latest-rocm` image or `.[rocm]`                                 | Instinct (CDNA) needs a source build; Windows ROCm is source only |
| Linux aarch64 (DGX Spark/GB10)   | source build                                                      | no upstream aarch64 wheels or images (see below)                  |
| macOS / CPU only                 | not supported                                                     | use `llama-cpp` or `mlx`                                          |

Requirements from ExLlamaV3's README: PyTorch installed first (torch is not resolved by pip for the plain package), CUDA 12.4 or later, `torch>=2.6.0`, Python >=3.10.11. Paged attention in TabbyAPI needs Ampere or newer. FlashAttention is credited as an acknowledgement; the README does not list it as a dependency (attention kernels are Triton/CUDA in the library), so do not install `flash-attn` for ExLlamaV3.

## Docker (recommended on x86_64)

Install Docker and the NVIDIA Container Toolkit first.

```bash
docker pull ghcr.io/theroyallab/tabbyapi:latest
docker run --gpus all --shm-size=8g --name tabbyapi -p 127.0.0.1:5000:5000 \
  -v /srv/models/exl3:/app/models ghcr.io/theroyallab/tabbyapi:latest
```

Tags (README): `latest` (CUDA 12.8), `cu13`, `latest-rocm` (Radeon RX 7900 series; other GPUs build from `docker/Dockerfile.rocm`), `latest-extras` (CUDA 12.8 plus the embeddings stack). On 2026-10-11 `latest`, `cu13` and `latest-extras` manifests listed only linux/amd64; the `latest-rocm` manifest could not be inspected anonymously (unverified). Check `docker manifest inspect ghcr.io/theroyallab/tabbyapi:<tag>` before relying on an arch.

Image facts from the Dockerfiles: entrypoint `python3`, default command `main.py --host 0.0.0.0`, port 5000, working dir `/app`, `cu13` built on `nvidia/cuda:13.2.1-runtime-ubuntu24.04`. Mount `/app/models`, optionally `/app/config.yml` and `/app/api_tokens.yml`. Always keep `--shm-size=8g` or use `--ipc=host`; the shm is a tmpfs upper bound, not a reservation. In a mounted config, `host` is overridden by the CMD `--host 0.0.0.0`, so publish the port on `127.0.0.1` only.

Passing options: `docker run ... ghcr.io/theroyallab/tabbyapi:latest main.py --host 0.0.0.0 --model-name <folder> --max-seq-len 32768` (first argument must be `main.py`; config keys map to `--<key-with-dashes>`; CLI arguments override config.yml).

Build locally (needed for custom exllamav3): `docker build -f docker/Dockerfile.cu13 -t tabbyapi:local .` (`--build-arg EXTRAS=1` adds the embeddings stack; ROCm: `docker/Dockerfile.rocm --build-arg ROCM_TARGETS=gfx1100`). See `templates/docker-compose.yml`.

## Start script (beginner path)

```bash
git clone https://github.com/theroyallab/tabbyAPI && cd tabbyAPI
./start.sh        # Windows: start.bat
```

The script creates a venv (uses `uv` with Python 3.12 if present, else `python3 -m venv`), asks for the GPU library, installs dependencies and starts the API with no model loaded unless `config.yml` names one. It skips the venv check inside conda. `--nowheel` skips updating torch/exllamav3 wheels. A saved choice is in `start_options.json`.

## Manual (advanced)

```bash
python -m venv venv && source venv/bin/activate
pip install -U .[cu12]     # or .[cu13] (Python 3.12+); ROCm: see ROCm section
python main.py
```

Plain `pip install .` skips the GPU extra and keeps whatever torch/exllamav3 you installed (use this with a custom wheel, otherwise the extra overwrites it).

## ExLlamaV3 alone

Prebuilt wheel (recommended upstream): choose from the releases page. Wheel names encode CUDA, torch and Python, for example `exllamav3-1.6.1+cu132.torch2.13.0-cp313-cp313-linux_x86_64.whl`. v1.6.1 ships `cu128` (torch 2.8 to 2.11), `cu132` (torch 2.11 to 2.13) and `rocm10.0` (torch 2.13, Linux, cp312 to cp314) wheels for linux_x86_64 and win_amd64 only (ROCm Linux only), plus a pure-Python `py3-none-any` wheel and sdist.

```bash
pip install torch --index-url https://download.pytorch.org/whl/cu128   # match your CUDA
pip install <wheel-url-from-releases>
```

PyPI: `pip install exllamav3` builds the extension and needs a CUDA toolkit, gcc and Python headers (VS Build Tools on Windows).

Source with uv (flavor extras `cu124 cu126 cu128 cu129 cu130 cu132`):

```bash
git clone https://github.com/turboderp-org/exllamav3 && cd exllamav3
uv venv && uv sync --extra cu130        # extras: --extra examples --extra eval
# or with your own torch:
uv pip install torch --torch-backend=auto && uv pip install --no-build-isolation .
```

`uv sync` and `pip install .` build in an isolation where torch is invisible, so the extension JIT-compiles at first import (minutes, once per torch version). `--no-build-isolation` in an env that already has torch precompiles. Build env vars: `MAX_JOBS` (ninja parallelism; use ~4 if you run out of RAM), `EXLLAMA_NOCOMPILE` (skip compile at install, torch builds at runtime), `EXLLAMA_EXT_LINEINFO`, `EXLLAMA_EXT_COMPRESS`. Checkout `dev` branch for in-progress features (less stable).

## ROCm (AMD)

TabbyAPI uses AMD's pip-native ROCm 10 packages, so only the `amdgpu` kernel driver is needed. Find the gfx target: `grep gfx_target_version /sys/class/kfd/kfd/topology/nodes/*/properties` (110000 to 110002 = gfx1100/1101/1102, 120000/120001 = gfx1200/1201, 100300 to 100302 = gfx1030 to 1032, 110500/110501 = gfx1150/1151). `start.sh` detects `/dev/kfd` and accepts `--gpu-lib rocm --rocm-targets gfx1100`. Manual:

```bash
pip install -U .[rocm] \
  --extra-index-url https://stable.repo.amd.com/rocm/pytorch/whl-next/ \
  --extra-index-url https://stable.repo.amd.com/rocm/core/whl-next/ \
  amd-torch-device-gfx1100
```

Never run a plain `pip install torch` afterwards: it replaces the ROCm torch with a CPU build (TabbyAPI warns at startup). `TABBY_ROCM_INDEX_URLS` overrides the indexes. Docker: compose profile `rocm` needs `/dev/kfd`, `/dev/dri` and the `video` and `render` groups.

## Windows

Python from python.org (not the Microsoft Store), `start.bat`. If a dependency tries to build a wheel, install VS Build Tools 17.8. If torch cannot load CUDA (DLL load failed), install the CUDA toolkit. Docker on Windows needs the CUDA Toolkit on WSL.

## DGX Spark and other aarch64 (GB10, sm_120/sm_121)

Upstream publishes no aarch64 wheels, and the TabbyAPI images listed linux/amd64 only on 2026-10-11 (re-check). Options:

1. Build TabbyAPI's `docker/Dockerfile.cu13` on the Spark, then replace the exllamav3 wheel with a source build of exllamav3 inside the image. Note the Dockerfile installs x86_64-only pinned wheels through `.[cu13]`, so expect to adapt it (unverified on aarch64).
2. Use the **MiaAI-Lab/exllamav3** fork (MIT, last push 2026-08-31 when checked). It states it builds and runs from source on DGX Spark (GB10, aarch64) and adds MTP and DFlash2/DSpark drafting, NVFP4/FP8 KV cache, `tools/serve_openai.py` (OpenAI server: `/v1/models`, `/health`, `/v1/chat/completions`), `start.sh`/`stop.sh` (venv, GPU torch, engine build, weights download) and `quantize.sh`. Its deployment kit for Qwen3.8-27B is `MiaAI-Lab/Qwen3.8-27B-DFlash2-EXL3-5.0bpw`. `serve_openai.py` flags (from source): `-m/--model`, `-dm/--draft_model`, `-cs/--cache_size` (default 65536), `-cq/--cache_quant`, `-p/--port`, `--host` (default `0.0.0.0`), `-ccs/--cpu_cache_size`, `--max_body_mb`. It has no authentication: always pass `--host 127.0.0.1`.

Build only with serving stopped and in a memory-capped scope (`systemd-run --scope -p MemoryMax=...`), because unified memory is shared with the GPU. For the Spark host itself use `nvidia-dgx-spark`.

## Verify

```bash
python -c "import exllamav3, torch; print(exllamav3.__version__, torch.cuda.is_available())"
curl -s http://127.0.0.1:5000/health
```
