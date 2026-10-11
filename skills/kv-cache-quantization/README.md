# KV Cache Quantization

Helps an agent fit more context or more concurrent requests by quantizing the KV cache (FP8, NVFP4, int8, q8_0, q4_0) for people running their own inference. It sizes the cache, picks the least aggressive dtype for the engine and GPU, gives exact flags for vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, ExLlamaV3 (TabbyAPI) and TensorFold, and gates the quality change with an A/B check before rollout.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill kv-cache-quantization
```

## Rules

- **Discover first.** Read-only checks of engine, GPU, model shape and whether the cache is really the limit.
- **Ask before changing the system.** Restarts and flag edits need approval and an undo path.
- **Gate every change.** KV quantization changes numerics and errors grow with context length. Use the `llm-evals` skill with the longest served context.
- **Start mild.** 8-bit before 4-bit, calibrated scales where the engine supports them.
- **Verify upstream.** Dtype names and hardware support change per release; check `--help` of the installed engine.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine flags, defaults, hardware and constraints, with unverified items marked.
- [`references/sizing-and-quality.md`](references/sizing-and-quality.md): KV size arithmetic, upstream accuracy evidence, calibration and troubleshooting.

## Companion skills

- `llm-evals`: A/B quality gate and decision record.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and operation.
- `model-quantization`, `kv-cache-offloading`, `long-context`, `speculative-decoding`, `choosing-hardware`: related techniques.
- `self-hosted-llms`: running the stack on owned GPU servers.

## License

MIT
