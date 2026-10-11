# Gemma 4 parsers, templates and toggles

> Verified against vLLM recipes Gemma4 page, SGLang Gemma 4 cookbook and server arguments, llama.cpp server README, TensorRT-LLM supported-models page, Gemma 4 model card, 2026-10-11

## Template and token facts

| Topic            | Fact                                                                                                                       | Source                                                           |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Roles            | Standard `system`, `user`, `assistant`. Gemma 4 has a native `system` role (Gemma 3 did not use these roles the same way). | [model card](https://ai.google.dev/gemma/docs/core/model_card_4) |
| Enable thinking  | Put `<                                                                                                                     | think                                                            | >`at the start of the system prompt. Remove it to disable. Libraries do this for you via`enable_thinking`. | model card |
| Thinking output  | `<                                                                                                                         | channel>thought\n`reasoning`<channel                             | >` then the answer.                                                                                        | model card |
| Thinking off     | All sizes except E2B and E4B still emit an empty block `<                                                                  | channel>thought\n<channel                                        | >`. E2B and E4B emit nothing.                                                                              | model card |
| History          | Strip earlier thoughts from assistant turns before the next user turn. Keep thinking only across tool-call turns.          | model card                                                       |
| Tool calls       | Custom special tokens: `<                                                                                                  | tool_call>call:name{key:<                                        | "                                                                                                          | >value<    | "   | >}<tool_call | >`. | [HF blog](https://huggingface.co/blog/gemma4), [SGLang PR](https://github.com/sgl-project/sglang/pull/21952) |
| Multimodal order | Image before text. Audio after text.                                                                                       | model card                                                       |
| Sampling         | `temperature=1.0`, `top_p=0.95`, `top_k=64` for all use cases.                                                             | model card                                                       |

Use the engine's own chat template path. Do not hand-build prompts. Hugging Face says the built-in template "takes care of formatting the inputs correctly".

## Engine matrix

| Engine       | Tool parser                                                  | Reasoning parser                                                                       | Template                                                                                                 | Thinking toggle                                                                                                                             |
| ------------ | ------------------------------------------------------------ | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM         | `--tool-call-parser gemma4` with `--enable-auto-tool-choice` | `--reasoning-parser gemma4`                                                            | `--chat-template examples/tool_chat_template_gemma4.jinja` (in the official container and the vLLM repo) | Per request `chat_template_kwargs: {"enable_thinking": true}`; default on with `--default-chat-template-kwargs '{"enable_thinking": true}'` |
| SGLang       | `--tool-call-parser gemma4`                                  | `--reasoning-parser gemma4`                                                            | Model default                                                                                            | Per request `chat_template_kwargs: {"enable_thinking": true}`                                                                               |
| llama.cpp    | Built into `--jinja` (default on)                            | `--reasoning-format` (`auto` default; `deepseek` puts thoughts in `reasoning_content`) | Model GGUF metadata                                                                                      | `--reasoning on\|off\|auto`, or `--chat-template-kwargs '{"enable_thinking":false}'`                                                        |
| TensorRT-LLM | Not verified                                                 | Not verified                                                                           | Not verified                                                                                             | Not verified                                                                                                                                |
| Ollama       | Built in (library page tags: vision, tools, thinking, audio) | Built in                                                                               | Built in                                                                                                 | Not verified for the CLI/API flag; read Ollama docs                                                                                         |
| TensorFold   | No upstream support found for CUDA on 1.0.7                  | n/a                                                                                    | n/a                                                                                                      | n/a                                                                                                                                         |

Sources: [vLLM recipe](https://docs.vllm.ai/projects/recipes/en/latest/Google/Gemma4.html), [SGLang cookbook](https://docs.sglang.io/cookbook/autoregressive/Google/Gemma4), [SGLang server args](https://docs.sglang.io/docs/advanced_features/server_arguments), [llama.cpp server README](https://github.com/ggml-org/llama.cpp/blob/d81235049/tools/server/README.md), [TensorRT-LLM supported models](https://nvidia.github.io/TensorRT-LLM/latest/models/supported-models.html), [Ollama gemma4](https://ollama.com/library/gemma4).

## vLLM

```bash
vllm serve google/gemma-4-31B-it \
  --tensor-parallel-size 2 --max-model-len 16384 --gpu-memory-utilization 0.90 \
  --enable-auto-tool-choice --reasoning-parser gemma4 --tool-call-parser gemma4 \
  --chat-template examples/tool_chat_template_gemma4.jinja \
  --limit-mm-per-prompt '{"image": 4, "audio": 1}' --async-scheduling
```

- The recipe's install uses a nightly wheel (`--pre`, `wheels.vllm.ai/nightly/cu129`) or `vllm/vllm-openai:latest` (CUDA 12.9) / `:latest-cu130`. The 12B recipe uses `vllm/vllm-openai:gemma4-unified`; `vllm/vllm-tpu:gemma4` serves TPUs.
- Audio needs `pip install "vllm[audio]"`. Audio only works on E2B, E4B and 12B.
- Vision budget: `--mm-processor-kwargs '{"max_soft_tokens": N}'`, default 280, up to 1120.
- Memory: `--limit-mm-per-prompt '{"image": 0, "audio": 0}'` for text-only; `.audio 0` for image-only. `--kv-cache-dtype fp8` halves KV memory.
- The reasoning parser strips the `thought\n` role label. Thinking and tool calls both work together. Raise `--max-model-len` and `max_tokens` when thinking is on.
- Structured outputs: the model does not see the JSON schema or its field descriptions. Describe the output in the prompt as well as in `response_format`.
- Speculative decoding (MTP): `--speculative-config '{"model": "google/gemma-4-31B-it-assistant", "num_speculative_tokens": 4}'`. Recipe values (benchmarked on A100 and H100): E2B 2 (TP1), E4B 4 (TP1), 12B 4-8 (TP1), 26B-A4B 4 (TP2), 31B 4-8 (TP2).

```bash
curl -s localhost:8000/v1/chat/completions -H 'content-type: application/json' -d '{
  "model":"google/gemma-4-31B-it","max_tokens":4096,
  "chat_template_kwargs":{"enable_thinking":true},
  "messages":[{"role":"user","content":"Plan a 3-step migration."}]}' | jq '.choices[0].message | {reasoning, content}'
```

Reasoning appears in the message `reasoning` field on the recipe's SDK example; if your client reads `reasoning_content`, check the response with `jq .` first.

## SGLang

```bash
sglang serve --model-path google/gemma-4-26B-A4B-it \
  --reasoning-parser gemma4 --tool-call-parser gemma4 --host 127.0.0.1 --port 30000
```

- Both `gemma4` parser names are listed in the server-arguments table; `auto` detects from the template.
- Cookbook container: `lmsysorg/sglang:latest`. AMD example sets `SGLANG_USE_AITER=0` for E4B.
- 31B in the SGLang PR was launched with `--tp 2` (2x H200).
- Reasoning streams as `reasoning_content`; tool calls as `tool_calls`.

## llama.cpp

```bash
llama-server -hf ggml-org/gemma-4-26b-a4b-it-GGUF:Q4_K_M --jinja -c 32768 \
  --temp 1.0 --top-p 0.95 --top-k 64 --reasoning off --host 127.0.0.1 --port 8080
```

- Image + text works with the GGUF mmproj (`-hf` pulls it automatically; otherwise `--mmproj FILE`).
- Thinking control has been flaky across builds; see `references/known-issues.md` before relying on `enable_thinking` alone.
- The Hugging Face blog installs with `curl -LsSf https://llama.app/install.sh | sh` and runs `llama serve -hf ...`. This skill uses the documented `llama-server` binary; check which one your install provides.

## TensorRT-LLM

PyTorch backend only, loads Hugging Face checkpoints directly (no `trtllm-build`). Supported architectures: `Gemma4ForConditionalGeneration` (E2B, E4B, 26B-A4B, 31B), `Gemma4UnifiedForConditionalGeneration` (12B), and `Gemma4AssistantForCausalLM` (MTP assistants for the four non-12B sizes). MTP is not supported for 12B. The upstream feature table marks KV cache reuse "No" for Gemma 4. See [TensorRT-LLM Gemma README](https://github.com/NVIDIA/TensorRT-LLM/blob/main/examples/models/core/gemma/README.md). Tool and reasoning parser flags for Gemma 4 were not found in the pages read.
