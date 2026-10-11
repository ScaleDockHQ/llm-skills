---
name: reasoning-models
description: Configure and verify reasoning (thinking) output on each inference engine. Per-engine matrix for vLLM --reasoning-parser and thinking_token_budget, SGLang --reasoning-parser, llama.cpp --reasoning-format/--reasoning-budget, TensorRT-LLM, Ollama think, TensorFold, TabbyAPI, plus chat_template_kwargs per family and reasoning vs reasoning_content. Use when thoughts appear in content, reasoning_content is empty, enable_thinking does nothing, or effort and budget need mapping or gating.
license: MIT
compatibility: Needs shell access to the serving host or an OpenAI-compatible endpoint, curl and jq. Changing engine flags, gateway config or restarting a service needs the user's explicit approval. Works on Linux, macOS and Windows hosts that run the engines.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Reasoning Models

Get a thinking model's trace separated from its answer on the engine in use, controlled by the right toggle, effort and budget for its family, and proven by a probe and an accuracy-versus-cost gate.

**Scope:** this cross-product technique, with per-engine flags and quality gates. Product install and tuning stay in product skills (see Companion skills).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets. Replace the port with the one in use (`ss -ltnp` shows listeners).

```bash
# Engine and version
command -v vllm && vllm --version
python3 -c "import sglang; print(sglang.__version__)" 2>&1 | tail -1
command -v trtllm-serve llama-server ollama
llama-server --version 2>&1 | head -2; ollama --version

# What the engine was started with (look for parser, format, budget flags)
ps -eo args | grep -E 'vllm|sglang|trtllm|llama-server|tensorfold|tabby' | grep -v grep | cut -c1-500
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Command}}' 2>/dev/null | cut -c1-400

# Model, and whether its template knows a thinking switch
curl -s http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -s http://127.0.0.1:8080/props | jq -r '.chat_template' | grep -o -E 'enable_thinking|thinking|reasoning_effort' | sort | uniq -c   # llama.cpp
curl -s http://localhost:11434/api/show -d '{"model":"MODEL"}' | jq '.thinking'                                                       # Ollama

# Gateway config that already maps effort or strips fields
rg -n 'reasoning|thinking|setParamsByID|stripParams' ~/llama-swap.yaml litellm*.yaml 2>/dev/null
```

Also read the model card and the `chat_template` in `tokenizer_config.json`: the template defines which kwarg exists (`enable_thinking`, `thinking`, `reasoning_effort`) and the parser must match its think tags.

Ask the user only what discovery cannot show: which model and engine, which clients read the trace, whether the trace should be shown or hidden, the latency and token budget, and the accuracy floor.

## Decision flow

1. **Pick the parser or format** for the engine and family in `references/engine-reasoning-matrix.md`. Without it the trace lands in `content`.
2. **Know the field.** vLLM returns `reasoning`; SGLang, llama.cpp and TensorFold return `reasoning_content`; Ollama native returns `thinking`. Fix clients or the gateway accordingly (`references/gateway-mapping-and-gate.md`).
3. **Pick the toggle by family.** `enable_thinking` for Qwen3, Granite 4.2 and Gemma 4; `thinking` for DeepSeek-V3.1 and Granite 3.2; top-level `reasoning_effort` for gpt-oss. Table in the matrix reference.
4. **Effort levels.** Test every level you expose; models disagree on the value set. Variants are cheapest as gateway aliases of one process.
5. **Budget.** A hint (`chat_template_kwargs` budget) is not a cap. Use an enforced control: vLLM `thinking_token_budget` with `--reasoning-config`, SGLang `--enable-strict-thinking`, llama.cpp `--reasoning-budget`, TensorFold `thinking_budget`. Confirm with the deterministic check.
6. **Unsupported fields.** Strip them per model in the gateway rather than hoping the engine ignores them.
7. **Tools or grammars too?** Pair the reasoning parser with the tool parser (`tool-calling-parsers`) and check how constrained decoding interacts with the think block (`structured-outputs`).
8. **Gate it** before the change serves users.

## Rules

- **Ask before changing the system.** Engine flags, gateway config and restarts need approval and an undo path (keep the old command line and config).
- **Secrets never touch output.** Keys live in `0600` files or environment variables (`LLM_API_KEY_FILE`, `LLM_API_KEY`).
- **Verify upstream.** Flag and parser names come from the installed `--help` and upstream docs; the references record versions and date. Do not copy a key between families.
- **Thinking changes answers and cost.** Gate reasoning on or off, any effort level and any thinking budget with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`): accuracy against baseline, reasoning tokens and latency, budget truncation rate, empty-answer rate, trace leaks, rollback to saved flags.
- **Hidden is not free.** `include_reasoning: false` (vLLM) hides the trace; the model still generates and bills the tokens.
- **Traces can contain sensitive input.** Do not log or forward `reasoning` fields to users or third parties unless that is intended.

## Techniques per engine

- [ ] Choose parser, toggle and budget for the family -> `references/engine-reasoning-matrix.md`.
- [ ] vLLM: `--reasoning-parser NAME`; optional `--default-chat-template-kwargs '{"enable_thinking": false}'`; budget needs `--reasoning-config` and per-request `thinking_token_budget`.
- [ ] SGLang: `--reasoning-parser NAME`; budget `--enable-strict-thinking` plus `custom_params.thinking_budget`.
- [ ] llama.cpp: `--reasoning-format`, `--reasoning on|off|auto`, `--reasoning-effort LEVEL`, `--reasoning-budget N`.
- [ ] TensorRT-LLM: `trtllm-serve --reasoning_parser NAME` (prototype); other controls unverified.
- [ ] Ollama: request `think` with a value from `/api/show`; trace in `message.thinking`.
- [ ] TensorFold: `--reasoning-effort`, `--thinking`/`--no-thinking`, `--thinking-budget`; trace in `reasoning_content`.
- [ ] ExLlamaV3/TabbyAPI: `reasoning`, `reasoning_start_token`, `reasoning_end_token`; template variables per family.
- [ ] Verify: run `scripts/probe-reasoning.sh BASE_URL MODEL [default|think-on|think-off|effort-low|effort-high]`. Pass means HTTP 200, a non-empty answer, no think tags in `content`, a trace field when thinking is on and none when it is off. Compare `effort-low` and `effort-high` token counts. Then run the gate in `references/gateway-mapping-and-gate.md`; done when accuracy meets the floor you wrote and token or latency goals are met.

## Reference index

- `references/engine-reasoning-matrix.md`: parsers, flags, fields, budgets and effort per engine, plus the per-family kwarg table. Load at step 1.
- `references/gateway-mapping-and-gate.md`: field naming across layers, llama-swap and LiteLLM mapping, stripping fields, the reasoning gate and pitfalls. Load at steps 2, 4, 6 and 8.
- `scripts/probe-reasoning.sh`: read-only reasoning probe (bash 3.2+, curl, jq).

## Companion skills

- `llm-evals`: golden sets and the quality gate. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `tool-calling-parsers`: tool parsers beside reasoning parsers. Install: `npx skills add ScaleDockHQ/llms-skills --skill tool-calling-parsers`.
- `structured-outputs`: constrained decoding with thinking models. Install: `npx skills add ScaleDockHQ/llms-skills --skill structured-outputs`.
- `vllm`: vLLM install and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `sglang`: SGLang install and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `tensorrt-llm`: TensorRT-LLM and `trtllm-serve`. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorrt-llm`.
- `llama-cpp`: llama.cpp server. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `ollama`: Ollama. Install: `npx skills add ScaleDockHQ/llms-skills --skill ollama`.
- `tensorfold`: TensorFold. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorfold`.
- `exllamav3`: ExLlamaV3 and TabbyAPI. Install: `npx skills add ScaleDockHQ/llms-skills --skill exllamav3`.
- `choosing-inference-engine`: pick an engine by reasoning support. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `llm-gateway`: gateway aliases and field stripping. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `self-hosted-llms`: the full self-hosted stack. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
