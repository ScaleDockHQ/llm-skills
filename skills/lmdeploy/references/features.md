# Features

> Verified against LMDeploy v0.18.0 (docs `llm/api_server_tools.md`, `llm/api_server_reasoning.md`, `advance/structed_output.md`, `llm/api_server_lora.md`, `advance/spec_decoding.md`, `multi_modal/*`; source parser registries), 2026-10-11

## Tool calling

Start with `--tool-call-parser <name>`; without it, `tools` are passed to the chat template but nothing is parsed
into `tool_calls`. Registered names in v0.18.0 source (check `lmdeploy serve api_server -h` for your version):

| Parser name(s)                | Model family (per upstream docs and source)                                 |
| ----------------------------- | --------------------------------------------------------------------------- |
| `qwen`, `qwen2d5`, `qwen3`    | Qwen2.5 / Qwen3 JSON-style tool calls                                       |
| `qwen3coder`                  | Qwen3-Coder format; upstream docs also name it for Qwen3.5                  |
| `internlm`, `intern-s1`       | InternLM / Intern-S1                                                        |
| `interns2-preview`            | Intern-S2-Preview                                                           |
| `llama3`                      | Llama 3.x                                                                   |
| `kimi_k2`, `kimi-k2`          | Kimi K2                                                                     |
| `deepseek-v32`, `deepseek-v4` | DeepSeek V3.2, V4                                                           |
| `glm47`                       | GLM-4.7                                                                     |
| (automatic)                   | gpt-oss uses the Harmony response parser when `openai_harmony` is installed |

`tool_choice`: `auto` lets the model decide; `required` constrains generation to the tool-call format (needs a
non-empty `tools` list and a parser that supports it, else HTTP 400, and takes precedence over `response_format`);
`none` disables extraction but the tools still reach the chat template. Smoke test:

```bash
curl -s http://127.0.0.1:23333/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"qwen","messages":[{"role":"user","content":"Weather in Paris?"}],
  "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],
  "tool_choice":"required"}' | jq '.choices[0].message.tool_calls'
```

## Reasoning

`--reasoning-parser <name>`: `default` (common `<think>...</think>`: Qwen3, QwQ, DeepSeek R1, Intern-S1),
`deepseek-v3` (reasoning mode only when `enable_thinking=True`), `deepseek-v32`/`deepseek-v3.2`, `deepseek-v4`
(reasoning when `thinking=True` or `enable_thinking=True`). Legacy `qwen-qwq`, `intern-s1`, `deepseek-r1` map to
`default` with a deprecation warning. Output is `message.reasoning_content` (and `delta.reasoning_content` when
streaming). For multi-turn reuse send the prior `reasoning_content` back (documented for Qwen3.8; it counts as prompt
tokens). gpt-oss needs no reasoning parser.

## Structured output

`response_format` with `type: json_schema` (OpenAI form) constrains decoding on both engines; the xgrammar library is used
(per the speculative-decoding doc). Grammar/regex variants are described in
`advance/structed_output.md`. With speculative decoding it applies to the draft too (PyTorch backend, methods
inheriting `DeepseekMTP`: `deepseek_mtp`, `qwen3_5_mtp`, `eagle3`).

```bash
curl -s http://127.0.0.1:23333/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"qwen","messages":[{"role":"user","content":"Name and age of a person as JSON"}],
  "response_format":{"type":"json_schema","json_schema":{"name":"p","schema":{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}}}}' \
  | jq -r '.choices[0].message.content'
```

## LoRA (PyTorch engine only)

```bash
lmdeploy serve api_server <base-model> --backend pytorch --adapters mylora=/path/to/adapter other=/path/other
```

Each key becomes a model name in `/v1/models`; select it with `"model": "mylora"`. For many adapters see the
`multi-lora-serving` skill.

## Vision-language models

Same server, OpenAI message format with `image_url` (and other modalities, see `multi_modal/multimodal_inputs.md`).
Control remote media with `--allowed-media-domains host1 host2` (exact hostnames) and fetch timeouts via
`LMDEPLOY_IMAGE_FETCH_TIMEOUT` / `LMDEPLOY_VIDEO_FETCH_TIMEOUT` (names from source; upstream's FAQ still shows an older
`LMDEPLOY_FETCH_TIMEOUT`). Docker image may lack per-model dependencies (upstream example installs git and pip
packages for LLaVA). Text-only models reject multimodal requests (v0.18.0).

## Speculative decoding (PyTorch, experimental)

```bash
lmdeploy serve api_server meta-llama/Llama-3.1-8B-Instruct --backend pytorch \
  --speculative-algorithm eagle3 --speculative-draft-model yuhuili/EAGLE3-LLaMA3.1-Instruct-8B \
  --speculative-num-draft-tokens 3 --max-batch-size 128
```

Algorithms: `eagle`, `eagle3`, `deepseek_mtp`, `hy3_mtp`, `qwen3_5_mtp`, `dflash`. EAGLE-3 needs flash-attention 3
(Hopper) per upstream; DeepSeek MTP needs FlashMLA. DFlash: `--speculative-dflash-block-size 8` proposes 7 tokens
and overrides `--speculative-num-draft-tokens`. Watch `lmdeploy:spec_decode_mean_accept_rate` in `/metrics`. For
technique background use the `speculative-decoding` skill.

## Embeddings and pooling

`/v1/embeddings` is tagged `unsupported` in the router. `POST /pooling` (reward-model style pooling, same input
shape as embeddings: `model`, `input` as str, list of str, token ids) exists. For embeddings use a dedicated
server (`text-embeddings-inference`).

## Chat templates

`--chat-template <json file or string>` with fields such as `system`, `user`, `assistant`, `eoh`, `eoa`, `stop_words`
(`advance/chat_template.md`). Run with `--log-level INFO` to see the applied template. A stale or wrong template is
the usual cause of garbled or non-terminating output on custom models.

## Anthropic and Responses endpoints

See `references/api.md`.
