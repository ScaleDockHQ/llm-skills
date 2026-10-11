# InvokeAI: install

> Verified against InvokeAI v6.14.2 (docs start-here installation, manual and system-requirements at tag v6.14.2, pyproject.toml, GitHub release and ghcr.io manifests), 2026-10-11

Upstream: [invoke-ai/InvokeAI](https://github.com/invoke-ai/InvokeAI) (Apache-2.0, not archived, last push 2026-10-11). Stable is **v6.14.2** (2026-09-27); `v7.0.0-alpha.1/2` are pre-releases. PyPI `InvokeAI` 6.14.2 requires Python `>=3.11,<3.13`.

## Hardware (docs at v6.14.2)

Windows 10+, macOS 14+, Linux (Ubuntu 20.04+ well tested). Apple silicon works, 16 GB or more recommended. AMD GPUs are supported on Linux only at this version; Intel Arc on Windows and Linux x86_64; Linux ARM64 is CPU-only (API-backed models still work). Docs' minimums: SD1.5 4 GB VRAM and 8 GB RAM; SDXL 8 GB and 16 GB; FLUX.1 10 GB and 32 GB; Z-Image Turbo 8 GB and 16 GB (Q4_K); Wan 2.2 TI2V-5B 8 GB and 16 GB. Less VRAM usually works, slower (`memory-and-performance.md`). If your temp directory is a tmpfs on Linux, make sure it has space.

## Pick a path

| Path                                                     | Use when                                                                                                                                 |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Invoke Launcher (Windows EXE, macOS DMG, Linux AppImage) | a person wants the UI; it installs Python, picks the GPU build and updates Invoke. Download from github.com/invoke-ai/launcher/releases. |
| Manual `uv` install                                      | headless Linux servers and scripts; upstream no longer maintains headless install scripts, only this walkthrough                         |
| Docker                                                   | NVIDIA or ROCm Linux hosts or Windows with Docker Desktop GPU support; no GPU on macOS containers                                        |
| Stability Matrix or LynxHub                              | third-party launchers; not managed by Invoke                                                                                             |

## Manual install (Linux, NVIDIA)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh                      # review the script first; or use your package manager
mkdir -p ~/invokeai && cd ~/invokeai
uv venv --relocatable --prompt invoke --python 3.12 --python-preference only-managed .venv
source .venv/bin/activate
uv pip install "invokeai==6.14.2" --python 3.12 --python-preference only-managed --torch-backend=cu128 --force-reinstall
deactivate && source .venv/bin/activate
invokeai-web --root ~/invokeai                                       # serves http://127.0.0.1:9090
```

- Package specifier: `invokeai[xformers]` for NVIDIA 16xx or 20xx; plain `invokeai` for 30xx and newer or non-NVIDIA.
- Torch backend (v6.14.2 docs): NVIDIA `--torch-backend=cu128`; Intel Arc `xpu`; Linux AMD `rocm7.1` (with `"torch<2.12"` pinned, since torch 2.12 on rocm7.1 was reported to break generation); CPU on x86_64 `cpu`; on ARM64 or macOS use no backend (the default wheels are CPU-only on ARM64). Pick a backend only when it applies.
- The `invokeai-web` command also installs `invoke-useradd` and `invoke-userdel` helpers (`configuration.md`).
- On Debian-like Linux OpenCV needs `libglib2.0-0` and `libgl1-mesa-glx`. On macOS install the Xcode CLI tools; if model installs fail with a certificate error run the Python `Install Certificates.command`.

## Docker

```bash
docker run --runtime=nvidia --gpus=all --publish 127.0.0.1:9090:9090 \
  -v ~/invokeai:/invokeai -e INVOKEAI_ROOT=/invokeai ghcr.io/invoke-ai/invokeai:6.14.2-cuda
```

- Upstream's one-liner uses the untagged image, which resolves to `latest`: built from `main` (CUDA), i.e. development code. Tags from the build workflow: `<version>-cuda`, `-cpu`, `-rocm` (for example `v6.14.2-cuda`, `6.14.2-cuda` and `6.14-cuda` all resolved on 2026-10-11), plus `main-<driver>` and `sha-<short>-<driver>`. Images are **linux/amd64 only** (the workflow notes arm64 would not be GPU-accelerated), so DGX Spark and other arm64 hosts need a manual install.
- The CUDA image needs a host NVIDIA driver and a GPU supported by that release (check the release notes; main moved to driver R580 or newer and compute capability 7.5 or newer).
- Publish the port on `127.0.0.1` unless a gateway fronts it. Mount the root (`INVOKEAI_ROOT`, default `~/invokeai`, models, outputs and the SQLite database live there) and optionally `HF_HOME`.
- Compose, from the repo: `cd docker && cp .env.sample .env && docker compose up` (profiles `cpu` and `rocm`; `GPU_DRIVER`, `INVOKEAI_PORT`, `RENDER_GROUP_ID` for ROCm, `CONTAINER_UID`). Set `HUGGING_FACE_HUB_TOKEN` in `.env` only from a file with `0600` permissions.
- WSL2: a CRLF `docker-entrypoint.sh` causes a "no such file or directory" error; convert to LF.
- `INVOKEAI_DB_URL` points the image at MySQL or MariaDB instead of SQLite.

## Python and drivers

Python 3.11 or 3.12 for v6.14.2 (3.12 recommended; `main` requires 3.12). NVIDIA: `nvidia-smi` must work. Linux ARM64 CPU-only. Check GPU use in the startup log: Invoke logs what it generates on; if the GPU is not used, reinstall with the right backend.
