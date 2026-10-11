# HTTP API

> Verified against vLLM v0.31.0 (docs `serving/online_serving/openai_compatible_server.md`, source `vllm/entrypoints/**`), 2026-10-11

One `vllm serve` process serves one model (plus LoRA adapters). To serve several models, run several servers
and a router (skills `llama-swap`, `llm-gateway`, `litellm`).

## Endpoints (route strings found in the v0.31.0 source)

| Group           | Routes                                                                                                                                                                                                                  |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Generation      | `/v1/chat/completions` (also `/batch`), `/v1/completions`, `/v1/responses` (also `/v1/responses/{id}` GET and `/cancel` POST), Anthropic-style `/v1/messages` and `/v1/messages/count_tokens`, `/inference/v1/generate` |
| Models          | `GET /v1/models` (lists the base model and loaded LoRA adapters; no tool/reasoning capability flags)                                                                                                                    |
| Pooling         | `/v1/embeddings`, `/v2/embed` (Cohere), `/pooling`, `/classify`, `/score`, `/v1/score`, `/rerank`, `/v1/rerank`, `/v2/rerank`                                                                                           |
| Audio           | `/v1/audio/transcriptions`, `/v1/audio/translations` (speech-to-text models; `vllm[audio]` extras)                                                                                                                      |
| Tokenization    | `/tokenize`, `/detokenize`; render endpoints (`/v1/chat/completions/render`, `/v1/responses/render`, ...) return prompt token IDs                                                                                       |
| Health and info | `GET /health` (200 when the engine is alive, 503 on a dead engine; never loads anything), `GET /version`, `GET /load`, `GET/POST /ping`, `GET /metrics` (Prometheus)                                                    |
| LoRA            | `POST /v1/load_lora_adapter`, `POST /v1/unload_lora_adapter` (only with `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True`)                                                                                                        |
| Profiling       | `POST /start_profile`, `/stop_profile` (start the server with `--profiler-config '{"profiler": "torch", "torch_profiler_dir": "./vllm_profile"}'`; docs `contributing/profiling.md`)                                    |
| Dev only        | Under `VLLM_SERVER_DEV_MODE=1`: `/sleep`, `/wake_up`, `/is_sleeping`, `/reset_prefix_cache`, `/server_info`, `/collective_rpc`, weight update endpoints. **Never expose these**; they can change or halt the server.    |

Authentication: `--api-key` / `VLLM_API_KEY` protects the `/v1` routes only. `/health`, `/metrics`, `/tokenize` and
others stay open, so keep the server on loopback or a private network and put a gateway in front.
Do not expose `/metrics` or dev routes publicly.

## Request basics

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "qwen-coder",
  "messages": [{"role": "user", "content": "12*17"}],
  "max_tokens": 200
}' | jq '.choices[0].message'
```

- `model` must equal `--served-model-name` (or the base repo ID if unset), or a LoRA adapter name.
- vLLM extension parameters go in the JSON body (or `extra_body` with the OpenAI SDK): `structured_outputs`,
  `chat_template_kwargs`, `top_k`, `min_p`, `repetition_penalty`, `priority`, `cache_salt`, and more. Full lists
  are in the "Extra parameters" sections of the OpenAI-compatible server docs.
- Default sampling parameters come from the model's `generation_config.json`; `--generation-config vllm` restores
  neutral defaults.
- Headers: `X-Request-Id` (with `--enable-request-id-headers`), `X-Vllm-Priority` (needs priority scheduling).
- Reasoning models return `message.reasoning` (not `reasoning_content`); see `references/features.md`.
- Responses API accepts `reasoning.effort` and per-request metrics; Anthropic `/v1/messages` accepts `thinking`
  (v0.31.0). Both are newer surfaces; test your client before relying on them.
- Streaming: `"stream": true`; `stream_options.include_usage` for token counts.

## Offline and batch

`from vllm import LLM, SamplingParams` for in-process inference (engine args become constructor args);
`vllm run-batch` for OpenAI-format batch files; `vllm chat` and `vllm complete` as quick CLI clients.

## gRPC

The Kubernetes docs mention serving with gRPC (`docs/deployment/k8s.md`, health check via
`grpc.health.v1.Health/Check`). This skill does not cover it.
