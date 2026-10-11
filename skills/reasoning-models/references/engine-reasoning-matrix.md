# Reasoning models: per-engine parsers, flags, fields and budgets

> Verified against vLLM v0.31.0 (docs: features/reasoning_outputs), SGLang v0.5.21 (docs: advanced_features/separate_reasoning, thinking_budget), TensorRT-LLM docs main (commands/trtllm-serve), llama.cpp master (tools/server/README.md), Ollama docs (capabilities/thinking), TensorFold v1.0.7 (docs/api.md), TabbyAPI main (docs/10.-Tool-Calling.md), 2026-10-11

Names below are copied from upstream. Parser lists change between releases: confirm against the installed binary (`vllm serve --help=all`, `python -m sglang.launch_server --help`, `trtllm-serve --help`, `llama-server --help`). This file supersedes the engine notes in the `self-hosted-llms` reasoning-effort reference, and corrects them: vLLM returns `reasoning` (not `reasoning_content`), and llama.cpp's `--jinja` is on by default.

## Flag matrix

| Engine               | Extract reasoning                                                                   | Response field                                                                                   | Toggle / effort                                                                                                  | Budget                                                                                   |
| -------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| vLLM                 | `--reasoning-parser NAME`                                                           | `reasoning` (renamed from `reasoning_content`; non-stream and `delta`)                           | `chat_template_kwargs`; `reasoning_effort` auto-injects `enable_thinking`; `--default-chat-template-kwargs`      | `thinking_token_budget` per request, needs `--reasoning-parser` and `--reasoning-config` |
| SGLang               | `--reasoning-parser NAME`                                                           | `reasoning_content`; request `separate_reasoning` (default on with a parser), `stream_reasoning` | `chat_template_kwargs`; request `reasoning_effort` is forwarded to the template                                  | `--enable-strict-thinking` (exact) or `--enable-custom-logit-processor`                  |
| TensorRT-LLM         | `trtllm-serve --reasoning_parser NAME` (prototype)                                  | not verified in the docs read (unverified)                                                       | not documented in the serve reference (unverified)                                                               | not documented (unverified)                                                              |
| llama.cpp            | `--reasoning-format FORMAT` (default `auto`)                                        | `reasoning_content` (deepseek style)                                                             | `-rea/--reasoning on\|off\|auto`; `--reasoning-effort LEVEL`; request `reasoning_effort`, `chat_template_kwargs` | `--reasoning-budget N` (+ `--reasoning-budget-message`)                                  |
| Ollama               | built in per model                                                                  | `message.thinking` (chat), `thinking` (generate)                                                 | request `think`: `true`, `false`, `null` or a level string from `/api/show`                                      | none documented                                                                          |
| TensorFold           | built in; `reasoning_content` and `delta.reasoning_content`                         | `reasoning_content`; `completion_tokens_details.reasoning_tokens`                                | `--reasoning-effort`, `--thinking` / `--no-thinking`; request `reasoning_effort`, `chat_template_kwargs`         | `--thinking-budget N`, request `thinking_budget`                                         |
| ExLlamaV3 / TabbyAPI | config `reasoning`, `reasoning_start_token`, `reasoning_end_token` (default `auto`) | `reasoning_content` (per the earlier verification; re-check on upgrade)                          | template variables, top-level `reasoning_effort`; `template_vars_default` in model config                        | `reasoning_budget_tokens` (per earlier verification; re-check)                           |

## vLLM

- Enable: `vllm serve MODEL --reasoning-parser NAME`. Without it, thoughts stay inside `content`.
- Field: `reasoning`. `reasoning_content` was the old name; a client reading it silently gets nothing. Update clients, or normalise in the gateway.
- Availability: the `/v1/chat/completions`, `/v1/messages` (Anthropic) and `/v1/responses` endpoints.
- Tool calling parses `content` only, never `reasoning`.
- `include_reasoning: false` (request): reasoning is still generated (quality unchanged) but omitted from the response, and logprobs and token IDs are suppressed too.
- `--default-chat-template-kwargs '{"enable_thinking": false}'` sets a server default. Request `chat_template_kwargs` always win.
- `reasoning_effort` (or Responses `reasoning.effort`): `low`, `medium`, `high` inject `enable_thinking=true`; `none` injects `false`; unset injects nothing. An explicit `enable_thinking` wins. Templates that do not declare `enable_thinking` filter the kwarg out.
- Budget: `thinking_token_budget` (a sampling parameter) counts tokens from `reasoning_start_str`; at the budget vLLM forces `reasoning_end_str`. `--reasoning-config '{"reasoning_start_str": "<think>", "reasoning_end_str": "...</think>"}'`; if not set vLLM tries to initialise both from the parser. `reasoning_end_str` may begin with a transition phrase. No budget given means no limit beyond `max_tokens`. Docs name Qwen3, DeepSeek and Nemotron3 as supporting it.
- Structured output with reasoning models: docs list `json` and `regex` support for each parser below (not for `granite`); the guided grammar applies after the reasoning ends (see `structured-outputs`).

Parsers (from the docs table; the name is what `--reasoning-parser` takes):

| Model series                    | Parser                    | Default thinking                                  | Tool calling                  |
| ------------------------------- | ------------------------- | ------------------------------------------------- | ----------------------------- |
| Cohere Command A Reasoning      | `cohere_command3`         | n/a                                               | yes                           |
| Cohere Command A Plus           | `cohere_command4`         | n/a                                               | yes                           |
| DeepSeek R1 series, QwQ-32B     | `deepseek_r1`             | on                                                | R1 no, QwQ yes                |
| DeepSeek-V3.1                   | `deepseek_v3`             | off; `thinking=True`                              | non-thinking mode only        |
| Gemma 4                         | `gemma4`                  | off; `enable_thinking=True` or `reasoning_effort` | yes                           |
| ERNIE-4.5-VL / 21B-A3B-Thinking | `ernie45`                 | n/a                                               | VL no, Thinking yes           |
| GLM-4.5 series                  | `glm45`                   | n/a                                               | yes                           |
| Holo2 series                    | `holo2`                   | on; `thinking=False` to disable                   | yes                           |
| Hunyuan A13B                    | `hunyuan_a13b`            | n/a                                               | yes                           |
| IBM Granite 3.2                 | `granite`                 | off; `thinking=True`                              | no (and no structured output) |
| IBM Granite 4.2                 | `granite_thinking_parser` | on; `enable_thinking=False` to disable            | yes                           |
| MiniMax-M2                      | `minimax_m2_append_think` | n/a                                               | yes                           |
| Qwen3 series                    | `qwen3`                   | on; `enable_thinking=False` to disable            | yes                           |
| Step-3.5 / Step-3.7 Flash       | `step3p5`                 | n/a                                               | yes                           |

## SGLang

- Enable: `python -m sglang.launch_server --model-path MODEL --reasoning-parser NAME`.
- Contract follows the DeepSeek API: `reasoning_content` plus `content`. Request `extra_body={"separate_reasoning": false}` returns the raw output; `stream_reasoning: false` buffers reasoning to the last reasoning chunk.
- Parsers from the docs: `deepseek-r1` (R1, R1-0528, distills; handles a missing start tag), `deepseek-v3` (V3.1, V3.2; hybrid, uses the `thinking` kwarg, not `enable_thinking`), `qwen3` (standard Qwen3; supports `enable_thinking`) and `qwen3` or `qwen3-thinking` (always-thinking Qwen3), `kimi_k2` (delimiters `◁think▷`; also needs `--tool-call-parser kimi_k2` for tools), gpt-oss (`<|channel|>analysis<|message|>`; parser name per the docs table, which was cut off in the fetch, confirm with `--help`), Apertus 2509 (also `--tool-call-parser apertus2509`).
- Hints: `chat_template_kwargs` can carry `enable_thinking` and `thinking_budget`; the latter only works if the model template defines it (the official Qwen3 template does), otherwise silently ignored. `reasoning_effort` is forwarded into the template. These are hints; the model can overshoot.
- Hard budget, option 1: launch with `--enable-strict-thinking` and a `--reasoning-parser`. Needs a grammar backend that supports token filtering (`xgrammar` is the default); startup fails otherwise. Chat completions: `extra_body={"custom_params": {"thinking_budget": 512}}`. Native `/generate`: `max_thinking_tokens` together with `require_reasoning: true` (without it the budget is silently ignored; sending it to a server without strict thinking returns 400). Server-wide cap: env `SGLANG_MAX_THINK_TOKENS` (default `-1`, none). With strict thinking and no budget, model-specific tokens (Qwen3: `<tool_call>`, `</tool_call>`, `<|im_end|>`, `<|endoftext|>`) are blocked during thinking.
- Hard budget, option 2: `--enable-custom-logit-processor` plus a request `custom_logit_processor` and `custom_params.thinking_budget`. Built-in processors: Qwen3, GLM-4.5/4.6, DeepSeek-R1, Inkling; they hardcode token IDs, so other models need a subclass of `ThinkingBudgetLogitProcessor`.
- The docs give a verification: same prompt at temperature 0 with and without budget; a working cap ends thinking at the budget, an ignored knob reproduces the baseline token for token.

## TensorRT-LLM

- `trtllm-serve MODEL --reasoning_parser NAME`, marked `prototype`. Choices (docs main): `auto`, `minimax_m2_append_think`, `minimax_m2`, `qwen3_5`, `qwen3`, `deepseek-r1`, `deepseek_v4`, `poolside_v1`, `laguna`, `minimax_m3`, `nano-v3`, `nemotron-v3`, `gemma4`, `kimi_k25`, `kimi_k2`, `kimi_k3`. `auto` selects from the model. The v1.2.1 release may list fewer; check `--help`.
- Response field names, effort control and thinking budgets were not found in the serve reference (unverified).

## llama.cpp

- `--reasoning-format FORMAT`: `none` leaves thoughts in `message.content`; `deepseek` puts them in `message.reasoning_content`; `deepseek-legacy` keeps the `<think>` tags in `content` and also fills `reasoning_content`. Default `auto`. Env `LLAMA_ARG_THINK`. Request field `reasoning_format` overrides; `none` outputs raw text.
- `-rea, --reasoning [on|off|auto]`: default `auto` (detect from the template). Env `LLAMA_ARG_REASONING`.
- `--reasoning-effort LEVEL`: `default` keeps the template default, or `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. Given to the chat template. Request `reasoning_effort`: `none` disables thinking, any other value is made available to the template. Env `LLAMA_ARG_REASONING_EFFORT`.
- `--reasoning-budget N`: `-1` unrestricted (default), `0` ends thinking immediately, `N>0` token budget. Env `LLAMA_ARG_THINK_BUDGET`. `--reasoning-budget-message MESSAGE` is injected before the end-of-thinking tag when the budget is exhausted (default none).
- `--reasoning-preserve` / `--no-reasoning-preserve` (default enabled): keep reasoning traces in the whole history for templates with that capability.
- `chat_template_kwargs` per request (example `{"enable_thinking": false}`).
- `reasoning_control: true` on a completion arms `POST /v1/chat/completions/control` with `{"id": ..., "action": "reasoning_end"}` to end the current reasoning block mid-stream.
- `--skip-chat-parsing`: everything, reasoning and tool calls, lands in `content`.
- Templates come from the model metadata unless `--chat-template` or `--chat-template-file` is given.

## Ollama

- Request `think`: `true`, `false` (if the model permits), `null` (model default), or a string level. Numbers are not supported. Use exact values from `/api/show`; unsupported names fall back to the model default.
- Discover: `curl http://localhost:11434/api/show -d '{"model": "gpt-oss"}'` returns `thinking.values` (booleans or level strings) and `thinking.default`; `values: [false]` means no thinking support; no `thinking` object means no metadata.
- Fields: `message.thinking` and `message.content` (chat), `thinking` and `response` (generate). Streaming sends thinking chunks before content chunks.
- Whether the OpenAI-compatible endpoint maps these onto `reasoning_content` or `reasoning` was not verified here (unverified); test it.

## TensorFold

- Request: `reasoning_effort` (`none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`), `chat_template_kwargs.enable_thinking`, `chat_template_kwargs.thinking` (`true`/`false` or `{"type": "enabled"}`/`{"type": "disabled"}`, read when `enable_thinking` is absent), `chat_template_kwargs.reasoning_effort` (the top-level field wins), `thinking_budget`.
- Rules: `none` disables thinking; other values enable it and reach the template. An unnamed level maps to the nearest level the template names, a tie takes the higher. Omitted effort with no startup flag keeps the template default; an explicit `enable_thinking` takes precedence. Effort does not set a token budget. Server flags: `--reasoning-effort`, `--thinking` / `--no-thinking`, `--thinking-budget N`.
- Budget: at the budget-th token while still thinking, the server inserts a newline, the closing think marker and a blank line, then continues the answer; a model that already closed is left alone; request `thinking_budget` absent or `0` takes `--thinking-budget`.
- Output: `reasoning_content` (`delta.reasoning_content` streaming), `completion_tokens_details.reasoning_tokens`. A tool call written before the think block closes becomes the reply's tool call when the reply ends inside the block.
- `--loop-guard` (off by default) closes a repeated exact cycle inside an open think block.
- Responses and Anthropic Messages endpoints also carry reasoning and `thinking`; see upstream.

## ExLlamaV3 / TabbyAPI

- Config keys `reasoning`, `reasoning_start_token`, `reasoning_end_token` (example `<think>` / `</think>`); `auto` is the default for the tags, taken from the detected format when the template or tokenizer confirms them, else switched off. Explicit values override detection. The parser applies reasoning tags even without a `tool_format`.
- Template variables: Hy3 uses top-level `reasoning_effort` (`no_think`, `low`, `high`) and ignores `enable_thinking`; set a server default with `template_vars_default: {reasoning_effort: high}`. DeepSeek-V4 accepts `enable_thinking` (or `thinking_mode: chat|thinking`) and `reasoning_effort` (`low` default, `high`, `max`).
- Harmony (gpt-oss) and Muse Glimmer structure reasoning, content and tool calls themselves and supersede `reasoning` and `tool_format`.

## Chat-template kwargs per family

Key names differ; copying one family's key to another is a top cause of "thinking will not turn off".

| Family                         | Key                                                                                                                 | Default      | Source          |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------- | ------------ | --------------- |
| Qwen3 series                   | `enable_thinking`                                                                                                   | on           | vLLM docs       |
| IBM Granite 4.2                | `enable_thinking`                                                                                                   | on           | vLLM docs       |
| Gemma 4                        | `enable_thinking`, or any `reasoning_effort`                                                                        | off          | vLLM docs       |
| DeepSeek-V3.1, IBM Granite 3.2 | `thinking`                                                                                                          | off          | vLLM docs       |
| DeepSeek-V3.1/V3.2 on SGLang   | `thinking` (not `enable_thinking`)                                                                                  | n/a          | SGLang docs     |
| Holo2                          | `thinking`                                                                                                          | on           | vLLM docs       |
| DeepSeek-V4 (Tabby docs)       | `enable_thinking` or `thinking_mode`; `reasoning_effort` `low`/`high`/`max`                                         | on           | TabbyAPI docs   |
| Hy3 (Tabby docs)               | top-level `reasoning_effort`: `no_think`, `low`, `high`; ignores `enable_thinking`                                  | off          | TabbyAPI docs   |
| gpt-oss                        | request `reasoning_effort`: `low`, `medium`, `high` (earlier verification of the old reference; model card governs) | (unverified) | model card      |
| GLM-5.3 (TensorFold doc)       | template effort names `low`, `high`, `max`; `clear_thinking`                                                        | n/a          | TensorFold docs |

## Official links

- https://docs.vllm.ai/en/latest/features/reasoning_outputs/
- https://docs.sglang.io/docs/advanced_features/separate_reasoning.md
- https://docs.sglang.io/docs/advanced_features/thinking_budget.md
- https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://docs.ollama.com/capabilities/thinking
- https://github.com/ashhart/TensorFold/blob/main/docs/api.md
- https://github.com/theroyallab/tabbyAPI/blob/main/docs/10.-Tool-Calling.md
