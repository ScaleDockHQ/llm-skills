# Features: tools, reasoning, structured output, LoRA, multimodal, embeddings, speculative decoding

> Verified against vLLM v0.31.0 (docs `features/*`, `models/pooling_models/*`, source `vllm/tool_parsers/__init__.py`, `vllm/reasoning/__init__.py`), 2026-10-11

## Tool calling

Required flags (both): `--enable-auto-tool-choice --tool-call-parser <name>`. A parser is required (source:
auto tool choice without a parser is rejected). Optional: `--chat-template <path|tool_use>` when the model's own
template does not handle `tool` role messages, `--tool-parser-plugin <file.py>` to register your own parser,
`--tool-strict-level auto|function|parameter` (v0.31.0), `--exclude-tools-when-tool-choice-none`.

Registered tool parser names in v0.31.0: `apertus`, `cohere_command3`, `cohere_command4`, `deepseek_v3`,
`deepseek_v31`, `deepseek_v32`, `deepseek_v4`, `deepseek_v41`, `dots`, `ernie45`, `functiongemma`, `gemma4`,
`gigachat3`, `glm45`, `glm47`, `granite`, `granite-20b-fc`, `granite4`, `hermes`, `hunyuan_a13b`, `hy_v3`,
`hy_v4`, `inkling`, `internlm`, `jamba`, `k2_horizon`, `kimi_k2`, `kimi_k3`, `lfm2`, `ling3`, `llama3_json`,
`llama4_json`, `llama4_pythonic`, `longcat`, `mimo`, `minicpm5`, `minimax_m2`, `minimax_m3`, `mistral`,
`muse_glimmer`, `olmo3`, `openai`, `phi4_mini_json`, `poolside_v1`, `pythonic`, `qwen3_coder`, `qwen3_xml`,
`seed_oss`, `step3`, `step3p5`, `xlam`.

Model family to parser (from the tool-calling docs):

| Model family                              | Flags                                                                                                                                   |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Qwen2.5, QwQ-32B (Hermes-style templates) | `--tool-call-parser hermes`                                                                                                             |
| Qwen3-Coder                               | `--tool-call-parser qwen3_xml`                                                                                                          |
| gpt-oss (`openai/gpt-oss-20b`, `-120b`)   | `--tool-call-parser openai` (reasoning parser is a different name, below)                                                               |
| Llama 3.1/3.2                             | `llama3_json` + `--chat-template examples/tool_chat_template_llama3.1_json.jinja` (or `3.2_json`); `pythonic` variants exist            |
| Llama 4                                   | `llama4_pythonic` + `examples/tool_chat_template_llama4_pythonic.jinja`                                                                 |
| Mistral                                   | `mistral`; some need `--tokenizer_mode hf --config_format hf --load_format hf` and `examples/tool_chat_template_mistral_parallel.jinja` |
| DeepSeek-V3 / V3.1                        | `deepseek_v3` / `deepseek_v31` + the matching `examples/tool_chat_template_deepseekv3*.jinja`                                           |
| Kimi-K2                                   | `kimi_k2`                                                                                                                               |
| GLM-4.5 / 4.7                             | `glm45` / `glm47`                                                                                                                       |
| IBM Granite                               | `granite4`, `granite`, `granite-20b-fc` (see docs for templates)                                                                        |
| Gemma 4                                   | `gemma4` (reasoning parser `gemma4`)                                                                                                    |
| Hunyuan A13B                              | `hunyuan_a13b` (+ `--reasoning-parser hunyuan_a13b` for reasoning)                                                                      |
| Models emitting Python-call lists         | `pythonic` + template                                                                                                                   |

Behaviours: `tool_choice="auto"` lets the model decide; a named function or `"required"` is enforced through
structured outputs and is always parseable (not necessarily good); `"none"` disables tools. With
`tool_choice="auto"`, structural-tag constraints apply only when a tool sets `strict: true` or
`--tool-strict-level` is `function`/`parameter`, and when `VLLM_ENFORCE_STRICT_TOOL_CALLING` is true (default).
Without that, tool calls are extracted from raw text and arguments can be malformed. vLLM does not report tool
support in `/v1/models`, so routers (llama-swap, LiteLLM) need it configured by hand.

## Reasoning

`--reasoning-parser <name>` moves thinking into the `reasoning` field of messages and streaming deltas.
**Breaking rename:** `reasoning_content` is now `reasoning`; clients reading `reasoning_content` silently see
nothing (the server still accepts `reasoning_content` in input messages and maps it).

Registered reasoning parser names in v0.31.0: `cohere_command3`, `cohere_command4`, `deepseek_r1`, `deepseek_v3`,
`deepseek_v4`, `deepseek_v41`, `ernie45`, `gemma4`, `glm45`, `glm47`, `granite`, `granite_thinking_parser`,
`holo2`, `hunyuan_a13b`, `hy_v3`, `hy_v4`, `inkling`, `k2_horizon`, `kimi_k2`, `kimi_k3`, `ling3`, `mimo`,
`minimax_m2`, `minimax_m2_append_think`, `minimax_m3`, `mistral`, `muse_glimmer`, `nemotron_v3`, `olmo3`,
`openai_gptoss`, `poolside_v1`, `qwen3`, `seed_oss`, `step3`, `step3p5`. Note gpt-oss uses `openai_gptoss`
for reasoning but `openai` for tools. QwQ-32B and DeepSeek R1 use `deepseek_r1`; Qwen3 uses `qwen3`.

Controls (all via `chat_template_kwargs`, request values override `--default-chat-template-kwargs`):

| Model                      | Behaviour                                                                |
| -------------------------- | ------------------------------------------------------------------------ |
| Qwen3 series               | thinking on by default; `enable_thinking=false` to disable               |
| IBM Granite 4.2            | on by default; `enable_thinking=false` disables                          |
| Granite 3.2, DeepSeek-V3.1 | off by default; `thinking=true` enables                                  |
| Gemma 4                    | off by default; `enable_thinking=true` or any `reasoning_effort` enables |
| Holo2                      | on by default; `thinking=false` disables                                 |
| gpt-oss                    | `reasoning_effort` low/medium/high (top-level request field)             |

`reasoning_effort` `low|medium|high` automatically injects `enable_thinking=true`; `none` injects `false`;
unset injects nothing; explicit `chat_template_kwargs` win. Other options: `include_reasoning=false` hides the
reasoning in the response (tokens are still generated); `--reasoning-config` plus per-request
`thinking_token_budget` caps reasoning tokens (Qwen3, DeepSeek, Nemotron 3); `--structured-outputs-config.enable_in_reasoning=True`
applies structured output constraints during reasoning too. Missing `--reasoning-parser` puts thoughts inside
`content`.

## Structured outputs

Backends xgrammar and guidance (default `--structured-outputs-config.backend auto`). Request body extras:

```json
{"structured_outputs": {"choice": ["positive", "negative"]}}
{"structured_outputs": {"json": {"type": "object", "properties": {"n": {"type": "integer"}}, "required": ["n"]}}}
{"structured_outputs": {"regex": "\\w+@\\w+\\.com\\n"}}
{"structured_outputs": {"grammar": "<lark or EBNF>"}}
```

`structural_tag` constrains a JSON schema between tags. OpenAI `response_format` (`json_schema`) works too.
Removed in v0.12.0: `guided_json`, `guided_regex`, `guided_choice`, `guided_grammar`,
`guided_decoding_backend`. Regex syntax depends on the backend (xgrammar, guidance, outlines: Rust-style;
lm-format-enforcer: Python `re`). Put the schema in the prompt too for best quality.

## LoRA

```bash
vllm serve meta-llama/Llama-3.2-3B-Instruct --enable-lora \
  --lora-modules sql-lora=/path/to/adapter --max-loras 4 --max-lora-rank 64
```

Adapters appear in `/v1/models`; select one with `"model": "sql-lora"`. Dynamic load/unload needs
`VLLM_ALLOW_RUNTIME_LORA_UPDATING=True`, then `POST /v1/load_lora_adapter` (`{"lora_name": ..., "lora_path": ...}`)
and `POST /v1/unload_lora_adapter`; only on trusted networks. Since v0.31.0 the LoRA path is part of the
prefix-cache block hash. Training adapters: skill `fine-tuning-llms`.

## Multimodal

Pass `image_url`, video and audio parts in chat `content`. Limit per prompt with `--limit-mm-per-prompt.image 2`
(also `video`, `audio`; `0` disables a modality, saving memory). Security: set `--allowed-media-domains`
(SSRF) and `--allowed-local-media-path` for `file://` access; per-request `mm_processor_kwargs` need
`--trust-request-mm-kwargs` (v0.31.0). Memory: `--mm-processor-cache-gb` (default 4), video token pruning
`--video-pruning-rate`/`--video-pruning-method`. Models such as Phi-3.5-vision may need `--runner generate
--trust-remote-code --max-model-len 4096`.

## Embeddings, scoring, rerank (pooling models)

```bash
vllm serve BAAI/bge-base-en-v1.5                       # embedding model: /v1/embeddings
vllm serve TIGER-Lab/VLM2Vec-Full --runner pooling     # same architecture as a generative model: force pooling
vllm serve <causal-lm> --convert embed                 # convert a text generation model (lower quality than trained embedders)
```

Endpoints: `/v1/embeddings` (OpenAI), Cohere Embed v2, `/pooling`, `/score` and `/v1/score`, `/rerank`, `/v1/rerank`,
`/v2/rerank`, classification. `dimensions` works only for Matryoshka models (`is_matryoshka` in `config.json`,
limit via `--hf-overrides '{"matryoshka_dimensions":[256]}'`); otherwise the server returns
`does not support matryoshka representation`. Run embeddings in their own server; one process serves one model.

## Speculative decoding

`--speculative-config '<json>'`; `method` is one of `ngram`, `suffix`, `draft_model`, `eagle`, `eagle3`, `medusa`,
`mlp_speculator`, `mtp` (and model-specific `*_mtp` names), `extract_hidden_states`, DFlash/DSpark types,
`custom_class`. Key fields: `model`, `num_speculative_tokens`, `draft_tensor_parallel_size`. Best at low to
medium QPS; gains shrink under load. See `references/combos/eagle3.md`. Speculative-decoding metrics are exposed
on `/metrics`; per-request acceptance metrics exist in the docs `acceptance_metrics.md`.

## Other features worth knowing

- Prefix caching (on by default), chunked prefill (on by default), CUDA graphs, `torch.compile` cache.
- Sleep mode and fast restart: `vllm preload` keeps post-quantized weights resident in GPU memory across engine
  restarts; experimental `vllm snapshot create/restore` (CRIU, TP1) (v0.31.0).
- Disaggregated prefill, KV offload, context parallel: `references/parallelism-multinode.md`.
- Batch jobs: `vllm run-batch` (OpenAI batch file format). Offline Python API: `from vllm import LLM`.
- `vllm chat` and `vllm complete` are small CLI clients; `--stats` prints TTFT and throughput.
