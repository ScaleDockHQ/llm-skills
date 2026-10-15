# Tool-Calling Parsers

An agent skill for getting a model's tool calls returned as structured `tool_calls` on self-hosted engines. It holds the verified parser-name lists and flags for vLLM (`--enable-auto-tool-choice --tool-call-parser`), SGLang (`--tool-call-parser`), TensorRT-LLM (`--tool_parser`), llama.cpp (`--jinja` templates), Ollama, TensorFold and TabbyAPI (`tool_format`), a model-family-to-parser table across engines, a probe script, and a tool-call success gate with rollback.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill tool-calling-parsers
```

## Rules

- **Discover first.** Read the engine version, running flags and chat template before changing a parser.
- **Names are per engine.** vLLM `deepseek_v31` is SGLang `deepseekv31`; never copy a name across engines.
- **Ask before changing the system.** Parser flags, templates and restarts need approval and an undo path.
- **Gate parser changes.** Use `llm-evals`: tool-call success, correct-tool and leak rates, multi-turn completion, rollback.
- **Never print secrets.** Keys come from `0600` files or environment variables.

## References

- [`references/engine-parser-matrix.md`](references/engine-parser-matrix.md): flags and parser names per engine.
- [`references/family-map-and-gate.md`](references/family-map-and-gate.md): family-to-parser table, tool-call gate, failure modes.
- [`scripts/probe-tools.sh`](scripts/probe-tools.sh): tool-call probe against an OpenAI-compatible endpoint (bash, curl, jq).

## Companion skills

- `llm-evals`: golden sets and the quality gate.
- `structured-outputs`: constrained and strict tool arguments.
- `reasoning-models`: reasoning parsers and thinking controls.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and tuning.
- `choosing-inference-engine`, `llm-gateway`, `self-hosted-llms`: engine choice, gateway and the full stack.

## License

MIT
