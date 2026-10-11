# ComfyUI: install

> Verified against ComfyUI v0.39.0, comfy-cli v1.22.0 and the PyTorch cu130 wheel index (docs: github.com/Comfy-Org/ComfyUI README, docs.comfy.org installation/manual_install, comfy-cli README), 2026-10-11

Upstream: [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) (GPL-3.0, not archived, last push 2026-10-11). `comfyanonymous/ComfyUI` redirects there. Releases come roughly weekly (v0.39.0 on 2026-10-05).

## Pick an install path

| Path                        | Use when                                                          | Notes                                                                                                                                                                           |
| --------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Desktop app                 | one user on Windows or macOS who wants the UI                     | README: Windows and macOS; the docs also list Linux AppImage and `.deb`. Not for headless serving.                                                                              |
| Windows portable (`.7z`)    | Windows, no Python setup                                          | README ships nvidia (Python 3.13, torch cuda 13.0), amd, intel and an `nvidia_cu126` build for 10-series and older GPUs. README says it is "not recommended for regular users". |
| `comfy-cli`                 | scripted or repeatable installs, node and model management        | `pip install comfy-cli`, then `comfy install`. Requires Python 3.10+ (PyPI metadata).                                                                                           |
| Manual (git clone and venv) | servers, containers you build yourself, DGX Spark and other arm64 | Full control of the torch build. The default for this skill.                                                                                                                    |

## Manual install, Linux with NVIDIA

```bash
git clone https://github.com/Comfy-Org/ComfyUI ~/ComfyUI && cd ~/ComfyUI
python3 -m venv .venv && . .venv/bin/activate
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
pip install -r requirements.txt
python main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch
```

- README requirements: Python 3.13 is "very well supported" (try 3.12 if a custom node dependency fails on 3.13). Python 3.14 works but some custom nodes may break. torch 2.7 is the minimum, "using a newer version is extremely recommended", and a **cu130 or newer** torch is required on NVIDIA 20-series and above.
- README: update PyTorch when it is more than six months old; the latest major torch with the latest CUDA is the default advice unless it is under two weeks old.
- "Torch not compiled with CUDA enabled": `pip uninstall torch`, then reinstall with the cu130 command above (README troubleshooting).
- `requirements.txt` at v0.39.0 pins `comfyui-frontend-package==1.53.10`, `comfyui-workflow-templates==0.11.76` and `comfyui-embedded-docs==0.5.13`; the frontend is a separate package, so an old frontend with a new core is a version-skew cause of odd UI errors.

## DGX Spark and other arm64 Linux

ComfyUI's docs have no Spark-specific page. On 2026-10-11 the cu130 index listed `torch-2.14.1+cu130` wheels tagged `manylinux_2_28_aarch64` for cp312 and cp313, so the manual steps above work. Confirm the GPU is visible:

```bash
python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))'
```

Container images from the community may be amd64-only (see Containers). Unified memory means ComfyUI and an LLM compete for the same pool; read `performance-memory.md` before running both. See the `nvidia-dgx-spark` skill for the platform.

## Other GPUs (from the README)

| GPU                    | torch install                                                                                                                                                                         |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AMD, Linux             | `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2`                                                                                       |
| AMD, Windows           | AMD multi-architecture packages from `https://stable.repo.amd.com/rocm/whl-next/` (README gives the exact `torch[device-all]==2.13.0+rocm10.0.0` line; needs Windows 11, Python 3.13) |
| Intel Arc              | `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu`                                                                                           |
| Apple silicon          | PyTorch nightly per Apple's guide, then the manual steps; launch with `python main.py`                                                                                                |
| Ascend, Cambricon, ... | vendor toolkit first, then the manual steps (README sections Ascend NPUs, Cambricon MLUs, Iluvatar Corex)                                                                             |
| CPU only               | any torch build; run with `--cpu` (slow)                                                                                                                                              |

AMD cards that ROCm does not officially support: README suggests `HSA_OVERRIDE_GFX_VERSION=10.3.0` for RDNA2 and older (6700, 6600) and `HSA_OVERRIDE_GFX_VERSION=11.0.0` for the 7600 and similar RDNA3.

## comfy-cli

```bash
python3 -m venv ~/venvs/comfy && . ~/venvs/comfy/bin/activate
pip install comfy-cli
comfy install                       # ComfyUI plus ComfyUI-Manager, default workspace <HOME>/comfy
comfy launch -- --listen 127.0.0.1  # arguments after -- go to main.py
```

Verified against the comfy-cli v1.22.0 README (PyPI 1.22.0, GPL-3.0, last push 2026-10-11):

- `comfy install --skip-manager` skips Manager. `--fast-deps` uses `uv`. `--workspace=<path>` chooses the location. `--pr "#1234"` installs a ComfyUI pull request (cannot combine with `--version` or `--commit`).
- `comfy install` reuses an active venv or conda env, then a `.venv` or `venv` inside the workspace. A `pip install comfy-cli` into the global Python installs ComfyUI's dependencies there too (the README calls this the typical Docker setup), so activate a venv first.
- `comfy launch --background` then `comfy stop` run and stop one background instance. `comfy set-default <path> --launch-extras="<args>"` stores default arguments.
- `export COMFY_LOCAL_URL=http://127.0.0.1:8189` points every local-targeting `comfy` command at a server on another address.
- `comfy setup` is the interactive wizard (local or cloud routing, auth, agent skills); `-y` makes it non-interactive. Cloud commands (`--where cloud`, `comfy generate`) spend Comfy Cloud credits. This skill does not use them.
- `comfy which`, `comfy env`, `comfy system-stats` and `comfy free` inspect and release a local server.

comfy-cli is a convenience layer: on a server, prefer the plain `python main.py` command in a service unit so the process and its flags are visible.

## Containers

There is no official ComfyUI image listed in the ComfyUI README. The llama-swap ComfyUI guide uses the community image `yanwk/comfyui-boot:cu130-slim-v2` (Docker Hub, tag updated 2026-10-06, `amd64` only when checked). Review any third-party image's Dockerfile and mounts before running it, and pin by digest for repeatable builds. For arm64, build your own image from the manual steps.

## Verify the install

```bash
python main.py --help | head -5
python main.py --quick-test-for-ci            # loads core and nodes, then exits 0 before serving (main.py)
python main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch &
sleep 20; curl -fsS 127.0.0.1:8188/system_stats | jq -r '.system.comfyui_version, .system.pytorch_version'
```

Stop the test server again (`kill %1`) before starting the real one.
