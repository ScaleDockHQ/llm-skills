# llama.cpp on AMD Strix Halo (Ryzen AI Max+) with Vulkan

> Verified against llama.cpp b11556 and v0.6.0 (docs/build.md, ggml-vulkan.cpp env vars); kernel and driver guidance from third-party sources (Strix Halo Wiki, Lychee-Technology/llama-cpp-for-strix-halo, ROCm issue 5595), 2026-10-11

Strix Halo (Ryzen AI Max, Radeon 8060S, gfx1151) is an APU with up to 128 GB of unified memory. llama.cpp is the runtime that can use most of it. The upstream docs describe the Vulkan and HIP builds generically; the Strix Halo-specific tuning below comes from community sources and is **not upstream-verified**. Benchmark on your own system.

## Which backend

Community benchmarks (Strix Halo Wiki, strix-benchmarks) favour **Vulkan with Mesa RADV** for most models because it maps the whole GTT pool without extra setup; ROCm/HIP works but needs unified-memory handling (`GGML_CUDA_ENABLE_UNIFIED_MEMORY=1`, which upstream documents for HIP APUs) and is sensitive to mmap. RADV versus AMDVLK varies by model: one wiki test found AMDVLK faster at prompt processing on a short test while RADV scaled better at long context. Test both for your model and context length.

## Install

```bash
# Prebuilt Vulkan (Linux x64): release asset llama-bNNNN-bin-ubuntu-vulkan-x64.tar.gz, or Docker:
docker run --rm --device /dev/dri/renderD128:/dev/dri/renderD128 --device /dev/dri/card1:/dev/dri/card1 \
  -p 127.0.0.1:8081:8080 -v /srv/models/gguf:/models:ro \
  ghcr.io/ggml-org/llama.cpp:server-vulkan -m /models/model-Q4_K_M.gguf -ngl all --host 0.0.0.0 --port 8080
# Windows: llama-bNNNN-bin-win-vulkan-x64.zip (or win-rocm-10.0-x64)
# Source: cmake -B build -DGGML_VULKAN=1 && cmake --build build --config Release -j   (see references/install.md for packages)
```

Confirm the GPU in the log: `ggml_vulkan: Using AMD Radeon ...`, and `vulkaninfo --summary`. ROCm route: `-DGGML_HIP=ON -DGPU_TARGETS=gfx1151` (gfx1151 is the Strix Halo target per the community sources; check `rocminfo | grep gfx`).

## Give the GPU the memory (Linux)

By default the kernel limits how much system RAM the GPU can map (reports of about 62 GB visible on a 128 GB machine). Community guidance: set the TTM page limits instead of the deprecated `amdgpu.gttsize`:

```text
# /etc/modprobe.d/increase_amd_memory.conf   (pages are 4 KiB; 25600000 pages is about 100 GB)
options ttm pages_limit=25600000
options ttm page_pool_size=25600000
```

then regenerate the initramfs and reboot (`update-initramfs -u -k all` on Debian/Ubuntu). Equivalent kernel command-line form: `ttm.pages_limit=... ttm.page_pool_size=...`. A conflicting `amdgpu.gttsize=` boot parameter overrides it and prints a deprecation warning; remove it. Other reports (strix-benchmarks) also needed `amd_iommu=off` for models above about 64 GB to load under Vulkan; this is a single-source claim and disabling the IOMMU weakens DMA isolation, so treat it as a last resort. Keep a few GB for the OS; the BIOS "UMA frame buffer" setting can stay small. Verify with `dmesg | grep amdgpu | grep -i gtt`.

Windows note: llama.cpp issue 26089 shows memory enumeration on Strix Halo depends on the BIOS GPU allocation setting and the app on top (LM Studio's survey layer was the culprit there, not llama.cpp).

## Serve

```bash
llama-server -m /srv/models/gguf/model-Q4_K_M.gguf -a local-model -c 32768 -ngl all -fa on \
  --host 127.0.0.1 --port 9931 -lm none        # -lm none disables mmap (see below)
```

- **mmap:** the Strix Halo Wiki recommends disabling mmap for large models (moderately slower loads on Vulkan, catastrophically slower on ROCm). In current builds that is `-lm none` (`--load-mode`); older builds use `--no-mmap`. Check `llama-server --help`.
- Large MoE models are the sweet spot: all experts live in the same pool, so `-cmoe` is not needed (and does not help).
- Env knobs for Vulkan exist in `ggml-vulkan.cpp` (for example `GGML_VK_PREFER_HOST_MEMORY`, `GGML_VK_DISABLE_COOPMAT`, `GGML_VK_PERF_LOGGER=1`); their effect on Strix Halo is **unverified**: profile with `GGML_VK_PERF_LOGGER=1` before changing anything.
- Pick quants that leave room for KV cache: a model near the pool size gets OOM-killed. Wiki test: a 105 GB Q8_0 exceeded a 120 GiB pool once KV and buffers were added; Q6_K and Q4_K_M ran.
- Decode speed is bound by memory bandwidth (about 256 GB/s class); Q4 beats Q8 and active parameters matter more than total.

## Benchmark

```bash
llama-bench -m model-Q4_K_M.gguf -ngl 99 -fa on -lm none -p 512,2048 -n 128 -d 0,8192
# compare backends: run the same command from a Vulkan build and a HIP build
```

## Troubleshooting

- Load hangs for minutes on a very large model: check TTM limits and mmap; community reports the Vulkan loader stalling above about 64 GB without the kernel tuning above.
- ROCm run is pathologically slow: missing `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` (the HIP build sees only BIOS-reserved VRAM and splits the graph).
- Only about half the RAM is visible: TTM limit or `amdgpu.gttsize` conflict.

See the `amd-strix-halo` platform skill (planned) for hardware, BIOS and OS setup: `npx skills add ScaleDockHQ/llm-skills --skill amd-strix-halo`.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md (Vulkan, HIP unified memory)
- https://strixhalo.wiki/AI/llamacpp-performance
- https://github.com/Lychee-Technology/llama-cpp-for-strix-halo/
- https://github.com/ROCm/ROCm/issues/5595
- https://github.com/ggml-org/llama.cpp/issues/26089
- https://strix-benchmarks.vercel.app/
