# NVIDIA DGX Spark

Set up, size, network and operate an NVIDIA DGX Spark (GB10 Grace Blackwell, 128 GB unified memory, DGX OS) for LLM inference: known-good software versions, unified-memory budgeting and safety, ConnectX-7 clustering with NCCL validation, host preparation, remote access, updates, and which engine and image runs on it.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark
```

## Rules

- **Do not reinstall the driver, CUDA or Docker on DGX OS.** Verify them.
- **`nvidia-smi` memory is not reported on this platform.** Use `free -h` and `/proc/meminfo`.
- **Leave headroom.** Engine memory fractions share RAM with the OS.
- **Same image and paths on both nodes.** Compare IDs, not tags.

## References

- [`references/hardware-and-os.md`](references/hardware-and-os.md): specs and the current software stack.
- [`references/memory.md`](references/memory.md): unified memory, budgeting, earlyoom, capped jobs.
- [`references/networking.md`](references/networking.md): QSFP, netplan, SSH, NCCL.
- [`references/host-setup.md`](references/host-setup.md): Docker, toolkit, service user, disks.
- [`references/monitoring.md`](references/monitoring.md): Dashboard, sparkDash, metrics.
- [`references/updating.md`](references/updating.md): OS, firmware, recovery.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/combos/`](references/combos): engines, dual-node cluster, remote access.
- [`templates/`](templates): netplan and earlyoom files.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`: engines.
- `llama-swap`, `self-hosted-llms`: swapping and the full stack.

## License

MIT
