# Linux desktops and laptops

> Verified against Ollama v0.40.3 Linux/GPU docs, llama.cpp b11555 release assets, LM Studio 0.4.26 docs, 2026-10-11

This page covers a Linux machine you sit at. For headless servers, multi-GPU boxes, and DGX Spark, use the **self-hosted-llms** skill.

## What it is and when to choose it

Linux has the widest backend choice: CUDA (NVIDIA), ROCm/HIP (AMD), Vulkan (AMD, Intel, NVIDIA), SYCL (Intel), and CPU. On a supported card, the native vendor stack (CUDA, or ROCm on a supported AMD card) is usually fastest. Vulkan is the portable fallback and often competitive on AMD.

## Discover (read-only)

```bash
uname -m; cat /etc/os-release | head -4
free -h                                              # RAM
lspci | grep -i -E 'vga|3d|display'                  # GPUs present
nvidia-smi --query-gpu=name,memory.total,memory.used,driver_version --format=csv
rocm-smi --showproductname --showmeminfo vram        # AMD ROCm (or: amd-smi static)
vulkaninfo --summary                                 # Vulkan devices (vulkan-tools package)
groups                                               # need 'render' (and often 'video') for AMD/Intel GPUs
ss -ltnp | grep -E ':(11434|1234|9931|8080)\b'       # what is already listening
command -v ollama lms llama-server mlx_lm.server
systemctl status ollama --no-pager 2>/dev/null; systemctl --user list-units --type=service | grep -i -E 'llama|lms|ollama'
```

## Install

**Drivers first**

- NVIDIA: use the distro's packaged proprietary driver (for example `ubuntu-drivers`). Ollama needs driver 550+ (570+ for compute capability 5.0–6.2). Check with `nvidia-smi`.
- AMD ROCm: install with AMD's `amdgpu-install` tool. Ollama requires ROCm v7 on Linux and lists the supported RX/PRO/Ryzen AI parts in its GPU docs. Unsupported RDNA cards can sometimes use `HSA_OVERRIDE_GFX_VERSION=x.y.z`; use this at your own risk.
- Vulkan: Mesa (RADV for AMD, ANV for Intel) and `vulkan-tools`.
- Add yourself to the GPU groups if needed: `sudo usermod -aG render,video "$USER"`, then log out and back in.

**Runtimes**

- Ollama: `curl -fsSL https://ollama.com/install.sh | sh`. This installs a system service `ollama.service` that runs as user `ollama`, with models in `/usr/share/ollama/.ollama/models`.
- llama.cpp: `brew install llama.cpp`, or a release tarball: `ubuntu-x64` (CPU), `ubuntu-vulkan-x64`, `ubuntu-cuda-<ver>-x64` (plus the `cudart-` tarball), `ubuntu-rocm-<ver>-x64`, or `ubuntu-sycl-*`. Building from source with `-DGGML_CUDA=ON` / `-DGGML_HIP=ON` / `-DGGML_VULKAN=ON` gives the best fit for your exact card.
- LM Studio: the AppImage (GUI), or headless llmster with `curl -fsSL https://lmstudio.ai/install.sh | bash`.

## Minimal working config

```bash
llama-server -hf ggml-org/<model>-GGUF:Q4_K_M -c 16384 --host 127.0.0.1 --port 9931
curl -s http://127.0.0.1:9931/health
```

## systemd user services

Run your own servers as **user** services, not system services. A user service runs with your permissions, stays out of `/etc`, and stops when you log out unless lingering is enabled.

```bash
mkdir -p ~/.config/systemd/user
cp assets/llama-server.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now llama-server
journalctl --user -u llama-server -f
loginctl enable-linger "$USER"    # optional: keep it running when logged out (ask first)
```

Ollama's installer creates a **system** service. Configure it with `sudo systemctl edit ollama` and lines such as `Environment="OLLAMA_CONTEXT_LENGTH=32768"` under `[Service]`, then `sudo systemctl daemon-reload && sudo systemctl restart ollama`.

## How it plugs in

Ollama `127.0.0.1:11434`, LM Studio `127.0.0.1:1234`, llama-server `127.0.0.1:9931`. Desktop firewalls (ufw, firewalld) usually block inbound traffic by default. Keep it that way unless you follow `sharing-on-lan.md`.

## Operating

- Ollama logs: `journalctl -u ollama --no-pager --follow --pager-end`. Update: re-run the install script. Pin a version with `curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=<ver> sh`.
- Changing `OLLAMA_MODELS` for the system service: the `ollama` user needs access (`sudo chown -R ollama:ollama <dir>`).
- After suspend/resume, NVIDIA UVM sometimes breaks GPU detection. Ollama's docs suggest reloading the module: `sudo rmmod nvidia_uvm && sudo modprobe nvidia_uvm`.

## Tuning knobs worth knowing

- `CUDA_VISIBLE_DEVICES`, `ROCR_VISIBLE_DEVICES`, `GGML_VK_VISIBLE_DEVICES` select GPUs. `OLLAMA_VULKAN=0` disables Ollama's Vulkan backend.
- `llama-server --list-devices` shows which backends and devices the binary sees. `-dev` picks among them.
- Laptops with NVIDIA Optimus: check that `nvidia-smi` shows the process while it's generating.

## Known pitfalls

- A CPU-only llama.cpp tarball on a GPU machine runs, but slowly. Check `--list-devices`.
- Missing `render` group membership gives "permission denied" on `/dev/kfd` or `/dev/dri/renderD*`.
- Running Ollama both as the system service and as `ollama serve` in a terminal gives "address already in use" on 11434.
- Secure Boot can block unsigned NVIDIA kernel modules. Enroll the MOK key the installer offers.

## Official links

- Ollama Linux: https://docs.ollama.com/linux
- Ollama GPU support: https://docs.ollama.com/gpu
- llama.cpp build guide: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- ROCm install: https://rocm.docs.amd.com/projects/install-on-linux/en/latest/
- LM Studio headless (llmster): https://lmstudio.ai/docs/developer/core/headless
