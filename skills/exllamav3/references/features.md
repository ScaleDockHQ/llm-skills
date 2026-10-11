# Features: tools, reasoning, vision, structured output, LoRA, embeddings

> Verified against TabbyAPI main (docs 04, 10, config_sample.yml) and ExLlamaV3 v1.6.1, 2026-10-11

## Chat templates

TabbyAPI uses the HF chat-template standard for `/v1/chat/completions`. It reads `chat_template` from the model's `tokenizer_config.json`; override with `model.prompt_template: <file>.jinja` placed in the `templates/` directory (only affects chat message lists). Stop strings can be set in a template with `{%- set stop_strings = ["..."] -%}` (use `{%- -%}` whitespace control on top-level metadata). Template variables go in the request as `template_vars` or `chat_template_kwargs` (OpenAI-style compatibility); defaults via `model.template_vars_default`, enforced values via `model.template_vars_force`. A top-level `reasoning_effort` field also works. Admin endpoints list/switch templates (`/v1/templates`, `/v1/template/switch`, `/v1/template/unload`); `/apply-template` renders messages without generating. The `developer` role is treated as `system`.

## Tool calling

Enabled by `tool_format`; default `auto` scores each known format against the chat template markers, tokenizer special tokens and (tie-break) architecture, and warns when nothing matches. The startup log shows a `Response parsing:` line. Blank `tool_format` disables parsing. Explicit values always override detection.

| `tool_format` (aliases)                                            | Models                                                   |
| ------------------------------------------------------------------ | -------------------------------------------------------- |
| `qwen3_coder` (`qwen3_5`, `step3_5`, `step3_7`)                    | Qwen3-Coder, Qwen3-Next, Qwen3.5/3.6, Step-3.5/3.7       |
| `minimax_m2`                                                       | MiniMax-M2, M2.1, M2.5                                   |
| `glm4_5` (`glm4_6`, `glm4_7`, `laguna`, `poolside_v1`, `spark2_5`) | GLM 4.5 to 4.7, GLM 5.2/5.3, Laguna, Spark X2.5          |
| `deepseek_v4` (`dsv4`)                                             | DeepSeek-V4, V4-Flash                                    |
| `harmony`                                                          | gpt-oss-20b/120b (auto-detected)                         |
| `hy3` (`hy_v3`)                                                    | Hy3                                                      |
| `lfm2` (`lfm`, `lfm2_5`)                                           | LFM2/2.5 (use `prompt_template: lfm2.jinja`)             |
| `hermes` (`qwen3`, `qwen2_5`, `smollm3`)                           | Qwen2.5/3 original, SmolLM3, Hermes-style JSON templates |
| `kimi` (`kimi_k2`, `kimi_linear`)                                  | Kimi K2, Kimi Linear                                     |
| `olmo3` (`olmo`)                                                   | OLMo 3/3.1                                               |
| `muse_glimmer`                                                     | Muse Glimmer                                             |
| `mistral`, `mistral_old`                                           | recent Mistral family; older ones unreliable             |
| `gemma4`                                                           | Gemma 4-it                                               |

Example per-model config:

```yaml
model:
  reasoning: true
  reasoning_start_token: "<think>"
  reasoning_end_token: "</think>"
  tool_format: qwen3_5
```

Harmony and Muse Glimmer structure the whole response (reasoning, content, tool calls) and supersede `reasoning` and `tool_format` when active; override detection with `harmony: false`. Tool messages are sorted by `tool_call_id` for LFM2.

## Reasoning

`reasoning: true` (default) splits output into `reasoning_content` and `content` when tags can be inferred (auto) or are set. `start_in_reasoning` (`auto|always|never`) handles templates that open `<think>` in the prompt. `tool_calls_in_reasoning` (default true) parses tool calls inside thinking. Budget: `reasoning_budget_tokens` (per request aliases `reasoning_budget`, `thinking_budget`, `thinking_token_budget`, or `reasoning.max_tokens`) forces the end of thinking after N tokens, optionally injecting `reasoning_budget_message`. Per-model quirks: Hy3's template disables reasoning unless `reasoning_effort` (`no_think|low|high`) is sent or set in `template_vars_default`; DeepSeek-V4 accepts `enable_thinking`/`thinking_mode` and `reasoning_effort` (`low|high|max`). Sampler settings can differ while reasoning via `sampling.reasoning_override`.

## Vision

Set `model.vision: true` for models marked multimodal in the README table. `vision_offload: true` keeps vision weights in pinned RAM. `disable_fetch_requests: true` stops the server downloading image URLs. `sysmem_multimodal_cache` (1024 MB) caches encoded images across turns. Vision towers are quantized without calibration (`-vb` at conversion).

## Structured output

TabbyAPI lists "JSON schema + Regex + EBNF support" (ExLlamaV3 depends on `llguidance`). Request field names are in the autogenerated API docs (`https://theroyallab.github.io/tabbyAPI`); the OpenAI `response_format` JSON-schema form is not confirmed here, so test it against your version.

## Samplers and overrides

Requests accept the OpenAI fields plus extended samplers (min_p, repetition_penalty, banned strings, ...) documented in the API docs. Server-side defaults/overrides: `sampling.override_preset`, inline overrides, `/v1/sampling/overrides` and `/v1/sampling/override/switch` (admin). Use `force: true` to override client values.

## LoRA

`lora.lora_dir` and `lora.loras` load adapters at startup; admin endpoints `/v1/lora/load`, `/v1/lora/unload`, `/v1/loras`. For many adapters per model see `multi-lora-serving` (vLLM is the better fit). Not verified: LoRA support on every EXL3 architecture.

## Embeddings

`/v1/embeddings` through infinity-emb: needs `latest-extras` or `pip install .[extras]`, load via `embeddings.embedding_model_name` or `/v1/model/embedding/load`. Prefer `embeddings_device: cpu`; use `cuda` on AMD.

## Speculative decoding

See `performance-tuning.md` (draft models, MTP, n-gram, hybrid).

## Kobold and AI Horde

`network.api_servers: ["OAI", "Kobold"]` enables the KoboldAI-compatible API. AI Horde support is listed in the feature list; see TabbyAPI docs 07 if needed.
