# Backends, containers and engines

> Verified against ROCm 10.1.0 install guide, kyuz0/amd-strix-halo-toolboxes README and strix-halo-toolboxes.com, Lemonade v2026.41.1 release notes, vLLM install docs, Strix Halo Wiki AI overview (2025-08), 2026-10-11

## Vulkan or ROCm

- **Vulkan (Mesa RADV)** is the toolbox project's most stable and compatible choice and its recommendation for most users and all models. The Linux driver stack is in Mesa; check it with `vulkaninfo --summary`. The wiki also describes AMDVLK; it was faster at prompt processing in a 2025 test while RADV held up better at long context and token generation. AMDVLK availability may have changed since; test what your distro ships.
- **ROCm** gives the HIP backend and PyTorch. The toolbox project calls its `rocm-10.0` image the latest stable ROCm Core SDK build with AMD's supported gfx1151 package set. The wiki said ROCm support was immature in August 2025, so check current notes before relying on it for training or image generation.
- Decide per model and context length with `llama-bench`; see the `llama-cpp` skill.

## Install ROCm on the host (optional)

Needed only for host-side ROCm development, the HIP backend outside a container, or PyTorch. Containers carry their own.

```bash
# Ubuntu 26.04.1 or 24.04.5 (inbox amdgpu driver); add AMD's apt source from the install page first
sudo apt install amdrocm10.1-gfx1151
sudo usermod -a -G render,video "$LOGNAME"       # log out and in
rocminfo | grep -E 'Name:\s+gfx' | sort -u       # gfx1151
```

The apt source block, keys and the other distro variants are in the AMD install page; the `amd-instinct` skill shows the Ubuntu 26.04 block. Python wheels: `python -m pip install --index-url https://stable.repo.amd.com/rocm/whl-next/ "rocm[libraries,device-gfx1151]==10.1.0"` (the command AMD's install page gives for `gfx1151`).

## Toolbox containers

`kyuz0/amd-strix-halo-toolboxes` (Docker Hub `kyuz0/amd-strix-halo-toolboxes`) provides llama.cpp images rebuilt when llama.cpp master changes.

| Tag                          | Stack                       | Use               |
| ---------------------------- | --------------------------- | ----------------- |
| `vulkan-radv`                | Vulkan, Mesa RADV           | Stable default    |
| `rocm-10.0`                  | ROCm 10.0 on Fedora 44      | Stable ROCm build |
| `therock-nightly` and others | Experimental, custom builds | Only for testing  |

Do not use the deprecated `-mtp` tags; MTP support is merged into llama.cpp master and in the standard toolboxes. Legacy ROCm 6.4 and 7.1 images are excluded.

Preferred workflow from the project: AI Toolbox Cockpit (`pipx install git+https://github.com/kyuz0/ai-toolbox-cockpit.git`, then `ai-toolbox-cockpit`). Read the repository before running code you install from it. Manual container commands (Fedora, Toolbx):

```bash
toolbox create llama-vulkan-radv --image docker.io/kyuz0/amd-strix-halo-toolboxes:vulkan-radv \
  -- --device /dev/dri --group-add video --security-opt seccomp=unconfined
toolbox create llama-rocm-10.0 --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-10.0 \
  -- --device /dev/dri --device /dev/kfd --group-add video --group-add render --group-add sudo --security-opt seccomp=unconfined
toolbox enter llama-rocm-10.0 && llama-cli --list-devices
```

On Ubuntu and Debian use Distrobox instead (same image and flags, plus `usermod -aG video,render` and a udev rule that sets `MODE="0666"` for `kfd` and `renderD*`; that rule opens the GPU to every local user, so prefer groups on shared machines).

The README recommends flash attention and no mmap for stable results:

```bash
llama-server -m model.gguf -c 8192 -ngl 999 -fa 1 --no-mmap      # toolbox README form
```

Current llama.cpp spells mmap control `-lm none` (`--load-mode`), and Lemonade replaced `--no-mmap` with `--load-mode none` in v2026.41.1; check `llama-server --help` for your build.

The README documents a temporary workaround in the ROCm images for llama.cpp issue 25992 (ROCm host buffers selected for compute on integrated GPUs); it is meant to disappear once llama.cpp fixes it upstream. The images also include RDMA support for llama.cpp RPC when a RoCEv2 NIC is present (add `--device /dev/infiniband --group-add rdma --ulimit memlock=-1` on Toolbx).

Other toolboxes from the same project cover ComfyUI (image and video), vLLM (with RCCL patches for clustering) and fine-tuning; see `strix-halo-toolboxes.com` for current names and tags.

## Lemonade

Lemonade (`lemonade-sdk/lemonade`, latest v2026.41.1, 2026-10-07) is an AMD-sponsored local server that bundles llama.cpp, whisper.cpp and other backends. The wiki recommends it for newcomers. Packages: Windows MSI, Ubuntu 24.04 and newer PPA, Debian 13 `.deb`, Fedora 43 and 44 RPMs, macOS pkg. Release v2026.41.1 moved all ROCm backends to ROCm 10 (the first ROCm model load after the upgrade downloads about 2.6 GB), and `lemonade config set` now rejects unknown backend keys.

## vLLM

The vLLM docs list Ryzen AI MAX and AI 300 (`gfx1151` and `gfx1150`) as supported on ROCm 7.0.2 or newer, with Python 3.12 wheels or the `vllm/vllm-openai-rocm` image. Use the `vllm` skill for flags. Unified memory changes the memory arithmetic: `--gpu-memory-utilization` is a share of what the engine thinks the device has, so confirm what it reports against `mem_info_gtt_total` before raising it.

## Ollama

The wiki (2025-08) said Ollama does not support Vulkan or AMD GPUs well and did not recommend it. That is old; check the current Ollama release notes and the `ollama` skill before choosing it.

## Image and video generation

The toolbox project documents ComfyUI containers for this chip (LTX2, Wan 2.2, HunyuanVideo, Qwen validated per its site). The `comfyui` skill covers ComfyUI itself.
