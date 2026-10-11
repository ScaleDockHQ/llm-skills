# KoboldCpp install

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

KoboldCpp ships as one prebuilt executable per platform. No installer, no Python needed. Models are separate.

## Choose the file

Release assets (v1.122.1): `koboldcpp.exe`, `koboldcpp-nocuda.exe`, `koboldcpp-oldpc.exe`,
`koboldcpp-linux-x64`, `koboldcpp-linux-x64-nocuda`, `koboldcpp-linux-x64-oldpc`, `koboldcpp-mac-arm64`.

| Platform               | File                   | Notes                                                                      |
| ---------------------- | ---------------------- | -------------------------------------------------------------------------- |
| Windows, NVIDIA        | `koboldcpp.exe`        | Includes CUDA. Also does Vulkan and CPU.                                   |
| Windows, AMD/Intel/CPU | `koboldcpp-nocuda.exe` | Smaller; CPU and Vulkan.                                                   |
| Old CPU or GPU         | `*-oldpc`              | Try when the default crashes at start; `--noavx2` is the flag alternative. |
| Linux x86-64           | `koboldcpp-linux-x64`  | `-nocuda` if no CUDA needed.                                               |
| Apple Silicon          | `koboldcpp-mac-arm64`  | Intel Macs need a source build.                                            |

Only download from https://github.com/LostRuins/koboldcpp/releases. The README warns `koboldcpp.com` is a
malicious fake; the official community site is koboldcpp.net.

## Linux and macOS

```bash
# Pin the tag instead of "latest" for reproducible installs (list tags: gh release list -R LostRuins/koboldcpp)
curl -fLo koboldcpp-linux-x64 https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64
chmod +x koboldcpp-linux-x64
./koboldcpp-linux-x64 --version
./koboldcpp-linux-x64 --model /path/to/model.gguf          # add --usecuda or --usevulkan
```

macOS may block the binary: allow it in System Settings > Privacy & Security (Apple's instructions are
linked from the README). Without a display, pass `--model` and `--skiplauncher` so the Tk GUI launcher is
not needed.

## Windows

Double-click `koboldcpp.exe` for the launcher, or from a terminal: `koboldcpp.exe --model "C:\Models\model.gguf"`.

## From source

Needs Git, Python 3, a C/C++ toolchain and the backend SDK. `LLAMA_PORTABLE=1` avoids tuning for the build machine.

| Backend     | Command                | Needs                    |
| ----------- | ---------------------- | ------------------------ |
| CPU         | `make`                 | toolchain                |
| Vulkan      | `make LLAMA_VULKAN=1`  | Vulkan SDK               |
| NVIDIA CUDA | `make LLAMA_CUBLAS=1`  | CUDA Toolkit             |
| AMD ROCm    | `make LLAMA_HIPBLAS=1` | ROCm dev libraries       |
| macOS Metal | `make LLAMA_METAL=1`   | Xcode command-line tools |

Then `python3 koboldcpp.py --model /path/model.gguf`. Linux also has `./koboldcpp.sh` (micromamba based:
`rebuild`, `dist`). Windows CUDA builds use Visual Studio and CMake (see the README). Python extras:
`pip install -r requirements.txt`.

## Android (Termux)

Install Termux from F-Droid, then `pkg install openssl wget git python clang make`, clone, `make`, run
`python koboldcpp.py --model ...`. CPU only; the installer script is `android_install.sh` in the repo (review
before piping to a shell).

## Docker

`koboldai/koboldcpp` on Docker Hub is documented as experts only, mainly for cloud GPU rentals: x86-64
Ubuntu inside, expects an NVIDIA or AMD GPU, may perform poorly on Windows/macOS Docker and fail on ARM. The
Hub currently lists a `latest` tag only. For local use prefer the binaries. See `templates/docker-compose.yml`.

## Cloud and hosted

Official Colab notebook, a RunPod image (https://koboldai.org/runpodcpp) and a Hugging Face demo Space are
linked from the README. Colab and rented GPUs have their own terms and prices; check them at use time.

## Verify

```bash
./koboldcpp-linux-x64 --version
./koboldcpp-linux-x64 --help | head -40
./koboldcpp-linux-x64 --analyze /path/model.gguf | head -30   # metadata and tensor types
```

Other people's builds (AUR, Nix, community Docker, the ROCm fork) are unofficial; check their maintenance.
License: AGPL v3 for KoboldCpp and KoboldAI Lite; bundled GGML, llama.cpp and stable-diffusion.cpp are MIT.
