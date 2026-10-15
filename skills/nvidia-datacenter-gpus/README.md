# NVIDIA datacenter GPUs

Choose and operate NVIDIA datacenter GPUs (H100, H200, B200, B300, GB200/GB300) for LLM serving: HBM capacity and bandwidth, SXM versus PCIe/NVL, NVLink and NVSwitch with Fabric Manager, data center driver branches, MIG and DCGM, plus an engine matrix and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-datacenter-gpus
```

## Rules

- **Driver and Fabric Manager versions must match.**
- **Blackwell needs the open kernel modules.**
- **Size by memory first**, with headroom.
- **Ask before** driver, MIG, power or firmware changes.

## References

- [`references/gpu-lineup.md`](references/gpu-lineup.md): specs by GPU.
- [`references/driver-and-fabric.md`](references/driver-and-fabric.md): drivers and Fabric Manager.
- [`references/mig-and-dcgm.md`](references/mig-and-dcgm.md): MIG and DCGM.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/`](references/combos): engines on datacenter GPUs.

## Companion skills

- `choosing-hardware`, `vllm`, `sglang`, `tensorrt-llm`, `nvidia-gpu-operator`, `llm-observability`, `nvidia-rtx-workstation`.

## License

MIT
