# gpt-oss parsers, templates and reasoning toggles

> Verified against OpenAI harmony guide and handle-raw-cot cookbook, vLLM recipes (GPT-OSS) and vLLM main parser registry (v0.31.0 latest release), SGLang gpt-oss docs, llama.cpp guide #15396 and server README, Ollama thinking docs, TensorRT-LLM gpt-oss deployment guide, TensorFold v1.0.7 README, 2026-10-11

## Harmony format in one screen

gpt-oss was trained only on [harmony](https://developers.openai.com/cookbook/articles/openai-harmony); without it output is
wrong. Engines render it from the repo's `chat_template.jinja` or the `openai-harmony` library. Do not hand-write prompts
unless you use `/v1/completions` or token-in token-out.

| Item            | Value                                                                                                                                                                                                |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Roles           | `system` (reasoning effort, dates, built-in tools), `developer` (your "system prompt", function tools), `user`, `assistant`, `tool`. Priority `system` > `developer` > `user` > `assistant` > `tool` |
| Channels        | `analysis` (raw CoT), `commentary` (function calls, preambles), `final` (user-facing)                                                                                                                |
| Special tokens  | `<\|start\|>` 200006, `<\|end\|>` 200007, `<\|message\|>` 200008, `<\|channel\|>` 200005, `<\|constrain\|>` 200003, `<\|return\|>` 200002, `<\|call\|>` 200012                                       |
| Stop tokens     | `<\|return\|>` and `<\|call\|>` (`generation_config.json` `eos_token_id`: 200002, 199999, 200012)                                                                                                    |
| Effort control  | `Reasoning: low\|medium\|high` line in the system message; default medium                                                                                                                            |
| System identity | Keep `You are ChatGPT, a large language model trained by OpenAI.`; put your own instructions in the developer message                                                                                |
| Tokenizer       | `o200k_harmony` (tiktoken); `openai_harmony` downloads the vocab at runtime                                                                                                                          |

Multi-turn rules ([handle raw CoT](https://developers.openai.com/cookbook/articles/gpt-oss/handle-raw-cot)):

1. After a `final` message, drop earlier `analysis` messages from the next prompt.
2. If the last assistant message was a tool call, keep the `analysis` messages back to the previous `final` until the
   model issues a `final`. Dropping them degrades tool use.
3. Store the reply ending in `<|end|>`, not `<|return|>`.
4. Chat Completions convention (from OpenRouter): raw CoT is the `reasoning` property on the message and on stream deltas;
   send it back as `reasoning`. Do not show it to users.

## Reasoning toggles

There is no on/off switch; the lowest setting is `low`. Values other than `low`, `medium`, `high` are not documented.

| Engine / API   | How to set effort                                                                                                                                                                                                                                                                             |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM chat      | request field `reasoning_effort` (used by the NVIDIA Puzzle card and the vLLM recipe; evals use `--reasoning-effort`)                                                                                                                                                                         |
| vLLM responses | not documented in the recipe (unverified); use the system-message `Reasoning:` line via the harmony renderer or the chat endpoint                                                                                                                                                             |
| SGLang         | not documented on the gpt-oss page (unverified); the page shows only parser flags. Test `reasoning_effort` and `chat_template_kwargs` on your build                                                                                                                                           |
| llama.cpp      | server default: `--chat-template-kwargs '{"reasoning_effort": "high"}'`; per request: `chat_template_kwargs.reasoning_effort`. The guide says llama-server only honours the `chat_template_kwargs` field, so a top-level `reasoning_effort` is ignored (a 2025 comment, retest on your build) |
| Ollama         | `think` set to `"low"`, `"medium"` or `"high"`; `GET /api/show` lists `thinking.values` and the default                                                                                                                                                                                       |
| TensorRT-LLM   | the guide only shows `gpt_oss.evals --reasoning-effort low,medium` against the server; no serving-side switch is documented (unverified)                                                                                                                                                      |
| TensorFold     | not qualified for gpt-oss                                                                                                                                                                                                                                                                     |
| Raw harmony    | `Reasoning: high` in the system message (`ReasoningEffort.HIGH` in `openai_harmony`)                                                                                                                                                                                                          |

llama-swap tip: expose `gpt-oss-low` / `gpt-oss-high` with `filters.setParamsByID` (see the `self-hosted-llms` skill's
`reasoning-effort.md`).

## Parsers per engine

| Engine       | Reasoning parser                                                                                                 | Tool-call parser / mode                                                   | Notes                                                                                                                                                  |
| ------------ | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| vLLM         | `--reasoning-parser openai_gptoss` (registry name; one community report says vLLM 0.20.1 auto-applies it)        | `--tool-call-parser openai --enable-auto-tool-choice`                     | Only `tool_choice="auto"` is supported for function calling. `include_reasoning: false` drops CoT from output                                          |
| SGLang       | `--reasoning-parser gpt-oss`                                                                                     | `--tool-call-parser gpt-oss`                                              | Python and web search via `--tool-server` / `EXA_API_KEY`                                                                                              |
| llama.cpp    | `--reasoning-format` (default `auto`; `none` leaves CoT in `content`, `deepseek` puts it in `reasoning_content`) | `--jinja` (default enabled); built-in `gpt-oss` chat template name exists | Use the GGUF's embedded template; do not pass `--chat-template` unless fixing a bug                                                                    |
| Ollama       | built in (`message.thinking` vs `message.content`)                                                               | built in                                                                  | Native MXFP4 kernels, `gpt-oss:20b` 14 GB, `gpt-oss:120b` 65 GB, 128K                                                                                  |
| TensorRT-LLM | handled by `trtllm-serve` (Responses and Chat Completions)                                                       | handled by `trtllm-serve`                                                 | Chat completion output in the guide's sample shows `analysis ... assistantfinal` inline in `content` with `reasoning_content` null; check your version |
| TensorFold   | not qualified                                                                                                    | not qualified                                                             | The 1.0.7 README qualified list has no gpt-oss                                                                                                         |

### Built-in tools versus function tools

- **Function calling** works on vLLM Chat Completions and Responses, SGLang and llama.cpp, with the parsers above.
- **Built-in tools** (browser, python) work on the Responses API with `--tool-server demo` (vLLM, SGLang) or MCP SSE
  servers (`--tool-server host:port,...`). vLLM's support matrix marks built-in tools as unsupported on Chat Completions.
  The demo Python tool needs Docker, or `PYTHON_EXECUTION_BACKEND=dangerously_use_uv` (vLLM) / `UV` (SGLang), which runs
  model-generated code on the host. Never use that on a shared or exposed server.
- Cline and Roo Code lack native tool calls; the llama.cpp guide suggests a custom grammar workaround.

## Sampling

OpenAI recommends `temperature=1.0`, `top_p=1.0` (both the llama.cpp guide and Unsloth repeat this; the HF cards give no
numbers). Unsloth adds `top_k=0` (or experiment with 100). Do not use repetition penalties.
llama-server's defaults are `top-k 40` and `min-p 0.1` and differ from this recommendation; a guide commenter suggests
`min-p 0.01` as a speed-friendly compromise (community, not OpenAI). Set `--temp 1.0 --top-p 1.0` explicitly.

## Sources

- https://developers.openai.com/cookbook/articles/openai-harmony
- https://developers.openai.com/cookbook/articles/gpt-oss/handle-raw-cot
- https://docs.vllm.ai/projects/recipes/en/latest/OpenAI/GPT-OSS.html
- https://raw.githubusercontent.com/vllm-project/vllm/main/vllm/reasoning/__init__.py
- https://docs.sglang.ai/basic_usage/gpt_oss.html
- https://github.com/ggml-org/llama.cpp/discussions/15396
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://docs.ollama.com/capabilities/thinking
- https://nvidia.github.io/TensorRT-LLM/deployment-guide/deployment-guide-for-gpt-oss-on-trtllm.html
- https://github.com/ashhart/TensorFold
