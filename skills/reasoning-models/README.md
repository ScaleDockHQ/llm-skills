# Reasoning Models

An agent skill for running thinking models on self-hosted engines: separating the trace from the answer, choosing the right toggle for each model family, mapping effort and budget, and gating the change. It holds the verified parser names and flags for vLLM (`--reasoning-parser`, `thinking_token_budget`), SGLang (`--reasoning-parser`, strict thinking), llama.cpp (`--reasoning-format`, `--reasoning-budget`, `--reasoning-effort`), TensorRT-LLM, Ollama (`think`), TensorFold and TabbyAPI, the `chat_template_kwargs` key per family, gateway mapping for llama-swap and LiteLLM, a probe script, and an accuracy-versus-cost gate.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill reasoning-models
```

## Rules

- **Discover first.** Read the engine version, running flags and the model's chat template before changing a toggle.
- **Field names differ.** vLLM returns `reasoning`; SGLang, llama.cpp and TensorFold return `reasoning_content`; Ollama returns `thinking`.
- **Ask before changing the system.** Engine flags, gateway config and restarts need approval and an undo path.
- **Gate thinking changes.** Use `llm-evals`: accuracy, reasoning tokens, latency, truncation, empty answers, rollback.
- **Never print secrets.** Keys come from `0600` files or environment variables.

## References

- [`references/engine-reasoning-matrix.md`](references/engine-reasoning-matrix.md): parsers, flags, fields, budgets and per-family kwargs.
- [`references/gateway-mapping-and-gate.md`](references/gateway-mapping-and-gate.md): gateway mapping, stripping fields, the reasoning gate, pitfalls.
- [`scripts/probe-reasoning.sh`](scripts/probe-reasoning.sh): reasoning probe against an OpenAI-compatible endpoint (bash, curl, jq).

## Companion skills

- `llm-evals`: golden sets and the quality gate.
- `tool-calling-parsers`, `structured-outputs`: tool parsers and constrained decoding beside reasoning.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and tuning.
- `choosing-inference-engine`, `llm-gateway`, `self-hosted-llms`: engine choice, gateway and the full stack.

## License

MIT
