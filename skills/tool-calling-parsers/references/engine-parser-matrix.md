# Tool-calling parsers: per-engine flags and parser names

> Verified against vLLM v0.31.0 (docs: features/tool_calling; vllm/tool_parsers/**init**.py), SGLang v0.5.21 (docs: advanced_features/tool_parser; srt/function_call/parser_names.py), TensorRT-LLM v1.2.1 and docs main (commands/trtllm-serve), llama.cpp v0.6.0 (docs/function-calling.md, tools/server/README.md), Ollama v0.40.3 (docs: capabilities/tool-calling, api/openai-compatibility), TensorFold v1.0.7 (docs/api.md), TabbyAPI main (docs/10.-Tool-Calling.md, docs/02.-Server-options.md), 2026-10-11

Names below are copied from upstream. Parser lists change between releases: confirm against the installed binary (`vllm serve --help=all`, `python -m sglang.launch_server --help`, `trtllm-serve --help`).

## Flag matrix

| Engine               | Enable tool calling                                                    | Parser selection                                                  | Template                                                                                            | Notes                                                                                                       |
| -------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| vLLM                 | `--enable-auto-tool-choice` (mandatory for `tool_choice: auto`)        | `--tool-call-parser NAME`; `--tool-parser-plugin PATH` for custom | `--chat-template PATH` (optional; `tool_use` uses the model's tokenizer-config tool template)       | `required`, named and `none` choices work without the flags                                                 |
| SGLang               | `--tool-call-parser NAME`                                              | `--tool-call-parser auto` detects from the chat template          | `--chat-template PATH`                                                                              | `tool_choice` `required` and named use EBNF; "fully supported" with xgrammar, maybe not with other backends |
| TensorRT-LLM         | `trtllm-serve --tool_parser NAME` (prototype)                          | `--tool_parser auto` resolves from the model type                 | `--chat_template`; `--allow_request_chat_template` for per-request templates (trusted clients only) | Fails with "Cannot auto-detect tool parser" for unsupported model types                                     |
| llama.cpp            | built in; `--jinja` (default enabled, `--no-jinja` disables)           | none: parser follows the chat template's format                   | `--chat-template-file FILE`, `--chat-template NAME`, `--chat-template-kwargs JSON`                  | Falls back to a Generic format when the template is not recognized (`Chat format: Generic` in logs)         |
| Ollama               | pass `tools` per request on a tool-capable model                       | none documented                                                   | model's own                                                                                         | OpenAI-compatible `/v1/chat/completions`: `tools` yes, `tool_choice` not supported                          |
| TensorFold           | built in; `tools`, `tool_choice`, `parallel_tool_calls` request fields | none: follows the checkpoint's chat template markup               | `--chat-template FILE`                                                                              | Qwen XML tool parameters typed from the offered schema                                                      |
| ExLlamaV3 (TabbyAPI) | `tool_format` in model config (default `auto`)                         | `tool_format: NAME`, blank disables parsing                       | `prompt_template`, `template_vars_default`                                                          | Startup log has a `Response parsing:` line                                                                  |

## vLLM parser names (v0.31.0 registry, in upstream order)

`dots`, `deepseek_v3`, `deepseek_v31`, `deepseek_v32`, `deepseek_v4`, `deepseek_v41`, `cohere_command3`, `cohere_command4`, `ernie45`, `glm45`, `glm47`, `ling3`, `granite-20b-fc`, `granite`, `granite4`, `hermes`, `poolside_v1`, `hunyuan_a13b`, `hy_v3`, `hy_v4`, `internlm`, `jamba`, `lfm2`, `kimi_k2`, `kimi_k3`, `k2_horizon`, `llama3_json`, `llama4_json`, `llama4_pythonic`, `longcat`, `mimo`, `minimax_m2`, `minimax_m3`, `minicpm5`, `mistral`, `olmo3`, `muse_glimmer`, `openai`, `phi4_mini_json`, `pythonic`, `qwen3_coder`, `qwen3_xml`, `seed_oss`, `step3`, `step3p5`, `inkling`, `xlam`, `gigachat3`, `functiongemma`, `gemma4`, `apertus`.

The docs also describe `--tool-call-parser hf` (reads the checkpoint's `response_template` from `tokenizer_config.json`; use with `--reasoning-parser hf`; startup fails if the template lacks `thinking` or `tool_calls`; rejects strict tools, required or named tool choice and `parallel_tool_calls=false`). `hf` is not in the registry map read above, so confirm it with `--help` before relying on it.

Documented model-to-parser pairings (vLLM docs):

| Parser                                | Models and flags                                                                                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hermes`                              | Hermes 2 Pro, Hermes 3, Qwen2.5, QwQ-32B. Hermes 2 Theta has degraded tool quality                                                                            |
| `mistral`                             | Mistral-7B-Instruct-v0.3 and other Mistral function-calling models; see the format flags below                                                                |
| `llama3_json`                         | Llama 3.1, 3.2 (also documented for 4); `--chat-template examples/tool_chat_template_llama3.1_json.jinja` (or `llama3.2_json`); no parallel calls on Llama 3  |
| `llama4_pythonic`                     | Llama 4 (recommended over JSON); `--chat-template examples/tool_chat_template_llama4_pythonic.jinja`                                                          |
| `pythonic`                            | Llama 3.2 small models (with `tool_chat_template_llama3.2_pythonic.jinja`), Llama 4, ToolACE-8B; the model must not mix text and tool calls in one generation |
| `granite4`                            | Granite 4.0 models. `granite` for Granite 3.0 (with `tool_chat_template_granite.jinja`) and 3.1; `granite-20b-fc` for granite-20b-functioncalling             |
| `internlm`                            | internlm2.5 chat; `--chat-template examples/tool_chat_template_internlm2_tool.jinja`                                                                          |
| `jamba`                               | AI21 Jamba-1.5 Mini and Large                                                                                                                                 |
| `xlam`                                | Salesforce xLAM models; `tool_chat_template_xlam_llama.jinja` or `_qwen.jinja`                                                                                |
| `deepseek_v3`                         | DeepSeek-V3-0324 (`tool_chat_template_deepseekv3.jinja`), DeepSeek-R1-0528 (`tool_chat_template_deepseekr1.jinja`)                                            |
| `deepseek_v31`                        | DeepSeek-V3.1 (`tool_chat_template_deepseekv31.jinja`)                                                                                                        |
| `openai`                              | gpt-oss-20b, gpt-oss-120b                                                                                                                                     |
| `kimi_k2`                             | Kimi-K2-Instruct                                                                                                                                              |
| `hunyuan_a13b`                        | Hunyuan-A13B-Instruct; with reasoning add `--reasoning-parser hunyuan_a13b`                                                                                   |
| `cohere_command3` / `cohere_command4` | Cohere Command A Reasoning / Command A Plus; needs the `cohere_melody` package; `--reasoning-parser` of the same name                                         |
| `longcat`                             | LongCat-Flash-Chat (and FP8)                                                                                                                                  |
| `glm45`                               | GLM-4.5, GLM-4.5-Air, GLM-4.6                                                                                                                                 |
| `glm47`                               | GLM-4.7, GLM-4.7-Flash                                                                                                                                        |
| `functiongemma`                       | google/functiongemma-270m-it; `--chat-template examples/tool_chat_template_functiongemma.jinja`; meant to be fine-tuned                                       |
| `qwen3_xml`                           | Qwen3-Coder models (docs name this parser for Qwen3-Coder; `qwen3_coder` also exists in the registry)                                                         |
| `mimo`                                | MiMo-V2.6 Pro and Flash RL; also `--reasoning-parser mimo --enable-auto-tool-choice`                                                                          |
| `step3p5`                             | Step-3.5 and Step-3.7 Flash; also `--reasoning-parser step3p5`                                                                                                |
| `olmo3`                               | Olmo-3-7B-Instruct, Olmo-3-32B-Think                                                                                                                          |
| `gigachat3`                           | GigaChat3 models (template from the HF files)                                                                                                                 |
| `apertus`                             | Apertus-8B/70B-Instruct-2509; `--chat-template` the examples `tool_chat_template_apertus.jinja`                                                               |

Mistral formats (vLLM docs): official format `--tool-call-parser mistral` (default tokenizer mode `auto`/`mistral`, uses mistral-common: `--tokenizer_mode mistral --config_format mistral --load_format mistral`); Transformers format `--tokenizer_mode hf --config_format hf --load_format hf --tool-call-parser mistral --chat-template examples/tool_chat_template_mistral_parallel.jinja`. With the Transformers tokenizer the stock template needs 9-digit tool-call IDs, hence the example templates.

vLLM behavior to know:

- `tool_choice: required` or a named function uses structured outputs, so it is "a validly-parsable function call, not a high-quality one", and the first use pays a grammar compile.
- `tool_choice: auto` is unconstrained unless a tool sets `strict: true` or the server sets `--tool-strict-level function|parameter` (default `auto`). `VLLM_ENFORCE_STRICT_TOOL_CALLING=false` turns the structural tags off. Define strict schemas OpenAI style: `additionalProperties: false`, all fields required, optional fields nullable.
- `--exclude-tools-when-tool-choice-none` drops tool definitions from the prompt when `tool_choice` is `none`.
- With a reasoning parser, tool calls are parsed only from `content`, not from `reasoning`.
- Plugin parsers: `--tool-parser-plugin <absolute path>` registers names for `--tool-call-parser`.

## SGLang parser names (v0.5.21 `TOOL_CALL_PARSER_NAMES`)

`auto` (detect from chat template), `apertus2509`, `cohere_command4`, `deepseekv3`, `deepseekv31`, `deepseekv32`, `deepseekv4`, `deepseekv41`, `dots`, `glm`, `glm45`, `glm47`, `gpt-oss`, `k2_horizon`, `kimi_k2`, `kimi_k3`, `lfm2`, `ling3`, `llama3`, `mimo`, `minicpm5`, `mistral`, `muse`, `poolside_v1`, `pythonic`, `qwen`, `qwen25`, `qwen3_coder`, `spark25`, `step3`, `step3p5`, `minimax-m2`, `minimax-m3`, `nanbeige`, `trinity`, `interns1`, `hermes`, `hunyuan`, `gigachat3`, `gigachat35`, `gemma4`, `inkling`, `iquest_q1`.

Docs pairings: `deepseekv3` (DeepSeek-V3-0324; template `tool_chat_template_deepseekv3.jinja`), `deepseekv31` (V3.1 and V3.2-Exp; template `..._deepseekv31.jinja` or `..._deepseekv32.jinja`), `deepseekv32` (V3.2), `glm` (GLM-4.6; GLM-4.5/4.6 use `glm45` and GLM-4.7 uses `glm47` in the GLM cookbook), `gpt-oss`, `kimi_k2`, `llama3` (3.1, 3.2, 3.3), `mistral`, `pythonic` (Llama 3.2/3.3/4; use the matching chat template), `qwen` (Qwen series except Qwen3-Coder, for example Qwen3-Next and Qwen3-VL), `qwen3_coder`, `qwen25` (Qwen2.5 in the docs example), `step3`. The docs table also lists `llama4`, which is not in the v0.5.21 choices; use `pythonic` for Llama 4 and trust `--help`.

SGLang behavior: the `gpt-oss` parser filters analysis-channel events and keeps only normal text, so content can be empty; complete the tool round by sending the tool result as a `role: "tool"` message. `tool_choice` `required` and named function are implemented with EBNF and are fully supported with xgrammar. `SGLANG_TOOL_STRICT_LEVEL` is an integer env var (`0` off default, `1` function, `2` parameter).

## TensorRT-LLM parser names

Release v1.2.1 (`--tool_parser`): `qwen3`, `qwen3_coder`, `kimi_k2`, `deepseek_v3`, `deepseek_v31`, `deepseek_v32`.

Docs main (newer than v1.2.1): `auto`, `qwen3`, `qwen3_coder`, `kimi_k2`, `kimi_k3`, `deepseek_v3`, `deepseek_v31`, `deepseek_v32`, `deepseek_v4`, `gemma4`, `glm4`, `glm47`, `minimax_m2`, `minimax_m3`, `poolside_v1`.

`--tool_parser auto` maps model types to parsers; an earlier main revision listed auto-detection for qwen2, qwen3, qwen3_moe, qwen3_5, qwen3_5_moe, qwen3_next, deepseek_v3, deepseek_v32, kimi_k2, kimi_k25 and glm4. Parser options are `prototype` stability. The gpt-oss example in the repo calls the chat API with `tools` and reads `message.reasoning` and `message.tool_calls`; the option list has no gpt-oss tool parser name, and how it is enabled is not verified here.

## llama.cpp (v0.6.0)

- Tool calls go through `/v1/chat/completions` with the OpenAI `tools` array; the server parses the model's native format. `parse_tool_calls` and `parallel_tool_calls` are request fields; parallel calls are disabled by default ("only supported on some models, verification is based on jinja template"). Anthropic Messages tool use also requires `--jinja`.
- Native formats listed upstream: Llama 3.1 / 3.3 (including builtin tools) and 3.2, Functionary v3.1 / v3.2, Hermes 2/3 and Qwen 2.5, Qwen 2.5 Coder, Mistral Nemo, Firefunction v2, Command R7B, DeepSeek R1 ("WIP / seems reluctant to call any tools?"), GPT-OSS (Harmony), LLM-jp-4.1 (Harmony dialect). Anything else uses the Generic handler, which "may consume more tokens and be less efficient".
- Check the template: `curl -s http://127.0.0.1:8080/props | jq .chat_template` and the startup log. Override with `--chat-template-file`; worst case `--chat-template chatml`. Upstream ships `models/templates/llama-cpp-deepseek-r1.jinja` for R1 distills.
- Caution from upstream: extreme KV quantization (for example `-ctk q4_0`) "can substantially degrade the model's tool calling performance".
- `--skip-chat-parsing` forces a pure content parser: reasoning and tool calls stay in `content`.
- Server tools (`--tools`, `--agent`) are a different feature (built-in file and shell tools for the Web UI); never enable them on a shared endpoint.

## Ollama (v0.40.3)

- Native API `/api/chat`: request `tools`; response `message.tool_calls`; return the tool results with the follow-up request, as in the upstream examples. Parallel calls, agent loops and streaming (collect `thinking`, `content` and `tool_calls` chunks, then return them together) are documented. `think` can be combined with tools.
- OpenAI-compatible API: `tools` supported; `tool_choice` is listed as not supported; `logit_bias`, `n`, `user` also not.
- No parser or template flag is documented; tool support depends on the model.

## TensorFold (v1.0.7)

- Request fields (both backends): `tools`, `tool_choice` (`none` hides tools from the template; `required` or a named function makes the reply call a tool), `parallel_tool_calls` (false returns at most one completed call).
- A reply that is not a call returns as content; a well-formed call to an unoffered tool is returned under its name so the client can report it. Qwen XML tool parameters take their types from the offered schema (arrays, objects, booleans, integers, numbers, nulls).
- `required` and named calls are enforced as a grammar on the engines that support structured output (see the `structured-outputs` skill); a grammar sent together with them is HTTP 400.
- A tool call written before the think block closes counts as the reply's tool call when the reply ends inside the block.

## ExLlamaV3 / TabbyAPI (main)

`tool_format` values (aliases in parentheses): `qwen3_coder` (`qwen3_5`, `step3_5`, `step3_7`), `minimax_m2`, `glm4_5` (`glm4_6`, `glm4_7`, `laguna`, `poolside_v1`, `spark2_5`), `deepseek_v4` (`dsv4`), `harmony`, `hy3` (`hy_v3`), `lfm2` (`lfm`, `lfm2_5`), `hermes` (`qwen3`, `qwen2_5`, `smollm3`), `kimi` (`kimi_k2`, `kimi_linear`), `olmo3` (`olmo`), `muse_glimmer` (`glimmer`), `mistral_old`, `mistral`, `gemma4`.

- Default `auto` scores every format against the chat template markers, tokenizer special tokens and architecture and picks the unique best match; if none matches a template that defines tools, the server warns and does not parse tool calls.
- Harmony (gpt-oss) and Muse Glimmer formats are detected from special tokens and supersede `reasoning` and `tool_format`; set `harmony: false` to override.
- Related keys: `reasoning`, `reasoning_start_token`, `reasoning_end_token`, `tool_calls_in_reasoning` (default true). Older Mistral-family models "tend to have unreliable tool calling support".

## Official links

- vLLM: https://docs.vllm.ai/en/latest/features/tool_calling/ and https://github.com/vllm-project/vllm/blob/v0.31.0/vllm/tool_parsers/__init__.py
- SGLang: https://docs.sglang.ai/advanced_features/tool_parser.html and https://github.com/sgl-project/sglang/blob/v0.5.21/python/sglang/srt/function_call/parser_names.py
- TensorRT-LLM: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- llama.cpp: https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md
- Ollama: https://docs.ollama.com/capabilities/tool-calling and https://docs.ollama.com/api/openai-compatibility
- TensorFold: https://github.com/ashhart/TensorFold/blob/main/docs/api.md
- TabbyAPI: https://github.com/theroyallab/tabbyAPI/blob/main/docs/10.-Tool-Calling.md
