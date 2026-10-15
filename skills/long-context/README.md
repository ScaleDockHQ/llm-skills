# Long Context

Helps an agent serve long context windows: size the KV cache, set the engine's context flag, extend positions with YaRN or RoPE scaling only when needed, tune chunked prefill, and use sliding window or context parallelism. It gives exact per-engine flags, defaults and constraints for vLLM, SGLang, TensorRT-LLM and llama.cpp, plus the documented status for TensorFold, Ollama and ExLlamaV3. Every extension goes through a baseline-versus-candidate gate with needle and RULER-style checks.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill long-context
```

## Rules

- **Discover first.** Read the model's native window, RoPE settings, KV heads and free memory before changing anything.
- **Need, not maximum.** Set the context flag to the real requirement, and extend RoPE only above the native window.
- **Gate numerics.** YaRN and RoPE scaling, KV quantization and window overrides need the `llm-evals` gate with long-context checks.
- **Verify upstream.** Flags were checked on 2026-10-11; re-check the installed version.
- **Ask before changing the system.** Restarts and config edits need approval and a rollback.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine context, RoPE/YaRN, chunked prefill, sliding window and context-parallel flags.
- [`references/quality-gate.md`](references/quality-gate.md): needle and RULER-style gate, short-prompt regression check and rollback.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and tuning.
- `llm-evals`: the quality gate.
- `kv-cache-quantization`, `kv-cache-offloading`, `prefix-aware-routing`, `multi-node-inference`, `disaggregated-serving`, `choosing-hardware`, `choosing-inference-engine`, `moe-serving`, `multi-lora-serving`, `speculative-decoding`, `reasoning-models`: related techniques.

## License

MIT
