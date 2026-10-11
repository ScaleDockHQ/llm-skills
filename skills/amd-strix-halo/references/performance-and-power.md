# Performance and power

> Verified against strix-halo-toolboxes.com host guide, kyuz0/amd-strix-halo-toolboxes README, Strix Halo Wiki AI overview (2025-08), 2026-10-11

Most numbers below are single-maintainer or community measurements. Benchmark your own model and context length (`llama-bench` in the `llama-cpp` skill) before keeping a change. The toolbox maintainer points to `local-llm-benchmarks.dev` for current community benchmarks; his older archived results are no longer updated.

## Host tuning (approval needed)

1. **Memory pool:** `memory.md`.
2. **tuned profile:** `accelerator-performance` disables higher-latency CPU idle states.

```bash
sudo apt install tuned            # or: sudo dnf install tuned
sudo systemctl enable --now tuned
sudo tuned-adm profile accelerator-performance
tuned-adm active
```

The wiki (2025-08) measured about 3 percent more raw Vulkan memory bandwidth and 5 to 8 percent better llama.cpp prompt processing (`pp512`) with little effect on token generation. Undo: `sudo tuned-adm profile <previous>` (read it first with `tuned-adm active`). 3. **Headless:** the toolbox guide switches to `multi-user.target` to free RAM and GPU resources: `sudo systemctl set-default multi-user.target && sudo reboot`. Restore with `sudo systemctl set-default graphical.target && sudo reboot`. 4. **IOMMU:** `amd_iommu=off` is the highest-impact and highest-risk change; see `memory.md`. The wiki found `iommu=pt` gave no speed benefit in its tests. The wiki says AMD's ROCm IOMMU guidance recommends `iommu=pt`.

## Engine settings

- Load all layers on the GPU (`-ngl 99`, or 999 for more than 99 layers; current llama.cpp accepts `-ngl all`). The wiki notes CPU memory bandwidth is about half the GPU's on this chip, so partial CPU offload is slow.
- Flash attention on (`-fa 1` in the toolbox README, `-fa on` in current builds). The toolbox README says always use flash attention and no mmap on this platform to avoid crashes and slowdowns.
- **mmap:** loading a model larger than half of RAM with mmap is marginally bad for Vulkan and catastrophically slow for ROCm per the wiki (hours for large models). Use `-lm none` in current llama.cpp, or `--no-mmap` in older builds.
- If the engine offers a unified-memory switch for HIP on APUs, set it as the engine docs say (llama.cpp documents `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` for HIP APUs; see the `llama-cpp` skill).
- Try `ROCBLAS_USE_HIPBLASLT=1` on ROCm builds; the wiki says hipBLASLt kernels are sometimes faster than the default rocBLAS ones. Measure it.
- The wiki reports the ROCm rocWMMA flash-attention path can give about 2x prompt-processing speed over Vulkan in its tests (2025-08); newer ROCm and llama.cpp builds have changed since, so re-test.

## Expectations

Decode speed scales with memory bandwidth and active parameters: Q4 beats Q8, and a mixture-of-experts model with few active parameters runs well. Dense 70B-class models are slow on a 256 GB/s bus. For a faster bus or more compute per dollar, compare in `choosing-hardware`.

## Cooling and power

Sustained load on a small-form-factor chassis throttles. The toolbox repository ships a GPU workload watcher (`systemd/gpu-workload-watch`) that switches Framework cooling and TuneD profiles automatically when it detects llama.cpp, vLLM and similar servers; read the repository README before installing it, since it runs as a systemd service. Check temperature and power with `amd-smi metric` when ROCm is installed.
