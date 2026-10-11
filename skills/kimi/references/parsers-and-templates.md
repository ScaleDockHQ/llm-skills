# Kimi: chat templates, parsers and reasoning toggles

> Verified against vLLM recipes (Kimi-K3, Kimi-K2.6) and vLLM kimi_k3 parser docs, vLLM K3 blog 2026-07-27, SGLang cookbook (Kimi-K2, K2.5, K3) and PR 33025, llama.cpp commit ad1de39 (Kimi-K3), TensorRT-LLM supported-models and Kimi K3 deployment guide, Unsloth Kimi K2.6/K3 pages, Kimi K3/K2.7-Code/K2.6 model cards, TensorFold v1.0.7 README, 2026-10-11

## Parser names per engine

| Model                                           | vLLM `--tool-call-parser` / `--reasoning-parser` | SGLang `--tool-call-parser` / `--reasoning-parser`                         |
| ----------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------- |
| K3                                              | `kimi_k3` / `kimi_k3`                            | `kimi_k3` / `kimi_k3` (also auto-detected from the model config, PR 33025) |
| K2.7-Code, K2.6, K2.5, K2-Thinking, K2-Instruct | `kimi_k2` / `kimi_k2`                            | `kimi_k2` / `kimi_k2` (reasoning parser only for the thinking models)      |
| Kimi-Linear, Kimi-VL                            | no Kimi-specific parser documented (unverified)  | not documented (unverified)                                                |

Always add `--enable-auto-tool-choice` on vLLM and `--trust-remote-code` for every Kimi checkpoint. The K3 vLLM parsers split three output channels (think, response, tools) into `reasoning_content`, `content` and `tool_calls`.

vLLM may expose the thinking text as `reasoning` instead of `reasoning_content` (the K2.7-Code card notes some APIs only support `reasoning`). Read both in clients.

### vLLM commands from upstream recipes

K3 on 8 GPUs (recipe, text and vision, 1M context):

```bash
vllm serve moonshotai/Kimi-K3 \
  --trust-remote-code --tensor-parallel-size 8 \
  --load-format fastsafetensors --enable-prefix-caching \
  --enable-auto-tool-choice --tool-call-parser kimi_k3 --reasoning-parser kimi_k3
```

The full recipe adds `--kv-cache-dtype fp8`, `--max-model-len 1048576`, `--attention-backend TOKENSPEED_MLA`, `--gpu-memory-utilization 0.95` and env `VLLM_USE_RUST_FRONTEND=1`. Per the vLLM blog only Docker images are usable for K3 today (pre-release FlashInfer dependency); use the image from https://recipes.vllm.ai/moonshotai/Kimi-K3 . Pass `--enable-prefix-caching` explicitly: it is off by default for K3.

K2.6 (recipe, 8x H200 INT4 verified):

```bash
vllm serve moonshotai/Kimi-K2.6 --trust-remote-code --tensor-parallel-size 8 \
  --tool-call-parser kimi_k2 --enable-auto-tool-choice --reasoning-parser kimi_k2 \
  --mm-encoder-tp-mode data
```

Add `--speculative-config '{"model":"lightseekorg/kimi-k2.6-eagle3-mla","method":"eagle3","num_speculative_tokens":3}'` for EAGLE3 (recipe). K2.6 recipe requires vLLM >= 0.25.0 for the B300 EAGLE3 and CPU KV offload paths. K2.5 tool-parser fixes need vLLM >= 0.20.0.

K3 speculative decoding (vLLM, `Inferact/Kimi-K3-DSpark`):

```bash
--speculative-config '{"model":"Inferact/Kimi-K3-DSpark","method":"dspark","num_speculative_tokens":7,"attention_backend":"FLASHINFER_MLA","draft_sample_method":"probabilistic","rejection_sample_method":"block"}'
```

TensorRT-LLM states K3 has no MTP or EAGLE-3 head; use DSpark there.

### SGLang commands from the cookbook

```bash
# K2.x thinking model
python -m sglang.launch_server --model moonshotai/Kimi-K2-Thinking \
  --reasoning-parser kimi_k2 --tool-call-parser kimi_k2 --tp 8 --trust-remote-code
# K3 (cookbook single-node template, text context capped at 65536)
sglang serve --trust-remote-code --model-path moonshotai/Kimi-K3 --tp-size 8 \
  --context-length 65536 --reasoning-parser kimi_k3 --tool-call-parser kimi_k3
```

The cookbook K3 recipes depend on hardware (B300 1x8, GB300 2x4, B200 2x8, GB200 4x4, H200 2x8, H100 4x8, MI35x 1x8) and use `--mamba-full-memory-ratio` sized by a calculator; start from https://docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K3 rather than hand-building flags. For the NVFP4 checkpoint use image `lmsysorg/sglang:dev-dev-kimi-k3-nvfp4`. K2.5 EAGLE3 draft: `lightseekorg/kimi-k2.5-eagle3`.

### llama.cpp

| Model            | Command (from Unsloth pages)                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| K2.6 / K2.7-Code | `llama-cli -hf unsloth/Kimi-K2.6-GGUF:UD-Q2_K_XL --temp 1.0 --top-p 0.95`; vision adds `--mmproj .../mmproj-F16.gguf`                            |
| K2.6 instant     | add `--temp 0.6 --chat-template-kwargs '{"enable_thinking":false}'`                                                                              |
| K3               | `llama-cli -hf unsloth/Kimi-K3-GGUF:UD-IQ1_S --temp 1.0 --top-p 0.95`; vision needs `--mmproj .../mmproj-BF16.gguf` and Unsloth's llama.cpp fork |

The Unsloth K2.6 repo notes chat-template fixes and says to use `--jinja` with llama.cpp. The K3 text model landed upstream in llama.cpp (commit ad1de39, PR 26185, template `models/templates/Kimi-K3.jinja`, reasoning and tool calls verified by the author); Unsloth builds its fork (PR branch `kimi-k3-fullsize-vision`) for vision and bug fixes. `--reasoning-format` behaviour for Kimi is not documented in the pages read: unverified, test it. See the `llama-cpp` skill for server flags.

Kimi-Linear is supported upstream in llama.cpp (arch `kimi-linear`, PR 18755 merged); Kimi-VL has `ggml-org/Kimi-VL-A3B-Thinking-2506-GGUF` with mmproj.

### TensorRT-LLM

| Architecture class                                         | Models    | Notes                                                                                                                                 |
| ---------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `DeepseekV3ForCausalLM`                                    | Kimi-K2   | NVFP4 guide: `trtllm-serve nvidia/Kimi-K2-Thinking-NVFP4 --config <yaml>` (Blackwell)                                                 |
| `KimiK25ForConditionalGeneration`                          | Kimi-K2.5 | listed in supported models; K2.6 and K2.7-Code (same `kimi_k25` arch) are not listed: unverified                                      |
| `KimiK3ForConditionalGeneration` + `KimiLinearForCausalLM` | Kimi-K3   | Blackwell (SM100) only; built from source; TEP16 validated on GB200, DEP16 and TEP8 need GB300-class memory; checkpoint already MXFP4 |

### TensorFold

Not qualified. The v1.0.7 README qualified list contains no Kimi model; it names Nemotron, Qwen3.8, GLM-5.3-Flash and Qwen3.5-2B only. Say "no upstream support found" and use vLLM, SGLang or llama.cpp. See the `tensorfold` skill.

### Ollama

All Kimi K2.6, K2.7-Code and K3 entries observed in the Ollama library are `:cloud` tags (requests go to Ollama's hosted service, nothing runs locally). `kimi-k2.5` was retired on 2026-07-31. For local GGUF loading Ollama needs a `Modelfile`; K3's GGUF arch support is in llama.cpp but Ollama local support for K3 was not found. See the `ollama` skill.

## Chat template and format quirks

| Topic                   | K3                                                                                                                                | K2.x (K2 to K2.7-Code)                                                                        |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Template                | Not a Jinja template: a Python render program emits exact control tokens (XTML). llama.cpp ships a Jinja port.                    | Jinja chat template in the repo (`apply_chat_template`)                                       |
| Channels                | `<                                                                                                                                | open                                                                                          | >think< | sep | >`, `< | open | >response< | sep | >`, `< | open | >tools< | sep | >` regions | Tool calls between `< | tool_calls_section_begin | >`and`< | tool_calls_section_end | >`, each `< | tool_call_begin | >`...`< | tool_call_end | >`  |
| System prompt           | Optional; messages may carry their own tools (SGLang accepts system/developer-level tools)                                        | Card default: "You are Kimi, an AI assistant created by Moonshot AI."                         |
| Thinking history        | Trained in preserved-thinking mode: return the whole assistant message (`reasoning_content` and `tool_calls`) on every later turn | Interleaved thinking with tool calls; K2.6 `preserve_thinking` is opt-in; K2.7-Code forces it |
| Reasoning in raw text   | Split by the `kimi_k3` parser                                                                                                     | Split by the `kimi_k2` parser                                                                 |
| Tool call IDs           | Native IDs (SGLang preserves them)                                                                                                | Not documented in the pages read                                                              |
| Structured/forced tools | vLLM and SGLang use XGrammar structural tags for `required`/named tool choice                                                     | vLLM routes `required`/named through a Kimi-native structural tag (PR 45003)                  |

Kimi-VL-Thinking-2506 wraps thinking in `◁think▷ ... ◁/think▷`; the card parses it client-side and plans for up to 32,768 generated tokens at temperature 0.8.

## Reasoning toggles

| Goal                       | Official API                                                               | vLLM / SGLang                                                                                             | llama.cpp (Unsloth)                                  |
| -------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| K3 effort                  | top-level `reasoning_effort`: `"low"`, `"high"`, `"max"` (default `"max"`) | same top-level `reasoning_effort` request field (K3 card, SGLang cookbook)                                | Unsloth Studio exposes low/high/max                  |
| K3 instant                 | not supported                                                              | not supported                                                                                             | not supported                                        |
| K2.6/K2.5 instant          | `extra_body={'thinking': {'type': 'disabled'}}`                            | `extra_body={'chat_template_kwargs': {"thinking": False}}`                                                | `--chat-template-kwargs '{"enable_thinking":false}'` |
| K2.6 keep thinking history | `extra_body={'thinking': {'type': 'enabled', 'keep': 'all'}}`              | `chat_template_kwargs {"thinking": true, "preserve_thinking": true}` (card recommends only in think mode) | n/a                                                  |
| K2.7-Code                  | thinking and preserve both forced                                          | instant not supported                                                                                     | thinking only                                        |

The key names differ between engines (`thinking` for vLLM/SGLang, `enable_thinking` for llama.cpp per Unsloth). Confirm on a test request that `reasoning_content` is empty after toggling.

## Recommended sampling (from cards)

| Model                 | Thinking                                                   | Instant                     | Notes                                                                        |
| --------------------- | ---------------------------------------------------------- | --------------------------- | ---------------------------------------------------------------------------- |
| K3                    | temperature 1.0, top_p 0.95 single-step; top_p 1.0 agentic | n/a                         | benchmark runs used `reasoning_effort` max                                   |
| K2.7-Code             | temperature 1.0, top_p 0.95                                | n/a                         | card for third-party vLLM/SGLang                                             |
| K2.6, K2.5            | temperature 1.0, top_p 0.95                                | temperature 0.6, top_p 0.95 |                                                                              |
| K2-Thinking           | temperature 1.0                                            | n/a                         | system prompt above is a good default                                        |
| K2-Instruct-0905      | n/a                                                        | temperature 0.6             | Anthropic-compatible API maps `real_temperature = request_temperature * 0.6` |
| Kimi-VL-Thinking-2506 | temperature 0.8                                            | n/a                         | max 32,768 new tokens in the card example                                    |

Give thinking models a generous `max_tokens`: vLLM notes that a low eval score is more often a truncated answer than a wrong one.

## Other engine requirements

- `transformers` for K2.5, K2.6, K2.7-Code: `>=4.57.1, <5.0.0` (K2.6 and K2.7-Code cards).
- Kimi-Linear HF path: `python >= 3.10`, `torch >= 2.6`, `fla-core >= 0.4.0`. vLLM serve example in the card: `--tensor-parallel-size 4 --max-model-len 1048576 --trust-remote-code`.
- Kimi-VL-Thinking-2506 card pins `vllm==0.9.1` and says to install `flash-attn` explicitly to avoid CUDA OOM (card text from 2025; newer vLLM lists `KimiVLForConditionalGeneration` as supported).
- vLLM supported-models page lists `KimiLinearForCausalLM`, `KimiK25ForConditionalGeneration`, `KimiK3ForConditionalGeneration` and `KimiVLForConditionalGeneration`.

## Sources

- https://recipes.vllm.ai/moonshotai/Kimi-K3 , https://recipes.vllm.ai/moonshotai/Kimi-K2.6
- https://github.com/vllm-project/vllm-project.github.io/blob/main/_posts/2026-07-27-k3.md
- https://docs.vllm.ai/en/latest/api/vllm/reasoning/kimi_k3_reasoning_parser/ , https://docs.vllm.ai/en/latest/api/vllm/tool_parsers/kimi_k3_tool_parser/
- https://docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K3 , https://docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K2 , https://github.com/sgl-project/sgl-cookbook/blob/main/docs/autoregressive/Moonshotai/Kimi-K2.5.md , https://github.com/sgl-project/sglang/pull/33025
- https://github.com/ggml-org/llama.cpp/commit/ad1de39e0708e3ced9c71bb3c82d93a2c046a73f , https://github.com/ggml-org/llama.cpp/pull/18755
- https://unsloth.ai/docs/models/kimi-k3 , https://unsloth.ai/docs/models/kimi-k2.6
- https://nvidia.github.io/TensorRT-LLM/latest/models/supported-models.html , https://nvidia.github.io/TensorRT-LLM/deployment-guide/deployment-guide-for-kimi-k3-on-trtllm.html , https://github.com/NVIDIA/TensorRT-LLM/blob/main/docs/source/deployment-guide/deployment-guide-for-kimi-k2-thinking-on-trtllm.md
- https://github.com/ashhart/TensorFold , https://ollama.com/library/kimi-k3:cloud , https://ollama.com/library/kimi-k2.5
- Model cards listed in `models.md`
