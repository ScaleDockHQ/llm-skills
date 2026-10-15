---
name: amd-strix-halo
description: Set up, size and operate AMD Ryzen AI Max (Strix Halo, gfx1151, Radeon 8060S, up to 128 GB unified memory) for local LLM inference on Linux or Windows. Use for GTT/TTM unified-memory limits (ttm.pages_limit, amdgpu.gttsize, amd-ttm), BIOS UMA carveout, Vulkan RADV vs ROCm choice, amdrocm10.1-gfx1151, kyuz0 strix-halo-toolboxes, Lemonade, mmap load stalls, IOMMU trade-offs, tuned profiles, or which engine runs on gfx1151. Not for Instinct servers (use amd-instinct) or NVIDIA DGX Spark.
license: MIT
compatibility: Ryzen AI Max / Max+ systems (Framework Desktop, mini PCs, laptops) on Ubuntu, Fedora, Debian or Windows 11; bash, docker or podman, curl and jq. Kernel arguments, BIOS changes, IOMMU changes, package installs and tuned profiles need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# AMD Strix Halo

Get a Ryzen AI Max machine from first boot to a stable local inference host: the right kernel and firmware, a GPU memory pool big enough for the model, a backend that works (Vulkan or ROCm), and a container or app to serve it.

**Scope:** the platform. llama.cpp flags and build details belong to `llama-cpp` (`references/combos/strix-halo-vulkan.md`); vLLM to `vllm`; sizing across machines to `choosing-hardware`; model swapping to `llama-swap`; the gateway and exposure stack to `self-hosted-llms`. The author did not run these steps on Strix Halo hardware; each reference states the sources and date.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
grep -E '^(NAME|VERSION)=' /etc/os-release; uname -r; cat /proc/cmdline
lscpu | grep 'Model name'; free -h; swapon --show
lspci -nn | grep -i -E 'vga|display|accel'                           # Radeon 8060S / 8050S, XDNA NPU
for f in mem_info_vram_total mem_info_gtt_total mem_info_gtt_used; do                # bytes
  echo "$f $(cat /sys/class/drm/card*/device/$f 2>/dev/null | tr '\n' ' ')"; done
ls /sys/class/drm/card*/device/uma 2>/dev/null                       # BIOS UMA carveout, if exposed
dmesg | grep -i amdgpu | grep -i -E 'gtt|vram|error|firmware' | tail
cat /etc/modprobe.d/*amd* /etc/modprobe.d/*ttm* 2>/dev/null          # existing TTM overrides
command -v rocminfo && rocminfo | grep -E 'Name:\s+gfx' | sort -u   # expect gfx1151
command -v vulkaninfo && vulkaninfo --summary | grep -E 'deviceName|driverName'
ls -l /dev/kfd /dev/dri/renderD* 2>&1; id -nG
tuned-adm active 2>/dev/null; docker --version 2>/dev/null; podman --version 2>/dev/null
```

## Decision flow

1. Confirm the chip: `gfx1151` is Strix Halo (Ryzen AI Max 300 series, RDNA 3.5) and Gorgon Halo (400 series). Compare OS, kernel and linux-firmware with `references/hardware-and-os.md`.
2. Give the GPU the memory: BIOS carveout small, GTT/TTM large (`references/memory.md`). Check `mem_info_gtt_total` before anything else; a model that needs more than the pool will not load.
3. Pick a backend and runtime: Vulkan (RADV) is the most compatible; ROCm needs `amdrocm10.1-gfx1151` or a ROCm container (`references/backends-and-engines.md`).
4. Pick a runtime path: toolbox containers, Lemonade, or a llama.cpp release; then use the product skill for flags.
5. Large model hangs on load, or speeds are poor: `references/performance-and-power.md`, then `references/troubleshooting.md`.
6. Updates: `references/updating.md`.

## Rules

- **Ask before changing the system.** Kernel arguments, modprobe files, BIOS settings, IOMMU, package installs and power profiles need approval and an undo path (keep the old GRUB entry).
- **Unified memory is shared with the OS.** Leave real headroom; setting the pool to all RAM invites a hang when the host needs memory. The community's 124 GB pool on a 128 GB machine is a ceiling, not a target.
- **Disabling the IOMMU is a trade-off.** `amd_iommu=off` can speed memory access but removes DMA protection, breaks the XDNA NPU and VM isolation; do not apply it by default.
- **Large models: avoid mmap.** Use the engine's no-mmap option (`-lm none` in current llama.cpp, `--no-mmap` in older builds).
- **Community sources move fast.** The Strix Halo wiki says its own guidance can go out of date; prefer AMD docs, then the active toolbox project, and mark anything else as unverified.
- **Never print tokens.** Pass `HF_TOKEN` as `-e HF_TOKEN` or from a `0600` env file.
- **Verify upstream.** ROCm, Mesa, kernel and the toolboxes change monthly.

## Workflows

- [ ] Baseline: run Discover; record OS, kernel, firmware, GTT total, backend -> `references/hardware-and-os.md`
- [ ] Memory pool: BIOS carveout, TTM limit, verify `mem_info_gtt_total` -> `references/memory.md`
- [ ] Backend: Vulkan check, optional ROCm install -> `references/backends-and-engines.md`
- [ ] Runtime: toolbox, Lemonade or llama.cpp -> `references/backends-and-engines.md`
- [ ] Tuning: tuned profile, mmap, headless -> `references/performance-and-power.md`
- [ ] Update path -> `references/updating.md`
- [ ] Verify: GTT total matches the plan, the engine log names the Radeon 8060S (or `gfx1151`), a model near the pool size loads without a hang, and `free -h` keeps headroom while it serves.

## Reference index

- `references/hardware-and-os.md`: chip family, ROCm 10.1.0 support, OS, kernel, firmware, Windows notes.
- `references/memory.md`: GART, GTT, TTM, kernel parameters, `amd-ttm`, IOMMU trade-off, sysfs checks, sizing.
- `references/backends-and-engines.md`: Vulkan vs ROCm, ROCm install, toolboxes, Lemonade, vLLM, ComfyUI.
- `references/performance-and-power.md`: tuned profile, headless mode, mmap, bandwidth ceiling.
- `references/updating.md`: ROCm, kernel, firmware and image updates.
- `references/troubleshooting.md`: symptom to fix.

## Companion skills

- `llama-cpp`: flags, builds and the Strix Halo Vulkan recipe. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `vllm`: vLLM on ROCm. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `choosing-hardware`: compare with DGX Spark, Macs and discrete GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `llama-swap`: model swapping. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `self-hosted-llms`: gateway, exposure and catalog on top. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
