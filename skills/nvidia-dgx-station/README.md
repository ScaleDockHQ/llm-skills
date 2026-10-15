# NVIDIA DGX Station

Set up, size and operate an NVIDIA DGX Station (GB300 Grace Blackwell Ultra, 252 GB HBM3e plus 496 GB LPDDR5X, DGX OS, ConnectX-8) for LLM inference and fine-tuning: known-good software, HBM versus LPDDR5X budgeting, GPU pinning, BMC and Redfish, two-station RoCE fabric, and updates.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-station
```

## Rules

- **Do not reinstall the driver, CUDA or Docker on DGX OS.** Verify them.
- **Pin the GB300 GPU** when an RTX PRO card is also installed.
- **Keep the default CDMM memory mode.** Legacy NUMA mode is not recommended.
- **Budget HBM first**; LPDDR5X is overflow.

## References

- [`references/hardware-and-os.md`](references/hardware-and-os.md): specs and software stack.
- [`references/memory-and-coherency.md`](references/memory-and-coherency.md): CDMM, HBM, LPDDR5X.
- [`references/bmc-and-power.md`](references/bmc-and-power.md): BMC, Redfish, power.
- [`references/two-station-fabric.md`](references/two-station-fabric.md): two-station bring-up.
- [`references/updating.md`](references/updating.md): updates and recovery.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/`](references/combos): engines on Station.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`: engines.
- `nvidia-dgx-spark`, `self-hosted-llms`, `llm-observability`.

## License

MIT
