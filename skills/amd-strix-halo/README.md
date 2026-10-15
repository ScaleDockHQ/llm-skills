# AMD Strix Halo

Set up, size and operate AMD Ryzen AI Max (Strix Halo, `gfx1151`, up to 128 GB unified memory) for local LLM inference: kernel and firmware, the GTT/TTM memory pool, Vulkan versus ROCm, toolbox containers and Lemonade, tuning, updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill amd-strix-halo
```

## Rules

- **Ask before changing the system.** Kernel arguments, BIOS, IOMMU and package installs need approval.
- **Check `mem_info_gtt_total` first.** The model must fit the GPU pool with headroom for the OS.
- **Disabling the IOMMU is a trade-off.** It breaks the NPU and weakens DMA protection.
- **Disable mmap for large models.** `-lm none` in current llama.cpp.

## References

- [`references/hardware-and-os.md`](references/hardware-and-os.md): chip, ROCm 10.1.0 support, OS, kernel.
- [`references/memory.md`](references/memory.md): GART, GTT, TTM, kernel parameters, sizing.
- [`references/backends-and-engines.md`](references/backends-and-engines.md): Vulkan, ROCm, toolboxes, Lemonade, vLLM.
- [`references/performance-and-power.md`](references/performance-and-power.md): tuned, headless, mmap.
- [`references/updating.md`](references/updating.md): update order and drift.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `llama-cpp`, `vllm`, `llama-swap`: engines and swapping.
- `choosing-hardware`, `self-hosted-llms`: comparison and the full stack.

## License

MIT
