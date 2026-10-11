# Installing Unsloth

> Verified against unslothai/unsloth library 2026.10.3 (PyPI) and Studio/Desktop v0.1.905-beta (GitHub), README.md and unsloth.ai/docs install pages, 2026-10-11

## What gets installed

| Product         | What it is                                                                                       | Install                                                            |
| --------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| Unsloth Core    | Python library (`pip install unsloth`, date-versioned, PyPI 2026.10.3, Python >= 3.9 and < 3.15) | uv or pip, below                                                   |
| Unsloth Studio  | Web UI to run, train and export models (`unsloth studio`)                                        | `curl -fsSL https://unsloth.ai/install.sh \| sh`, Homebrew, Docker |
| Unsloth Desktop | Native desktop app                                                                               | OS downloads from GitHub Releases                                  |

Licensing (README): the core package is Apache-2.0; optional components such as the Studio UI are AGPL-3.0. Project is very actively maintained (pushed 2026-10-11, near-daily Studio releases).

## Core (code-based), Linux or WSL

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv unsloth_env --python 3.13
source unsloth_env/bin/activate
uv pip install unsloth --torch-backend=auto
python -c 'import unsloth'
```

Windows: install `torchao` first, then Unsloth, in a uv venv (`uv pip install torchao`, then `uv pip install unsloth --torch-backend=auto`); a one-step install silently resolves an old Unsloth because `--torch-backend` finds torchao only on the PyTorch index.

Unsloth pins a TRL range (`trl>=0.18.2,!=0.19.0,<=1.15.0` in `pyproject.toml` on main). Let the Unsloth install choose `transformers` and `trl`; do not upgrade them independently.

## Studio and Desktop

macOS, Linux, WSL:

```bash
curl -fsSL https://unsloth.ai/install.sh | sh        # same command updates
unsloth studio -H 127.0.0.1 -p 8888
```

`curl | sh` runs a remote script; read it first or use the Homebrew cask (`brew install --cask unsloth`) if the user prefers. Windows uses `irm https://unsloth.ai/install.ps1 | iex`. Desktop installers per OS (Windows `.exe`, macOS `.dmg`, Linux x64 `.deb`, Linux ARM64 `.deb` for Ubuntu 24.04+, Linux x64 AppImage) are listed at https://github.com/unslothai/unsloth/releases. Installer variables from the README: `UNSLOTH_NO_TORCH=1` (GGUF-only, skips PyTorch), `UNSLOTH_SKIP_AUTOSTART=1`, `UNSLOTH_STUDIO_HOME=<abs path>`, `UNSLOTH_PYTHON=3.12`, `UNSLOTH_LLAMA_CPP_BACKEND=vulkan|cpu|cuda|rocm|auto`. Uninstall: the `scripts/uninstall.sh` in the repo. More: `references/studio.md`.

## Docker

Image `unsloth/unsloth` (tags checked on Docker Hub 2026-10-11, all `amd64` and `arm64`): `latest`, `studio`, `core` (notebooks only), dated `nightly-YYYY.MM.DD` and `core-nightly-...`, release tags like `v0.1.903-beta`. AMD: `unsloth/unsloth-rocm`.

```bash
docker run -d --name unsloth --gpus all --ipc=host \
  -p 127.0.0.1:8000:8000 -p 127.0.0.1:8888:8888 \
  -v "$PWD":/workspace/host \
  -v "$HOME/.cache/huggingface":/workspace/.cache/huggingface \
  -v unsloth-studio:/opt/unsloth-studio \
  unsloth/unsloth && docker logs -f unsloth
```

The upstream example publishes `-p 8000:8000 -p 8888:8888` on all interfaces; the loopback form above is the safer default. For a public Cloudflare HTTPS link upstream uses `-e UNSLOTH_STUDIO_SECURE=1` instead (see exposure rules in `references/studio.md`). NVIDIA toolkit setup helper: `docker/install_nvidia_toolkit.sh` in the repo (runs with sudo; read it first). Guide: https://unsloth.ai/docs/get-started/install/docker.

## DGX Spark (GB10, arm64)

Upstream's guide builds a dedicated image from `Dockerfile_DGX_Spark` in `unslothai/notebooks`:

```bash
wget -O Dockerfile "https://raw.githubusercontent.com/unslothai/notebooks/main/Dockerfile_DGX_Spark"
docker build -f Dockerfile -t unsloth-dgx-spark .
docker run -it --gpus=all --net=host --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  -v $(pwd):$(pwd) -v $HOME/.cache/huggingface:/root/.cache/huggingface -w $(pwd) unsloth-dgx-spark
```

On 2026-10-11 the Dockerfile is `FROM nvcr.io/nvidia/pytorch:25.11-py3`, sets `TORCH_CUDA_ARCH_LIST="12.1"`, builds from source, and pins `bitsandbytes==0.48.0 transformers==4.56.2 trl==0.22.2` (older than current TRL). Expect a long build; run it memory-capped (skill `fine-tuning-llms` covers unified-memory caps). Inside the container all Unsloth notebooks work with the install cells removed (upstream). Whether the plain multi-arch `unsloth/unsloth` image or `uv pip install unsloth` works on Spark without that Dockerfile is **unverified**; test with a tiny model first.

## Blackwell, AMD, Intel

README points to: Blackwell RTX 50 guide https://unsloth.ai/docs/blog/fine-tuning-llms-with-blackwell-rtx-50-series-and-unsloth, AMD guide https://unsloth.ai/docs/basics/amd, Intel guide https://unsloth.ai/docs/get-started/install/intel. Not summarized here.

## Verify

```bash
python -c 'import unsloth; print("ok")'
pip show unsloth | head -3
unsloth --help | head
```
