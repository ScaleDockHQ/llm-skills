# Multi-LoRA Serving

Helps an agent serve many LoRA adapters over one base model: register adapters, size the adapter slots and rank, select an adapter per request, and load or unload adapters at runtime where the engine allows it. It gives exact per-engine flags, defaults and constraints for vLLM, SGLang, TensorRT-LLM and llama.cpp, plus the documented status for TensorFold, Ollama and ExLlamaV3. Merging, scale blending and quantized bases go through a baseline-versus-candidate gate with adapter isolation checks. Producing adapters stays in `fine-tuning-llms`.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill multi-lora-serving
```

## Rules

- **Discover first.** Read each adapter's base model, rank and target modules, and the served base, before changing anything.
- **Same base only.** An adapter works only on the base it was trained on.
- **Runtime loading is a trust boundary.** Keep load endpoints on loopback, load only vetted local paths.
- **Gate numerics.** Merges at low precision, quantized bases and scale blends need the `llm-evals` gate.
- **Verify per adapter.** Load success does not prove an adapter is applied.
- **Ask before changing the system.** Restarts need approval and a rollback.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine flags, defaults, per-request selection and runtime load/unload APIs.
- [`references/quality-gate.md`](references/quality-gate.md): per-adapter regression, isolation and merge checks, rollback.

## Companion skills

- `fine-tuning-llms`: produce, evaluate, merge and convert adapters.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and tuning.
- `llm-evals`: the quality gate.
- `llm-gateway`, `model-quantization`, `moe-serving`, `long-context`, `speculative-decoding`, `kv-cache-offloading`, `prefix-aware-routing`, `choosing-inference-engine`: related skills and techniques.

## License

MIT
