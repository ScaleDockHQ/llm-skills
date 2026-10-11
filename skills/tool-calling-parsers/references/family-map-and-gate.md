# Tool-calling parsers: model-family map, tool-call gate and failure modes

> Verified against vLLM v0.31.0 (docs: features/tool_calling, features/reasoning_outputs; vllm/tool_parsers/**init**.py), SGLang v0.5.21 (docs: advanced_features/tool_parser, separate_reasoning; srt/function_call/parser_names.py), TensorRT-LLM v1.2.1 and docs main (commands/trtllm-serve), llama.cpp v0.6.0 (docs/function-calling.md), TabbyAPI main (docs/10.-Tool-Calling.md), 2026-10-11

Model-family skills (`qwen`, `gpt-oss`, `deepseek`, `glm`, `kimi`, `mistral`, `llama`, `gemma`, `nemotron` and others) carry the per-model detail where they exist. This table is the cross-engine starting point. A blank cell means no pairing was found in upstream docs or parser lists; check `--help` rather than guessing.

## Family to parser, per engine

| Family                           | vLLM `--tool-call-parser`                                  | SGLang `--tool-call-parser`                                       | TensorRT-LLM `--tool_parser` | llama.cpp                                                | TabbyAPI `tool_format`                                  |
| -------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------- | -------------------------------------------------------- | ------------------------------------------------------- |
| Hermes 2/3, Qwen2.5, QwQ         | `hermes`                                                   | `qwen25` (Qwen2.5), `hermes`                                      | `qwen3` (Qwen3 family)       | native Hermes 2 Pro / Qwen 2.5                           | `hermes`                                                |
| Qwen3 (hybrid/instruct/thinking) | `hermes` (doc pairs Qwen2.5 and QwQ; check Qwen3)          | `qwen` (docs: Qwen3-Next, Qwen3-VL)                               | `qwen3`                      | per template                                             | `hermes` (alias `qwen3`)                                |
| Qwen3-Coder                      | `qwen3_xml` (docs); `qwen3_coder` also registered          | `qwen3_coder`                                                     | `qwen3_coder`                | per template                                             | `qwen3_coder` (aliases `qwen3_5`, `step3_5`, `step3_7`) |
| Llama 3.1 / 3.2 / 3.3            | `llama3_json` + example template; `pythonic` for 3.2 small | `llama3`; `pythonic`                                              |                              | native Llama 3.x                                         |                                                         |
| Llama 4                          | `llama4_pythonic` + template (recommended)                 | `pythonic` (docs also list `llama4`, absent from v0.5.21 choices) |                              | per template                                             |                                                         |
| Mistral / Mistral Nemo           | `mistral` (+ tokenizer mode flags)                         | `mistral`                                                         |                              | native Mistral Nemo                                      | `mistral`                                               |
| DeepSeek-V3 / R1-0528            | `deepseek_v3` + template                                   | `deepseekv3`                                                      | `deepseek_v3`                | DeepSeek R1 native (WIP; use upstream override template) |                                                         |
| DeepSeek-V3.1                    | `deepseek_v31` + template                                  | `deepseekv31`                                                     | `deepseek_v31`               | per template                                             |                                                         |
| DeepSeek-V3.2                    | `deepseek_v32`                                             | `deepseekv32`                                                     | `deepseek_v32`               |                                                          |                                                         |
| DeepSeek-V4 / V4.1               | `deepseek_v4`, `deepseek_v41`                              | `deepseekv4`, `deepseekv41`                                       | `deepseek_v4` (main)         |                                                          | `deepseek_v4`                                           |
| gpt-oss                          | `openai`                                                   | `gpt-oss`                                                         | see engine matrix            | native GPT-OSS (Harmony)                                 | `harmony` (auto)                                        |
| GLM-4.5 / 4.6                    | `glm45`                                                    | `glm45` (docs table: `glm`)                                       | `glm4` (main)                |                                                          | `glm4_5` (alias `glm4_6`)                               |
| GLM-4.7                          | `glm47`                                                    | `glm47`                                                           | `glm47` (main)               |                                                          | `glm4_5` (alias `glm4_7`)                               |
| Kimi K2                          | `kimi_k2`                                                  | `kimi_k2`                                                         | `kimi_k2`                    |                                                          | `kimi` (alias `kimi_k2`)                                |
| Gemma 4                          | `gemma4`                                                   | `gemma4`                                                          | `gemma4` (main)              | per template                                             | `gemma4`                                                |
| FunctionGemma                    | `functiongemma` + template                                 |                                                                   |                              |                                                          |                                                         |
| MiniMax-M2                       | `minimax_m2`                                               | `minimax-m2`                                                      | `minimax_m2` (main)          |                                                          | `minimax_m2`                                            |
| Step-3.5 / 3.7                   | `step3p5`                                                  | `step3p5`                                                         |                              |                                                          | `qwen3_coder` alias `step3_5`                           |
| IBM Granite 4 / 3                | `granite4` / `granite`                                     |                                                                   |                              | native Granite listed in examples                        |                                                         |
| Cohere Command A                 | `cohere_command3`, `cohere_command4`                       | `cohere_command4`                                                 |                              | Command R7B native                                       |                                                         |
| Olmo 3                           | `olmo3`                                                    |                                                                   |                              |                                                          | `olmo3`                                                 |

Parser names on one engine are not portable to another: vLLM `deepseek_v31` is SGLang `deepseekv31`; vLLM `minimax_m2` is SGLang `minimax-m2`; vLLM `openai` is SGLang `gpt-oss`.

## Reasoning plus tools

Most tool-calling reasoning models need both parsers (see the `reasoning-models` skill): vLLM `--reasoning-parser` with `--tool-call-parser` (for example `step3p5`, `mimo`, `hunyuan_a13b`, `cohere_command4` take a same-named pair), SGLang `--reasoning-parser kimi_k2` with `--tool-call-parser kimi_k2`. In vLLM, tool calls are parsed from `content` only. TabbyAPI parses tool calls inside reasoning by default (`tool_calls_in_reasoning: true`). TensorFold returns a call written before the think block closes as the reply's tool call when the reply ends inside the block.

## Tool-call gate

Run this with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`) whenever the parser, chat template, engine version, quantization, KV-cache dtype, strict level or model changes. Write thresholds first.

1. **Tool set and golden prompts.** 30 to 100 real tasks with the real tool schemas. For each: expected tool name(s), expected arguments (exact or checkable), and for multi-step tasks the expected sequence. Include no-tool prompts, ambiguous prompts, parallel-call prompts, large argument payloads, nested objects, arrays and non-ASCII strings.
2. **Baseline arm.** Current parser and template. Run each prompt at least 3 times with fixed sampling. Capture the raw response, not only the parsed one.
3. **Candidate arm.** Exactly one change.
4. **Metrics.**
   - tool-call success rate: `tool_calls` present with `finish_reason` of `tool_calls` (or the engine's equivalent) and `arguments` that parse as JSON and validate against the tool's schema;
   - correct-tool rate and argument accuracy against the expected calls;
   - leak rate: raw tool-call markup (for example `<tool_call>`) or reasoning text left in `content`;
   - false-positive rate on no-tool prompts;
   - multi-turn completion: the agent loop (call, tool result, final answer) finishes within N turns;
   - parallel-call handling and, on streaming, the same results as non-streaming;
   - tokens and latency per task.
5. **Decide.** Candidate must not be below baseline on success, correct-tool and leak rates beyond measured noise, and must meet your product floor. List per-prompt flips and read them. Record the decision.
6. **Rollback.** Keep the previous flags, template file and image tag in version control; reverting is restoring them and restarting the engine.

## Failure modes

| Symptom                                                       | Likely cause                                                                                                                                                       | Check or fix                                                                                                   |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| Tool call appears as text in `content`, `tool_calls` empty    | Parser flag missing or wrong family; vLLM missing `--enable-auto-tool-choice`; llama.cpp built with `--no-jinja` or template unrecognized (`Chat format: Generic`) | Use the family row above; check startup log and `/props`. Try a template override.                             |
| vLLM error when tools are sent                                | `tool_choice: auto` without `--enable-auto-tool-choice` and `--tool-call-parser`                                                                                   | Add both flags; `required` and named work without them                                                         |
| Malformed arguments (array serialized as string, wrong types) | Model quality (vLLM documents this for Llama JSON); unconstrained `auto`                                                                                           | Strict schemas plus `--tool-strict-level` (vLLM) or `SGLANG_TOOL_STRICT_LEVEL`; validate and retry client-side |
| Mistral template exception about tool call IDs                | Transformers tokenizer backend needs 9-digit IDs                                                                                                                   | Use the official mistral-common format or the vLLM example Mistral templates                                   |
| Empty `content` with gpt-oss on SGLang                        | Parser keeps only normal text, drops analysis channel                                                                                                              | Return the tool result as a `role: "tool"` message so the model writes the final answer                        |
| First `required` or named call is slow (vLLM)                 | Grammar compile on first use                                                                                                                                       | Warm up the tool schemas after startup                                                                         |
| Tool quality dropped after a quantization change              | Extreme KV quantization degrades tool calling (llama.cpp upstream caution)                                                                                         | Rerun the gate with KV at higher precision                                                                     |
| `Cannot auto-detect tool parser` (TensorRT-LLM)               | `--tool_parser auto` and unsupported model type                                                                                                                    | Name the parser explicitly (list in the engine matrix)                                                         |
| No tool calls parsed on TabbyAPI, warning at startup          | No format matched the template                                                                                                                                     | Set `tool_format`, `reasoning_start_token` and `reasoning_end_token` explicitly                                |
| Ollama OpenAI endpoint ignores `tool_choice`                  | `tool_choice` is not supported there                                                                                                                               | Constrain through the prompt, or use another engine for forced calls                                           |

## Official links

- https://docs.vllm.ai/en/latest/features/tool_calling/
- https://docs.sglang.ai/advanced_features/tool_parser.html
- https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md
- https://github.com/theroyallab/tabbyAPI/blob/main/docs/10.-Tool-Calling.md
