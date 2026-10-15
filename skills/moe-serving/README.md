# MoE Serving

Helps an agent serve Mixture-of-Experts LLMs on the user's hardware: expert parallelism, DeepEP all-to-all, EPLB load balancing, MoE kernel backends and expert offload to CPU. It gives exact per-engine flags and config keys, defaults and constraints for vLLM, SGLang, TensorRT-LLM and llama.cpp, plus the documented status for TensorFold, Ollama, ExLlamaV3 and KTransformers. Every numerics-changing option goes through a baseline-versus-candidate quality gate.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill moe-serving
```

## Rules

- **Discover first.** Read GPUs, interconnect, RAM, model config and the installed engine version before changing anything.
- **Placement before precision.** Try EP, EPLB and offload at the same dtype before reaching for FP8 or FP4 kernels.
- **Gate numerics.** Quantized MoE kernels, low-precision dispatch and lossy CPU experts need the `llm-evals` gate.
- **Verify upstream.** Flags were checked on 2026-10-11; re-check the installed version.
- **Ask before changing the system.** Installs and restarts need approval and a rollback.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine flag matrix for EP, all-to-all, EPLB, MoE kernels and expert offload.
- [`references/quality-gate.md`](references/quality-gate.md): MoE-specific baseline-versus-candidate procedure and rollback.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and tuning.
- `llm-evals`: the quality gate.
- `choosing-inference-engine`, `choosing-hardware`, `multi-node-inference`, `disaggregated-serving`, `speculative-decoding`, `kv-cache-offloading`, `kv-cache-quantization`, `long-context`, `multi-lora-serving`, `model-quantization`: related techniques.

## License

MIT
