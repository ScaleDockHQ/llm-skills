# SambaNova troubleshooting

> Verified against SambaNova docs (API error codes, OpenAI compatibility, Model rate limits, Deprecations, Prompt caching), 2026-10-11

| Symptom                         | Cause                                                             | Fix                                                                                         |
| ------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `401 invalid_authentication`    | Wrong, deleted or expired key; wrong env var; wrong base URL.     | New key from the portal; `[ -n "$SAMBANOVA_API_KEY" ]`; base `https://api.sambanova.ai/v1`. |
| `400 model_not_found`           | Misspelled ID or not on your subscription.                        | `GET /v1/models`.                                                                           |
| `410 model_deprecated`          | Model retired.                                                    | Use the replacement from the deprecation page; rerun evals.                                 |
| `429 insufficient_quota`        | RPM, RPD or Free-tier TPD hit.                                    | Check `x-ratelimit-*` headers; slow down; link a payment method; ask sales for more.        |
| `429 queue_full`                | Too many in-flight requests service-wide.                         | Retry after a short delay with jitter; lower concurrency.                                   |
| `408 request_timeout`           | Load or long request.                                             | Smaller payload, retry; higher tier suggested by the docs.                                  |
| `503 maintenance`               | Model temporarily down.                                           | Retry later; fail over to another deployment in the gateway.                                |
| `400 context_length_exceeded`   | Prompt plus output above the model context.                       | Trim input or `max_tokens`; read the model context in the catalog.                          |
| `400` with `n` and tools        | `n > 1` is unsupported with tools.                                | Use `n: 1`.                                                                                 |
| `400` on `logit_bias` or `seed` | Model does not support them (multimodal, high-throughput models). | Remove the parameter for that model.                                                        |
| Penalty settings have no effect | `presence_penalty` and `frequency_penalty` are ignored.           | Use other sampling controls (`temperature`, `top_p`, `top_k` via `extra_body`).             |
| Image or video request fails    | Model is text-only (`MiniMax-M3` on SambaCloud) or no audio.      | Use `gemma-4-31B-it` for images and video if still listed.                                  |
| `cached_tokens` is 0            | Model not cache-enabled, prefix under 4096 tokens or unstable.    | Only MiniMax-M2.7 and M3 cache; stabilize the prefix.                                       |
| Anthropic client gets 404       | Base URL doubled or missing `/v1`.                                | Try `https://api.sambanova.ai/v1` then without `/v1`; use a SambaNova model ID.             |

Include the `request_id` from the error JSON when contacting support (help@sambanova.ai).
