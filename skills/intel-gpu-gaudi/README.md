# Intel GPU and Gaudi

Set up, verify and operate Intel accelerators for LLM inference: Gaudi 2 and 3 with Gaudi software 1.24.x and the vllm-gaudi plugin, and Intel GPUs (Arc, Arc Pro B-series, Data Center) with vLLM XPU, llama.cpp SYCL and OpenVINO. States clearly what is archived (IPEX, IPEX-LLM) or end of life (the HabanaAI vLLM fork).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill intel-gpu-gaudi
```

## Rules

- **Ask before changing the system.** Drivers, runtime registration and installs need approval.
- **Archived is not supported.** Do not recommend IPEX or IPEX-LLM for new work.
- **Match versions.** Gaudi software, vllm-gaudi plugin and vLLM must be a documented combination.
- **Disable mmap on shared hosts** with llama.cpp.

## References

- [`references/gaudi.md`](references/gaudi.md): software release, runtime, vault images, vllm-gaudi.
- [`references/intel-gpu.md`](references/intel-gpu.md): drivers, vLLM XPU, llm-scaler, llama.cpp SYCL, OpenVINO.
- [`references/status.md`](references/status.md): archived, end of life and current projects.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `vllm`, `llama-cpp`: engines.
- `choosing-hardware`, `self-hosted-llms`: comparison and the full stack.
