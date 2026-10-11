# TensorFold: API

> Verified against TensorFold v1.0.7, 2026-10-11

Docs/api.md, README

Base URL `http://127.0.0.1:8080/v1` by default. Use the ID from `/v1/models` or `--name`.

## Routes

| Route                                                             | Notes                                                                                                                                                       |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /health`                                                     | Open even with keys (`{"status":"ok"}`). On CUDA also `busy`, `requests_running`, `requests_total`, `completion_tokens_total`, `streams`, `context_length`. |
| `GET /v1/models`, `/models`                                       | Includes `context_length` and `max_model_len` when the window is finite.                                                                                    |
| `GET /metrics`, `/v1/metrics`                                     | Prometheus text.                                                                                                                                            |
| `GET /dashboard`, `/stats`                                        | Only with `--dashboard` (404 otherwise).                                                                                                                    |
| `POST /v1/chat/completions`                                       | Text, optional images, tools, reasoning; streaming.                                                                                                         |
| `POST /v1/completions`                                            | Raw text or token IDs (CUDA: string `prompt` or token-ID list; `add_special_tokens` default false).                                                         |
| `POST /v1/responses`, `GET/DELETE /v1/responses/{id}`             | OpenAI Responses, run as chat; newest 1,024 stored (256 MiB).                                                                                               |
| `POST /v1/messages`, `/v1/messages/count_tokens`                  | Anthropic Messages, JSON or SSE.                                                                                                                            |
| `POST /tokenize`, `/v1/tokenize`, `/detokenize`, `/v1/detokenize` | vLLM-compatible.                                                                                                                                            |
| `POST /v1/decisions`                                              | Choice/score/yes-no from next-token logits; MLX server and CUDA GLM engine only (other CUDA engines return 400).                                            |

## Request fields (chat)

`messages`, `tools`, `tool_choice` (`none`/`required`/named), `parallel_tool_calls`, `max_tokens` / `max_completion_tokens` (rejected if prompt plus reply exceeds the window), `temperature`, `top_p`, `top_k`, `min_p`, `seed`, `stream`, `stream_options.include_usage`, `chat_template_kwargs.enable_thinking`, `draft` (false = serial reference), structured-output fields, `ignore_eos`, `stop`, `reasoning_effort` (`none` to `max`), `thinking_budget`, `priority` (`background`). `n` must be 1. A request without `seed` takes one derived from its prompt (salt: `TENSORFOLD_SEED_SALT`); send a `seed` per run for independent repeats. `logprobs`/`top_logprobs` (0 to 20) work on non-streamed chat on native CUDA Nemotron without tools, stop strings or structured output; elsewhere HTTP 400.

Replies carry a `tensorfold` block (`engine`, `tokens_per_second`, `time_to_first_token`, `prefill_seconds`, `token_sha`, draft counters). Reasoning is returned in `reasoning_content`; an empty `content` usually means the model thought until `max_tokens`.

## Examples

```bash
curl -fsS http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $(cat ~/.config/tensorfold/key)" \
  -d '{"model":"local-model","messages":[{"role":"user","content":"Hi"}],"max_tokens":128,"temperature":0,"stream":false}'
# Anthropic client such as Claude Code
ANTHROPIC_BASE_URL=http://127.0.0.1:8080 ANTHROPIC_API_KEY=local claude --model local-model
```

Responses refuse built-in tools, `background`, `include`, `conversation`, `truncation: "auto"`, `top_logprobs`, files and encrypted reasoning with HTTP 400. Messages refuse server-side tools, documents/file IDs and redacted thinking; `cache_control` hints do not allocate an Anthropic cache.
