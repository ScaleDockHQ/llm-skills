# Mistral parsers, templates and toggles

> Verified against vLLM v0.31.0 docs and recipes.vllm.ai, SGLang v0.5.21 cookbooks, llama.cpp server README (master), Hugging Face model cards and chat templates, 2026-10-11

## Two checkpoint layouts, two tokenizers

Official Mistral repos ship a native layout (`params.json`, `consolidated-*.safetensors`, `tekken.json`) and,
for newer models, an HF layout (`config.json`, `model-*.safetensors`). vLLM documents both:

| Mode                                     | vLLM flags                                                                     | Notes                                                                                                                        |
| ---------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Mistral native (default for model cards) | `--tokenizer-mode mistral --config-format mistral --load-format mistral`       | Uses `mistral-common`. The cards' commands use the underscore spelling (`--tokenizer_mode`); both are accepted by the cards. |
| HF format                                | `--tokenizer-mode hf --config-format hf --load-format hf` plus a chat template | The NVIDIA NVFP4 Medium 3.5 card uses `--config-format hf --trust-remote-code`.                                              |

Install floors from the cards: `mistral_common >= 1.11.1` and `transformers >= 5.4.0` for Medium 3.5,
`mistral_common >= 1.11.0` for Small 4, `>= 1.8.6` for Large 3, Ministral 3 and Devstral 2. A current
`uv pip install -U vllm` pulls the right one; verify with `python -c "import mistral_common; print(mistral_common.__version__)"`.

`mistral-common` never encodes special tokens that appear in plain text. A user typing `[THINK]` or `[IMG]`
gets literal characters, not control tokens (by design, and the cause of the HF-format multimodal bug in
`known-issues.md`).

## Template tokens

| Token                                                                   | Meaning                                                                                                                                                                                 |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[AVAILABLE_TOOLS]...[/AVAILABLE_TOOLS]`                                | Tool definitions, emitted when `tools` is set                                                                                                                                           |
| `[TOOL_CALLS]`                                                          | Start of a tool call in the assistant turn                                                                                                                                              |
| `[MODEL_SETTINGS]{"reasoning_effort": "none"\|"high"}[/MODEL_SETTINGS]` | Small 4 template; the template raises `reasoning_effort must be either "none" or "high"` for anything else, and defaults to `none`                                                      |
| `[THINK]...[/THINK]`                                                    | Reasoning span (special tokens). Decode with `skip_special_tokens=False` to see it                                                                                                      |
| `[IMG]`                                                                 | Image placeholder                                                                                                                                                                       |
| `SYSTEM_PROMPT.txt`                                                     | Reference system prompt in each repo. Placeholders `{name}`, `{today}`, `{yesterday}` are filled by the client. Large 3 and Medium 3.5 chat templates inject a default if you send none |

Ministral 3 Reasoning: the card says to append Mistral's system prompt to your own, and its example splits the
prompt at `[THINK]` / `[/THINK]` into text and `thinking` chunks. Keep reasoning traces in multi-turn context
(card recommendation).

## Reasoning toggle

| Model                                     | Toggle                                        | Values                                 |
| ----------------------------------------- | --------------------------------------------- | -------------------------------------- |
| Small 4, Medium 3.5                       | per-request `reasoning_effort` (OpenAI field) | `none` (default, no reasoning), `high` |
| Ministral 3 Reasoning                     | none, always reasons                          |                                        |
| Large 3, Devstral 2, Ministral 3 Instruct | none                                          |                                        |

There are no `enable_thinking`, `/think` or `/no_think` switches. In vLLM the `reasoning_effort` request field
reaches the template; vLLM docs say it also auto-injects `enable_thinking` for templates that declare it.
Mistral templates do not, so use `reasoning_effort`.

llama.cpp: pass it as `--chat-template-kwargs '{"reasoning_effort":"high"}'` (Unsloth docs) at server start, or
per request in the request body (llama.cpp PR 26941 stores `reasoning_effort` for templates; it is closed on
2026-10-11, verify your build). SGLang takes it per request in `extra_body={"reasoning_effort": "high"}`.

## Engine flags

| Engine       | Tool calls                                                                 | Reasoning split                                                                                            | Output field                                                                           |
| ------------ | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| vLLM         | `--enable-auto-tool-choice --tool-call-parser mistral`                     | `--reasoning-parser mistral`                                                                               | `message.reasoning` (renamed from `reasoning_content` in current vLLM, update clients) |
| SGLang       | `--tool-call-parser mistral`                                               | `--reasoning-parser mistral`                                                                               | `reasoning_content`                                                                    |
| llama.cpp    | `--jinja` (enabled by default in the README) with the model's own template | `--reasoning-format` (`none`, `deepseek`, `deepseek-legacy`), `-rea on\|off\|auto`, `--reasoning-budget N` | `message.reasoning_content` when extracted                                             |
| Ollama       | handled by the library template                                            | handled by the library                                                                                     | see Ollama docs                                                                        |
| TensorRT-LLM | see `platforms-and-quants.md`                                              |                                                                                                            |                                                                                        |
| TensorFold   | not qualified for any Mistral model on 1.0.7                               |                                                                                                            |                                                                                        |

The vLLM "Supported Models" table on its reasoning page does not list Mistral, but every Mistral card and the
vLLM recipe use `--reasoning-parser mistral`. Treat the card commands as authoritative.

### vLLM, copy-ready commands (from the cards and recipe)

```bash
# Medium 3.5 on 8xH200 (recipe). Add --language-model-only for text-only workloads.
vllm serve mistralai/Mistral-Medium-3.5-128B --tensor-parallel-size 8 \
  --tokenizer_mode mistral --config_format mistral --load_format mistral \
  --enable-auto-tool-choice --tool-call-parser mistral --reasoning-parser mistral

# Small 4 (card). The NVFP4 card swaps the backend to TRITON_MLA.
vllm serve mistralai/Mistral-Small-4-119B-2603 --max-model-len 262144 --tensor-parallel-size 2 \
  --attention-backend FLASH_ATTN_MLA --tool-call-parser mistral --enable-auto-tool-choice \
  --reasoning-parser mistral --max_num_batched_tokens 16384 --max_num_seqs 128 --gpu_memory_utilization 0.8

# Large 3 (card), no reasoning parser
vllm serve mistralai/Mistral-Large-3-675B-Instruct-2512 --max-model-len 262144 --tensor-parallel-size 8 \
  --tokenizer_mode mistral --config_format mistral --load_format mistral \
  --enable-auto-tool-choice --tool-call-parser mistral

# Ministral 3 14B Reasoning (card). Drop --reasoning-parser for Instruct.
vllm serve mistralai/Ministral-3-14B-Reasoning-2512 --tensor-parallel-size 2 \
  --tokenizer_mode mistral --config_format mistral --load_format mistral \
  --enable-auto-tool-choice --tool-call-parser mistral --reasoning-parser mistral
```

Speculative decoding: the Medium 3.5 EAGLE head via
`--speculative-config '{"model":"mistralai/Mistral-Medium-3.5-128B-EAGLE","num_speculative_tokens":3,"method":"eagle","max_model_len":"65536"}'`.
Large 3 uses the same shape with `mistralai/Mistral-Large-3-675B-Instruct-2512-Eagle` and `"max_model_len": "16384"`.
Small 4 has `mistralai/Mistral-Small-4-119B-2603-eagle`.

Useful vLLM flags from the Medium 3.5 recipe: `--language-model-only` (skip the vision encoder),
`--mm-encoder-tp-mode data`, `--limit-mm-per-prompt.image N`, `--max-model-len` (default 262144; lower to free KV).

### SGLang

```bash
python -m sglang.launch_server --model-path mistralai/Mistral-Medium-3.5-128B --tp 4 \
  --tool-call-parser mistral --reasoning-parser mistral
# EAGLE: add --dtype bfloat16 --speculative-algorithm EAGLE \
#   --speculative-draft-model-path mistralai/Mistral-Medium-3.5-128B-EAGLE \
#   --speculative-num-steps 3 --speculative-eagle-topk 1 --speculative-num-draft-tokens 4
```

`--dtype bfloat16` is required with the EAGLE draft (the draft `params.json` lacks a dtype, so `auto` falls back
to fp32 then fp16 and conflicts with the bf16 target). Devstral 2 card: `--tp 8 --tool-call-parser mistral` and no
reasoning parser. Cookbooks exist for Ministral 3, Small 4, Medium 3.5 and Devstral 2.

### llama.cpp

```bash
llama-server -hf unsloth/Mistral-Small-4-119B-2603-GGUF:UD-Q4_K_M --jinja --temp 0.7 \
  --chat-template-kwargs '{"reasoning_effort":"high"}'
llama-server -hf unsloth/Mistral-Medium-3.5-128B-GGUF:UD-Q4_K_XL --temp 0.7 \
  --chat-template-kwargs '{"reasoning_effort":"none"}'
```

Use the template embedded in the GGUF and Unsloth's fixed templates. Official Mistral GGUFs exist only for
Ministral 3 (Instruct and Reasoning). If a template fails with `Failed to generate tool call example`, the
template uses a construct `minja` does not support; supply a compatible one with `--chat-template-file`
(llama.cpp issue 15930, a Mistral Small 2506 case).

## Sampling from the cards

| Model                         | Settings                                                                                                                                      |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Small 4                       | `reasoning_effort=high`: temperature 0.7. `none`: temperature 0.0 to 0.7 depending on task (card examples use 0.1)                            |
| Medium 3.5                    | `high`: temperature 0.7, top_p 0.95. `none`: temperature 0.0 to 0.7, leave top_p unset or 1.0. NVIDIA's NVFP4 card benchmarks with 0.7 / 0.95 |
| Large 3                       | temperature below 0.1 for production (card examples use 0.15). Few, well-defined tools; images close to 1:1 aspect                            |
| Ministral 3 Instruct          | temperature below 0.1 (GGUF card)                                                                                                             |
| Ministral 3 Reasoning         | card text says temperature 1 for most environments; its code examples use 0.7 and top_p 0.95. The two disagree, test both                     |
| Devstral 2, Devstral Small 2  | card examples use temperature 0.15                                                                                                            |
| Magistral Small 2509 (legacy) | temperature 0.7, top_p 0.95, max_tokens 131072                                                                                                |

Unsloth adds: keep repetition and presence penalties off (1.0) unless you see looping, and max context 262,144.

## Sources

- https://docs.vllm.ai/en/latest/features/tool_calling/
- https://docs.vllm.ai/en/latest/features/reasoning_outputs/
- https://recipes.vllm.ai/mistralai/Mistral-Medium-3.5-128B
- https://docs.sglang.io/cookbook/autoregressive/Mistral/Mistral-Medium-3.5
- https://docs.sglang.io/cookbook/autoregressive/Mistral/Mistral-Small-4
- https://github.com/ggml-org/llama.cpp/tree/master/tools/server
- https://github.com/ggml-org/llama.cpp/pull/26941
- https://github.com/ggml-org/llama.cpp/issues/15930
- https://unsloth.ai/docs/models/mistral-3.5
- https://huggingface.co/unsloth/Mistral-Small-4-119B-2603-GGUF
- https://huggingface.co/mistralai/Mistral-Small-4-119B-2603-NVFP4/blob/main/chat_template.jinja
- https://huggingface.co/mistralai/Mistral-Medium-3.5-128B
- https://huggingface.co/mistralai/Mistral-Large-3-675B-Instruct-2512
- https://huggingface.co/mistralai/Ministral-3-14B-Reasoning-2512
- https://huggingface.co/mistralai/Devstral-2-123B-Instruct-2512
- https://huggingface.co/mistralai/Magistral-Small-2509
