# NVIDIA RTX workstation GPUs

Choose, size and run NVIDIA RTX PRO Blackwell workstation GPUs (6000 96 GB, 5000, 4500, 4000, Max-Q variants) for local LLM inference on Linux: card selection by VRAM and bandwidth, the required open kernel modules, CUDA and sm_120 builds, multi-GPU PCIe layout, power, cooling and MIG.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill nvidia-rtx-workstation
```

## Rules

- **Blackwell requires the open kernel modules** (`nvidia-open`).
- **Budget VRAM explicitly**, with headroom.
- **Check PSU, connector and airflow** before adding cards.
- **Ask before** driver, MIG or power-limit changes.

## References

- [`references/cards.md`](references/cards.md): lineup and specs.
- [`references/driver-and-cuda.md`](references/driver-and-cuda.md): driver, CUDA, sm_120.
- [`references/multi-gpu-power-cooling.md`](references/multi-gpu-power-cooling.md): topology, power, MIG.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/`](references/combos): engines on RTX PRO.

## Companion skills

- `choosing-hardware`, `vllm`, `llama-cpp`, `ollama`, `sglang`, `exllamav3`, `nvidia-dgx-station`.

## License

MIT
