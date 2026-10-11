# SGLang: API surface

> Verified against SGLang v0.5.21 (docs: basic_usage/{openai_api_*,anthropic_api,ollama_api,native_api,sampling_params}; `srt/utils/auth.py`), 2026-10-11

Base URL `http://127.0.0.1:30000` by default.

## Compatible APIs

| API       | Endpoints                                                                                           | Notes                                                                                                                                                 |
| --------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| OpenAI    | `POST /v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `GET /v1/models`, `/v1/responses` | `model` is `--served-model-name` (or the path). `model="base:adapter"` selects a LoRA adapter.                                                        |
| Anthropic | `POST /v1/messages`, `/v1/messages/count_tokens`                                                    | Registered automatically; model name is not validated; reuses chat template and parsers. Needs `--tool-call-parser` for executable `tool_use` blocks. |
| Ollama    | `/api/tags`, `/api/chat`, `/api/generate`, `/api/show`                                              | `OLLAMA_HOST=http://host:port ollama run "<exact --model name>"`; no Ollama server needed.                                                            |
| Native    | `POST /generate`                                                                                    | `{"text": "...", "sampling_params": {"max_new_tokens": 64, "temperature": 0}}`; also `input_ids`, `lora_path`, `stream`, `return_logprob`.            |

PD disaggregation limits `/v1/responses` (no stored responses, background mode, or built-in tools); see `combos/pd-disaggregation.md`.

## Smoke tests

```bash
H='Content-Type: application/json'; B=http://127.0.0.1:30000
curl -fsS $B/v1/models | jq -r '.data[].id'
curl -fsS $B/v1/chat/completions -H "$H" -d '{"model":"MODEL","messages":[{"role":"user","content":"Hi"}],"max_tokens":16,"stream":false}' | jq .usage
curl -fsS $B/generate -H "$H" -d '{"text":"The capital of France is","sampling_params":{"max_new_tokens":8,"temperature":0}}' | jq -r .text
curl -fsS $B/v1/messages -H "$H" -d '{"model":"any","max_tokens":16,"messages":[{"role":"user","content":"Hi"}]}' | jq .
```

With `--api-key`, add `-H "Authorization: Bearer $(cat ~/.config/sglang/api-key)"` (a `0600` file; never echo it).

## Request extras (OpenAI endpoints)

Passed through `extra_body`: `separate_reasoning` (reasoning in `reasoning_content`), `chat_template_kwargs` (for example `{"enable_thinking": false}`), `regex`, `ebnf`, `lora_path`, `top_k`, `min_p`, `repetition_penalty`, `stop_token_ids`, `skip_special_tokens`, `priority` (with `--enable-priority-scheduling`), `return_hidden_states` (with `--enable-return-hidden-states`). `response_format` with `json_schema` is standard. `stream_options.include_usage` for usage in streams (or `--stream-response-default-include-usage`). Check `sampling_params` upstream for the native list; Not every extra was individually verified on 0.5.21: test the ones you rely on.

## Operational endpoints

| Endpoint                                               | Purpose                                                                                                                                                                                                                                                               | Auth class     |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| `GET /health`                                          | Liveness: server is up (no generation). Use for probes.                                                                                                                                                                                                               | open           |
| `GET /health_generate`                                 | Generates one token. Manual deep check; not for frequent polling.                                                                                                                                                                                                     | open           |
| `GET /get_model_info`                                  | `model_path`, `is_generation`, `tokenizer_path`, `weight_version`, `model_type`, `architectures`, image/audio capability.                                                                                                                                             | normal         |
| `GET /server_info`                                     | Effective server args, token limits, memory pool sizes (merges old `get_server_args`, `get_memory_pool_size`, `get_max_total_num_tokens`). Treat as sensitive: it includes the resolved args and `launch_command`, which can contain keys passed on the command line. | normal         |
| `GET /metrics`                                         | Prometheus text (needs `--enable-metrics`).                                                                                                                                                                                                                           | open           |
| `POST /flush_cache` (`?timeout=30`)                    | Clear the radix cache; fails fast if not idle when timeout is 0.                                                                                                                                                                                                      | admin-optional |
| `POST /update_weights_from_disk`                       | Hot-swap weights of the same architecture.                                                                                                                                                                                                                            | admin-optional |
| `POST /load_lora_adapter`, `/unload_lora_adapter`      | Dynamic LoRA.                                                                                                                                                                                                                                                         | admin-optional |
| `POST /tokenize`, `/detokenize`                        | Tokenizer round trip.                                                                                                                                                                                                                                                 | normal         |
| `POST /encode`, `/classify`, `/v1/rerank`, `/v1/score` | Embedding, reward, rerank, scoring models.                                                                                                                                                                                                                            | normal         |
| `POST /start_profile`, `/stop_profile`                 | Torch profiler traces (`SGLANG_TORCH_PROFILER_DIR`); in PD mode profile prefill and decode separately.                                                                                                                                                                | admin-optional |

Auth classes (from `srt/utils/auth.py`): **open** paths (`/health*`, `/ready*`, `/metrics`) always pass. **normal** endpoints require `--api-key` when it is set (an `--admin-api-key` alone leaves them open). **admin-optional** endpoints (cache flush, weight updates, profiling, HiCache storage attach/detach, abort, and similar) are open when no keys are set, need the admin key when `--admin-api-key` is set (the normal key is then refused), and need the normal key when only `--api-key` is set. Class assignments above are from the v0.5.21 source and may change; never expose admin endpoints beyond localhost and set both keys when a server is reachable by others.

## Clients

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:30000/v1", api_key="dummy")   # use the real key via env when --api-key is set
r = client.chat.completions.create(model="qwen3-8b", messages=[{"role": "user", "content": "Hi"}])
```

Claude Code and other Anthropic-SDK clients: see `integrations.md`. For a gateway with keys, budgets and routing in front: skill `litellm`.

## Offline engine

`import sglang as sgl; llm = sgl.Engine(model_path=...)` runs without HTTP (batch jobs, RL loops). Not covered further; see `basic_usage/offline_engine_api` upstream.
