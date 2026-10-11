# AMD Instinct

Set up, verify and operate AMD Instinct GPUs (MI300X, MI325X, MI350X, MI355X, MI200) with ROCm 10.x for LLM inference: matching driver, firmware and ROCm, GPU access in containers, which vLLM, SGLang or llama.cpp image to run, multi-GPU checks with RCCL, partitioning, health validation, monitoring with `amd-smi`, and updates.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill amd-instinct
```

## Rules

- **Match driver, firmware and ROCm to AMD's compatibility matrix.**
- **Use `amd-smi`.** `rocm-smi` is removed from the standard ROCm 10.1 build.
- **Ask before changing the system.** Drivers, kernel arguments, firmware, partitions and resets need approval.
- **Pin engine images by tag and digest.** Validated engine versions trail the engine projects.

## References

- [`references/hardware-and-stack.md`](references/hardware-and-stack.md): parts, targets, supported OS, driver, firmware, ROCm 10.1.0 stack.
- [`references/install.md`](references/install.md): driver, packages, wheels, groups.
- [`references/containers-and-engines.md`](references/containers-and-engines.md): run flags, images, wheels.
- [`references/multi-gpu-and-partitioning.md`](references/multi-gpu-and-partitioning.md): topology, RCCL, partitioning, SR-IOV.
- [`references/health-and-validation.md`](references/health-and-validation.md): acceptance checks and benchmarks.
- [`references/monitoring.md`](references/monitoring.md): `amd-smi` and what to alert on.
- [`references/updating.md`](references/updating.md): upgrade order and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `vllm`, `sglang`, `llama-cpp`: engines.
- `choosing-hardware`, `multi-node-inference`, `llm-observability`, `self-hosted-llms`: sizing, scaling, metrics and the full stack.

## License

MIT
