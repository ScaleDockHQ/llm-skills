# GLM chat templates, parsers and toggles

> Verified against vLLM recipes (GLM-5.3, GLM-5.3-Flash; vLLM 0.28/0.29), SGLang cookbook (GLM-5.3, GLM-5.3-Flash; SGLang v0.5.20), TensorRT-LLM 1.3.0rc25 GLM-5 guide, zai-org model cards and Unsloth guides, 2026-10-11

Sources: [vLLM GLM-5.3 recipe](https://recipes.vllm.ai/zai-org/GLM-5.3), [vLLM GLM-5.3-Flash recipe](https://recipes.vllm.ai/zai-org/GLM-5.3-Flash), [SGLang GLM-5.3](https://cookbook.sglang.io/autoregressive/GLM/GLM-5.3), [SGLang GLM-5.3-Flash](https://cookbook.sglang.io/autoregressive/GLM/GLM-5.3-Flash), [TensorRT-LLM GLM-5 guide](https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-glm-5-on-trtllm.html), [GLM-5 README](https://github.com/zai-org/GLM-5), [GLM-4.7 README](https://huggingface.co/zai-org/GLM-4.7), [Unsloth GLM-5.3](https://unsloth.ai/docs/models/glm-5.3).

## Parser names

| Engine       | Model              | Tool-call parser                                     | Reasoning parser                                                            | Source               |
| ------------ | ------------------ | ---------------------------------------------------- | --------------------------------------------------------------------------- | -------------------- |
| vLLM         | GLM-5.3, 5.3-Flash | `--tool-call-parser glm47 --enable-auto-tool-choice` | `--reasoning-parser glm47` in the recipes; NVIDIA's NVFP4 card uses `glm45` | recipes, NVIDIA card |
| vLLM         | GLM-4.7, 4.7-Flash | `glm47`                                              | `glm45`                                                                     | GLM-4.7-Flash card   |
| SGLang       | GLM-5.3, 5.3-Flash | `--tool-call-parser glm47` (`auto` resolves to it)   | `--reasoning-parser glm45` (`auto` resolves to it)                          | cookbooks            |
| SGLang       | GLM-4.7-Flash      | `glm47`                                              | `glm45`                                                                     | card                 |
| TensorRT-LLM | GLM-5.x            | no parser flags in the guide                         | none documented                                                             | TRT-LLM guide        |
| llama.cpp    | all                | no parser flag: `--jinja` uses the model's template  | `--reasoning-format` (see below)                                            | Unsloth guides       |

Running with no tool parser, or the older `glm45` tool parser on GLM-5.x, leaves the `<tool_call>...<arg_key>...<arg_value>` text in `content` and `finish_reason` stays `"stop"`, so agent loops never see a call (SGLang cookbook). Without a reasoning parser, the thinking and the answer come back as one `content` string with a stray closing think tag between them, because the template opens the think block in the generation prompt.

## Reasoning and thinking toggles

| Model                   | Toggle                                                                | Values               | Default                                    | Notes                                                                                                                                                     |
| ----------------------- | --------------------------------------------------------------------- | -------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GLM-5.3, 5.3-Flash      | `reasoning_effort` (top-level OpenAI field or `chat_template_kwargs`) | `low`, `high`, `max` | `max`; any other value falls back to `max` | Thinking cannot be turned off; the generation prompt always opens a think block. The template injects `Reasoning Effort: Low                              | High | Max` into the system prompt. |
| GLM-5.3, 5.3-Flash      | `clear_thinking` (`chat_template_kwargs`)                             | true/false           | `false`                                    | Card: pass `true` for chat; keep `false` for agent consistency at a context cost.                                                                         |
| GLM-5.3-Flash on SGLang | `chat_template_kwargs: {"thinking": false}`                           |                      |                                            | The SGLang cookbook documents this for Flash; the card says thinking is always on. Treat as engine-specific and test it. Unverified against the template. |
| GLM-5.2                 | `reasoning_effort`                                                    | `high`, `max` only   | `max`                                      | Has `enable_thinking` (TRT-LLM guide).                                                                                                                    |
| GLM-4.7, 4.7-Flash      | `chat_template_kwargs: {"enable_thinking": false}`                    |                      | on                                         | Preserved Thinking: `{"enable_thinking": true, "clear_thinking": false}` (SGLang only per the GLM-4.7 card).                                              |

```bash
# GLM-5.3 family: low effort, clear earlier reasoning (works on vLLM and SGLang)
curl -s localhost:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"glm-5.3","messages":[{"role":"user","content":"hi"}],
  "chat_template_kwargs":{"reasoning_effort":"low","clear_thinking":true}}' | jq '.choices[0].message'
```

llama.cpp: `--jinja --chat-template-kwargs '{"reasoning_effort":"max","clear_thinking":true}'` (Unsloth guide). Check `llama-server --help` for your build's `--reasoning-format` values; the Unsloth GLM guides do not state a value for it.

## Template quirks

- The GLM-5.3 template renders `tools` before `system`. A per-request varying system prompt (Claude Code's attribution header) then breaks prefix caching every turn; SGLang's cookbook says set `CLAUDE_CODE_ATTRIBUTION_HEADER=0`.
- The template uses an `.{id}.` index notation many engines do not support; Unsloth rewrote it to `[id]` in its GGUFs (Unsloth GLM-5.3 page). Use Unsloth's embedded template, not the original, with llama.cpp.
- `tool_calls[].function.arguments` must be a dict when rendering with `apply_chat_template` directly. The OpenAI string form crashes the GLM-5.3-Flash template (see `known-issues.md`); server paths normalise it.
- Thinking can appear in `reasoning_content` or in `content` around tool execution: read both fields on follow-up turns (SGLang cookbook).
- Multimodal (Flash only): standard `image_url` and `video_url` parts. SGLang needs a Transformers build with `Glm5NextProcessor` (5.17.0 per cookbook) or image requests are silently answered from text alone. Video needs `torchcodec`, is sampled at 2 FPS and capped at 240,000 visual tokens.

## Sampling (from the cards)

| Use                                       | temperature    | top_p | Source                  |
| ----------------------------------------- | -------------- | ----- | ----------------------- |
| Default, GLM-5.3 / 5.3-Flash / 4.7-Flash  | 1.0            | 0.95  | cards, SGLang cookbook  |
| Long agentic tasks, GLM-5.3 (Unsloth)     | 1.0            | 1.0   | Unsloth                 |
| DeepSWE-style agent runs, 5.3-Flash       | 0.95           | 1.0   | Unsloth, card footnotes |
| Terminal-Bench / SWE-bench, GLM-4.7-Flash | 0.7            | 1.0   | GLM-4.7-Flash card      |
| llama.cpp extra (Unsloth)                 | `--min-p 0.01` |       | Unsloth                 |

## Launch commands (verbatim from upstream; adapt TP and memory)

vLLM, GLM-5.3 FP8 on 8x H200 (recipe, vLLM 0.28.0+, `transformers>=5.15.0`):

```bash
vllm serve zai-org/GLM-5.3 \
  --kv-cache-dtype fp8 --tensor-parallel-size 8 \
  --speculative-config.method mtp --speculative-config.num_speculative_tokens 5 \
  --tool-call-parser glm47 --reasoning-parser glm47 --enable-auto-tool-choice \
  --served-model-name glm-5.3
```

Full 1M context on 8x B200: same flags with `--kv-cache-dtype fp8_e4m3 --max-num-seqs 32`. FP8 needs DeepGEMM (recipe troubleshooting).

vLLM, GLM-5.3-Flash (recipe, 0.29.0+; Docker nightly until in a public release; FlashInfer 0.6.17+; one GB200 tray, FP8 TP4):

```bash
vllm serve zai-org/GLM-5.3-Flash --tensor-parallel-size 4 --kv-cache-dtype fp8 \
  --speculative-config '{"method":"mtp","num_speculative_tokens":5}' \
  --tool-call-parser glm47 --reasoning-parser glm47 --enable-auto-tool-choice \
  --served-model-name zai-org/GLM-5.3-Flash
```

Hopper does not support FP8 KV cache for Flash in the PD-disaggregation recipe: use BF16 KV there.

SGLang, GLM-5.3: use the cookbook's generated command with `--reasoning-parser auto --tool-call-parser auto`; it auto-selects DSA backends and KV dtype (`fp8_e4m3` on Blackwell, bf16 on Hopper). MTP: `--speculative-algorithm EAGLE --speculative-num-steps 5 --speculative-eagle-topk 1 --speculative-num-draft-tokens 6`. Flash needs SGLang v0.5.20+ and keeps the KDA lower bound: never override `linear_lower_bound` via `--json-model-override-args`.

TensorRT-LLM (1.3.0rc25, 8x B200, FP8): `trtllm-serve /models/GLM-5.3 --tp_size 8 --ep_size 8 --pp_size 1 --max_batch_size 128 --max_num_tokens 8192 --config /tmp/config.yml` with `moe_config.backend: DEEPGEMM` (FP8) or `TRTLLM` (NVFP4, no MTP), `speculative_config: {decoding_type: MTP, num_nextn_predict_layers: 1}`.

GLM-4.7-Flash, vLLM and SGLang (card): `--tool-call-parser glm47 --reasoning-parser glm45`, vLLM MTP `--speculative-config.method mtp --speculative-config.num_speculative_tokens 1`; on Blackwell with SGLang add `--attention-backend triton --speculative-draft-attention-backend triton`.
