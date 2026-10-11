---
name: tool-calling-parsers
description: Pick and verify the tool-call parser for a model on each inference engine. Per-engine and per-family matrix for vLLM --enable-auto-tool-choice --tool-call-parser (hermes, llama3_json, mistral, qwen3_xml, deepseek_v3, openai, glm45, kimi_k2), SGLang --tool-call-parser, TensorRT-LLM --tool_parser, llama.cpp --jinja, Ollama tools, TensorFold, TabbyAPI tool_format, plus a tool-call success gate. Use when tool_calls come back empty, tool markup shows up in content, "auto" tool choice requires --enable-auto-tool-choice, or a model is moved to another engine. Not for JSON schema output (structured-outputs) or thinking (reasoning-models).
license: MIT
compatibility: Needs shell access to the serving host or an OpenAI-compatible endpoint, curl and jq. Changing parser flags, templates or restarting an engine needs the user's explicit approval. Works on Linux, macOS and Windows hosts that run the engines.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Tool-Calling Parsers

Get a model's tool calls returned as structured `tool_calls` on the engine in use, by choosing the right parser name and chat template, then proving it with a probe and a success-rate gate.

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

# What the engine was started with (look for parser and template flags)
ps -eo args | grep -E 'vllm|sglang|trtllm|llama-server|tensorfold|tabby' | grep -v grep | cut -c1-500
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Command}}' 2>/dev/null | cut -c1-400

# Model and its chat template (does it render tools?)
curl -s http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -s http://127.0.0.1:8080/props | jq -r '.chat_template' | grep -c -i tool   # llama.cpp: count of "tool" in the template
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i models-- | head -20
```

Also read the model's `config.json` `architectures` and `chat_template` in `tokenizer_config.json`: the parser must match the markup the template renders.

Ask the user only what discovery cannot show: which model and engine, which clients send tools, whether `tool_choice` must be forced, whether thinking is on, and the success rate they need.

## Decision flow

1. **Find the family row** in `references/family-map-and-gate.md`, then the exact flag and name in `references/engine-parser-matrix.md`. Names differ per engine (vLLM `deepseek_v31`, SGLang `deepseekv31`).
2. **vLLM:** both `--enable-auto-tool-choice` and `--tool-call-parser NAME` are needed for `tool_choice: auto`; add the example chat template when the docs pair one with the parser.
3. **SGLang / TensorRT-LLM:** set the parser name, or try `auto` first and read the log for what it chose; name it explicitly when auto-detection fails.
4. **llama.cpp / Ollama / TensorFold:** there is no parser flag. The chat template decides the format; check the template, then override it (`--chat-template-file`, `--chat-template`) if tools are not rendered.
5. **ExLlamaV3/TabbyAPI:** `tool_format: auto` scores formats against the template; read the `Response parsing:` log line and set it explicitly if it warns.
6. **Thinking model?** Set the reasoning parser too (`reasoning-models`), since tool calls can sit inside or after the think block.
7. **Forced tool choice or strict schemas?** `required` and named calls go through a grammar (`structured-outputs`); `auto` is unconstrained unless strict mode is set (vLLM `--tool-strict-level`, `SGLANG_TOOL_STRICT_LEVEL`).
8. **Gate it** before the change serves users.

## Rules

- **Ask before changing the system.** Parser flags, template files and restarts need approval and an undo path (keep the old command line and template).
- **Secrets never touch output.** Keys live in `0600` files or environment variables (`LLM_API_KEY_FILE`, `LLM_API_KEY`).
- **Verify upstream.** Parser names come from the installed `--help` and upstream docs; the references record versions and date. Do not carry a name from one engine to another.
- **Tool parsers change behavior.** Gate any parser, template, engine, quantization or strict-level change with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`): tool-call success rate, correct-tool and argument accuracy, markup-leak rate, multi-turn completion, rollback to the saved flags.
- **Extreme KV quantization hurts tool calling** (llama.cpp upstream caution); re-gate after any KV-cache dtype change.
- **Never enable llama.cpp `--tools` or `--agent` on a shared endpoint**; they expose file and shell tools.

## Techniques per engine

- [ ] Choose parser and template from the family row -> `references/family-map-and-gate.md`, `references/engine-parser-matrix.md`.
- [ ] vLLM: `--enable-auto-tool-choice --tool-call-parser NAME [--chat-template PATH]`; Mistral needs the tokenizer-mode flags for its official format; optional `--tool-strict-level function|parameter`.
- [ ] SGLang: `--tool-call-parser NAME` (or `auto`); optional `--chat-template`.
- [ ] TensorRT-LLM: `trtllm-serve MODEL --tool_parser NAME` (prototype stability; main branch has more names than v1.2.1).
- [ ] llama.cpp: keep `--jinja` on (default); verify `/props` template and the startup `Chat format:` line; `parallel_tool_calls` is per request.
- [ ] Ollama: use a tool-capable model; native `tools`; no `tool_choice` on the OpenAI endpoint.
- [ ] TensorFold: `tools`, `tool_choice`, `parallel_tool_calls` fields; Qwen XML parameters typed from the schema.
- [ ] TabbyAPI: `tool_format` plus matching `reasoning_start_token` and `reasoning_end_token`.
- [ ] Verify: run `scripts/probe-tools.sh BASE_URL MODEL [auto|required|none|get_weather]`. Pass means HTTP 200, a `get_weather` call with valid JSON arguments (`city`, `unit`), and no raw markup in `content`. Then run the gate in `references/family-map-and-gate.md`; done when success, correct-tool and leak rates meet the thresholds you wrote and are not worse than baseline beyond noise.

## Reference index

- `references/engine-parser-matrix.md`: flags per engine, verified parser name lists (vLLM, SGLang, TensorRT-LLM, TabbyAPI), llama.cpp native formats, Ollama and TensorFold behavior. Load at step 1.
- `references/family-map-and-gate.md`: model family to parser table across engines, reasoning plus tools, the tool-call gate procedure and a symptom table. Load when picking a parser or debugging.
- `scripts/probe-tools.sh`: read-only tool-call probe (bash 3.2+, curl, jq).

## Companion skills

- `llm-evals`: golden sets and the quality gate. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `structured-outputs`: grammar-constrained and strict tool arguments. Install: `npx skills add ScaleDockHQ/llms-skills --skill structured-outputs`.
- `reasoning-models`: reasoning parsers and thinking controls. Install: `npx skills add ScaleDockHQ/llms-skills --skill reasoning-models`.
- `vllm`: vLLM install and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `sglang`: SGLang install and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `tensorrt-llm`: TensorRT-LLM and `trtllm-serve`. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorrt-llm`.
- `llama-cpp`: llama.cpp server. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `ollama`: Ollama. Install: `npx skills add ScaleDockHQ/llms-skills --skill ollama`.
- `tensorfold`: TensorFold. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorfold`.
- `exllamav3`: ExLlamaV3 and TabbyAPI. Install: `npx skills add ScaleDockHQ/llms-skills --skill exllamav3`.
- `choosing-inference-engine`: pick an engine by tool-calling support. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `llm-gateway`: gateway behavior for tools. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `self-hosted-llms`: the full self-hosted stack. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
