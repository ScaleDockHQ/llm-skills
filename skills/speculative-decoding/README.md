# Speculative Decoding

Helps an agent speed up LLM token generation with speculative decoding (EAGLE-3, MTP, draft models, n-gram, suffix, DFlash) for people running their own inference. It discovers the live engine first, picks a method for the workload, gives the exact per-engine flags and constraints for vLLM, SGLang, TensorRT-LLM, llama.cpp, TensorFold, Ollama and ExLlamaV3 (TabbyAPI), and gates the change with an A/B quality check before it reaches users.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding
```

## Rules

- **Discover first.** Read-only checks of engine, version, hardware and traffic before any change.
- **Ask before changing the system.** Restarts and launch-flag edits need approval and an undo path.
- **Gate every deployment.** Even exact verification is lossless only up to hardware numerics, and relaxed-acceptance options are lossy. Use the `llm-evals` skill.
- **Never ship benchmark-only switches** such as synthetic acceptance.
- **Verify upstream.** Every flag in the references carries a verification date; re-check against `--help` of the installed version.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine flags, defaults, constraints and unverified items.
- [`references/methods-and-tuning.md`](references/methods-and-tuning.md): method choice, memory costs, tuning order, acceptance metrics, troubleshooting.

## Companion skills

- `llm-evals`: A/B quality gate for numerics-changing changes.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and operation.
- `choosing-inference-engine`, `kv-cache-quantization`, `reasoning-models`, `structured-outputs`: related techniques.
- `self-hosted-llms`: running the stack on owned GPU servers, including benchmarking.

## License

MIT
