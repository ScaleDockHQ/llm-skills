# Qwen parsers and templates

> Verified against vLLM recipes (Qwen3.8-27B, Qwen3.8-Flash-Next), SGLang Qwen3.8 cookbook, TensorRT-LLM Qwen3.8/3.5 deployment guide, Qwen3.8 and Qwen3.8-Flash-Next GitHub READMEs, Qwen3.8/3.6/3.5/Coder-Next/Qwen3 model cards, Unsloth Qwen3.8 guide, llama.cpp issue #27107, 2026-10-11

## Template behaviour (3.5, 3.6, 3.8)

| Topic                    | Behaviour                                                                                                                                                                                                                                                                                             |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Format                   | ChatML (`im_start` and `im_end` special tokens around each role turn). Reasoning in a `<think>` block                                                                                                                                                                                                 |
| Thinking default         | On. The template pre-injects the opening `<think>` in the generation prompt, so a reply starts inside reasoning and only `</think>` appears in the output. A reasoning parser is required to split it (vLLM Ascend note, TensorRT-LLM guide)                                                          |
| Thinking off             | `chat_template_kwargs {"enable_thinking": false}` (template prefills an empty think block per issue #236 analysis). On Qwen Cloud use top-level `"enable_thinking": false` instead                                                                                                                    |
| `reasoning_effort` (3.8) | `xhigh` (default), `medium`, `low`. Cards pass it as a top-level OpenAI parameter; the vLLM recipe sets it inside `chat_template_kwargs`; llama.cpp uses `--chat-template-kwargs '{"reasoning_effort":"medium"}'`. `medium` has no template branch of its own (injects no instruction) per issue #216 |
| `preserve_thinking`      | 3.6 (opt-in) and 3.8 (on by default): keeps thinking blocks of earlier turns in the prompt. Improves KV reuse and agent consistency, costs tokens. Disable with `chat_template_kwargs {"preserve_thinking": false}`                                                                                   |
| Tool call format         | XML-ish: `<tool_call>` containing `<function=name>` and `<parameter=key>value</parameter>` blocks. Parsed by `qwen3_coder`                                                                                                                                                                            |
| System messages          | Only one, and it must be first. A later `system` message raises `System message must be at the beginning.` (issue #244, llama.cpp #27107)                                                                                                                                                             |
| Developer role           | Not in the stock template; Unsloth GGUFs add developer-role support                                                                                                                                                                                                                                   |
| Multimodal               | Image and video parts via `image_url` and `video_url`. Video sampling: vLLM `--media-io-kwargs '{"video": {"num_frames": -1}}'` then `mm_processor_kwargs {"fps": 2, "do_sample_frames": true}`                                                                                                       |
| BOS                      | No BOS documented on these cards. The Qwen3-Omni tokenizer config shows `bos_token` null and the `im_end` token as EOS; other families unverified, read `tokenizer_config.json`                                                                                                                       |

Differences by model:

- **Qwen3.8-2.4T-A95B**: text only, thinking required (`enable_thinking` should not be turned off); every reply starts with reasoning. Hosted Qwen3.8-Max adds non-thinking and vision.
- **Qwen3-Coder-Next**: non-thinking only, no `<think>` block, `enable_thinking=False` not needed. Uses `qwen3_coder`.
- **Qwen3.5 and 3.6**: `enable_thinking` only (no `reasoning_effort` on their cards). 3.6 adds `preserve_thinking`.
- **Qwen3 (2025)**: `enable_thinking` plus `/think` and `/no_think` soft switches in user or system messages (soft switches are ignored when `enable_thinking=False`). Reply always has a think block when enabled, possibly empty. Historical turns should drop thinking content. Tool calls there use JSON inside `<tool_call>` (seen in the Qwen3-Omni template).

## Sampling (from the cards)

| Model and mode                                  | temperature | top_p      | top_k | min_p | presence_penalty | repetition_penalty |
| ----------------------------------------------- | ----------- | ---------- | ----- | ----- | ---------------- | ------------------ |
| 3.8-27B and Flash-Next, thinking                | 1.0         | 0.95       | 20    | 0.0   | 0.0              | 1.0                |
| 3.8-27B and Flash-Next, instruct (thinking off) | 0.7         | 0.80       | 20    | 0.0   | 1.5              | 1.0                |
| 3.8-2.4T-A95B (thinking only)                   | 1.0         | 0.95       | 20    | 0.0   | 0.0              | 1.0                |
| 3.6, thinking, general                          | 1.0         | 0.95       | 20    | 0.0   | 1.5              | 1.0                |
| 3.6, thinking, precise coding                   | 0.6         | 0.95       | 20    | 0.0   | 0.0              | 1.0                |
| 3.6 and 3.5, instruct                           | 0.7         | 0.8        | 20    | 0.0   | 1.5              | 1.0                |
| 3.5-397B, thinking                              | 0.6         | 0.95       | 20    | 0.0   | 0.0              | 1.0                |
| Coder-Next                                      | 1.0         | 0.95       | 40    | -     | -                | -                  |
| Qwen3 (2025), thinking / non-thinking           | 0.6 / 0.7   | 0.95 / 0.8 | 20    | 0     | optional 0 to 2  | -                  |

Notes from the cards: do not use greedy decoding (loops and degradation). Raise `presence_penalty` (0 to 2) only against endless repetition; it can cause language mixing. 3.8 output budget for agents: up to 262,144 reasoning tokens and 131,072 final tokens inside the 1M window. vLLM reads `generation_config.json` (27B ships `temperature 1.0, top_p 0.95, top_k 20`), so server defaults are already the thinking set. Cards tell you sampling support varies by engine. See `known-issues.md` for what happens at `temperature 0`.

## Engine flags

| Engine       | Reasoning                                                                                                                                                          | Tool calls                                                 | Notes                                                                                                                                                                                                                 |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM         | `--reasoning-parser qwen3`                                                                                                                                         | `--enable-auto-tool-choice --tool-call-parser qwen3_coder` | 27B needs vLLM 0.17.0+ and `transformers>=5.8.0`. Flash-Next needs vLLM 0.29.0+ and the `vllm/vllm-openai:qwen38-flash-next` image per the recipe (PyPI install "not supported" there). Coder-Next needs vLLM 0.15.0+ |
| SGLang       | `--reasoning-parser qwen3`                                                                                                                                         | `--tool-call-parser qwen3_coder`                           | 3.6 card: SGLang 0.5.10+. Coder-Next: 0.5.8+ (card uses only `--tool-call-parser qwen3_coder`). 2.4T cookbook image: `lmsysorg/sglang:qwen38`. NVFP4 27B from Unsloth needs SGLang v0.5.19                            |
| TokenSpeed   | `--reasoning-parser qwen3`                                                                                                                                         | `--enable-auto-tool-choice --tool-call-parser qwen3_coder` | Listed on the official cards next to vLLM and SGLang                                                                                                                                                                  |
| TensorRT-LLM | `--reasoning_parser qwen3_5`                                                                                                                                       | `--tool_parser qwen3`                                      | Underscore flags. Thinking toggle via request `chat_template_kwargs {"enable_thinking": false}`. Image `nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc29` in the guide                                                   |
| llama.cpp    | `--jinja --reasoning-format deepseek` (community fix for lost tool calls); `--reasoning on`, `--reasoning-budget N`, `--reasoning-preserve` appear in user reports | built from the template by the autoparser, needs `--jinja` | Qwen templates reject some inputs: see below. `--chat-template-kwargs` passes `reasoning_effort` and `enable_thinking`. Vision needs `--mmproj`                                                                       |
| Ollama       | handled by Ollama's own template                                                                                                                                   | handled by Ollama                                          | `ollama run qwen3.8`; see `platforms-and-quants.md`                                                                                                                                                                   |
| MLX          | `mlx_lm`/`mlx_vlm`                                                                                                                                                 | via chat template                                          | Community MLX; Flash-Next needs a bundled `qwen4_exp` implementation                                                                                                                                                  |
| TensorFold   | server side                                                                                                                                                        | server side                                                | Qualified paths only; see `platforms-and-quants.md`                                                                                                                                                                   |

## Copy-ready commands

vLLM, Qwen3.8-27B (card, 4 GPUs):

```bash
vllm serve Qwen/Qwen3.8-27B --port 8000 --tensor-parallel-size 4 --max-model-len 262144 \
  --reasoning-parser qwen3 --enable-auto-tool-choice --tool-call-parser qwen3_coder
```

vLLM, 27B on one GPU (recipe, H200 BF16; skip the vision encoder for text only with `--language-model-only`):

```bash
vllm serve Qwen/Qwen3.8-27B --tensor-parallel-size 1 \
  --enable-auto-tool-choice --tool-call-parser qwen3_coder --reasoning-parser qwen3 \
  --mm-encoder-tp-mode data
```

Make `reasoning_effort` safe server-wide (recipe: `--default-chat-template-kwargs`):

```bash
vllm serve Qwen/Qwen3.8-27B ... --default-chat-template-kwargs '{"reasoning_effort":"medium"}'
```

MTP speculative decoding on 3.8 (recipes): `--speculative-config '{"method":"mtp","num_speculative_tokens":3}'`. On 3.5 and 3.6 cards the method name is `qwen3_next_mtp` with `num_speculative_tokens` 2. The recipe warns to reduce the number below 3 under memory pressure.

SGLang, Qwen3.8-27B (card):

```bash
sglang serve --model-path Qwen/Qwen3.8-27B --port 8000 --tp-size 4 --context-length 262144 \
  --reasoning-parser qwen3 --tool-call-parser qwen3_coder
```

SGLang MTP on 3.6 (card): add `--speculative-algo NEXTN --speculative-num-steps 3 --speculative-eagle-topk 1 --speculative-num-draft-tokens 4`.

Flash-Next (card): the same commands with `Qwen/Qwen3.8-Flash-Next`, vLLM `--tensor-parallel-size 4`, SGLang `--tp-size 4`. Production flags are in `platforms-and-quants.md`.

TensorRT-LLM, 2.4T FP8 (guide, 16 GPUs minimum):

```bash
trtllm-serve Qwen/Qwen3.8-2.4T-A95B-FP8 --host 127.0.0.1 --port 8000 \
  --reasoning_parser qwen3_5 --tool_parser qwen3 \
  --config /app/tensorrt_llm/examples/configs/curated/qwen3.8-low-latency.yaml
```

Curated YAML files in the container: `qwen3.8-low-latency.yaml`, `qwen3.8-low-latency-mtp3.yaml`, `qwen3.8-high-throughput.yaml`, `qwen3.8-high-throughput-mtp3.yaml`. The guide binds `0.0.0.0`; bind loopback behind a gateway.

llama.cpp, Qwen3.8-27B GGUF (Unsloth guide and community reports):

```bash
llama-server -m Qwen3.8-27B-UD-Q4_K_XL.gguf --jinja --host 127.0.0.1 --port 8080 \
  --ctx-size 131072 -fa on --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 \
  --reasoning-format deepseek --chat-template-kwargs '{"reasoning_effort":"medium"}'
```

Add `--mmproj <mmproj.gguf>` for images, and `--chat-template-file fixed.jinja` if the harness sends a second system message. `ggml-org/Qwen3.8-27B-GGUF` documents `llama serve -hf ggml-org/Qwen3.8-27B-GGUF` (llama.app). Ollama: `ollama run qwen3.8`.

## YaRN to 1M tokens (cards)

Static YaRN with `factor 4.0` over 262,144 native. Only for prompts above 262,144 tokens; scale `factor` to your typical length (524,288 tokens: `2.0`).

```bash
# vLLM (27B and Flash-Next: override nested under text_config; the 2.4T recipe takes it flat)
VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 vllm serve ... --max-model-len 1000000 --hf-overrides \
  '{"text_config": {"rope_parameters": {"mrope_interleaved": true, "mrope_section": [11, 11, 10], "rope_type": "yarn", "rope_theta": 10000000, "partial_rotary_factor": 0.25, "factor": 4.0, "original_max_position_embeddings": 262144}}}'
# SGLang: SGLANG_ALLOW_OVERWRITE_LONGER_CONTEXT_LEN=1 sglang serve ... --json-model-override-args '<same JSON>' --context-length 1000000
```

3.5 and 3.6 cards use `--max-model-len 1010000`. For hour-long video set `longest_edge` to 469,762,048 in `video_preprocessor_config.json` (card).

## Sources

- https://github.com/QwenLM/Qwen3.8
- https://github.com/QwenLM/Qwen3.8-Flash-Next
- https://recipes.vllm.ai/Qwen/Qwen3.8-27B
- https://recipes.vllm.ai/Qwen/Qwen3.8-Flash-Next
- https://docs.sglang.io/cookbook/autoregressive/Qwen/Qwen3.8
- https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-qwen3.8-qwen3.5-on-trtllm.html
- https://unsloth.ai/docs/models/qwen3.8
- https://huggingface.co/Qwen/Qwen3.8-27B-FP8
- https://huggingface.co/Qwen/Qwen3.6-35B-A3B
- https://huggingface.co/Qwen/Qwen3-Coder-Next
- https://huggingface.co/Qwen/Qwen3-32B
- https://huggingface.co/ggml-org/Qwen3.8-27B-GGUF
- https://github.com/ggml-org/llama.cpp/issues/27107
- https://github.com/QwenLM/Qwen3.8/issues/216
- https://github.com/QwenLM/Qwen3.8/issues/236
- https://github.com/QwenLM/Qwen3.8/issues/244
