# OpenRouter troubleshooting

> Verified against OpenRouter API v1 (docs: api_reference/errors-and-debugging, limits, provider-selection, model-fallbacks, byok, claude-code-integration), 2026-10-11

Start by reading `error.code` and `error.metadata`, not only the HTTP status: once generation has started the HTTP status is 200 and the error is in the body or SSE stream.

| Symptom                              | Likely cause                                                                                | Fix                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 401 Invalid credentials              | Key deleted or disabled, wrong env var, expired management key (`API key expired`)          | `GET /api/v1/key` with the same header; recreate; check `ANTHROPIC_AUTH_TOKEN` or `OPENAI_API_KEY` really holds the key |
| 402 with positive balance            | In-flight spending budget, `limit_source: openrouter_in_flight_budget`                      | Wait for `Retry-After`; lower `max_tokens`; add credits                                                                 |
| 402 `openrouter_key_limit`           | Key credit limit spent                                                                      | Raise limit or wait for reset                                                                                           |
| 403 `Budget limit exceeded`          | Guardrail, workspace or key budget                                                          | Read `metadata.scope`, `resets_at`; ask admin; no retry helps                                                           |
| 403 `Request blocked`                | Guardrail content filter or moderation flag                                                 | Read `metadata.patterns` or `reasons`; adjust prompt or guardrail                                                       |
| 429 on `:free`                       | Free-model request caps                                                                     | Back off with `Retry-After`; use a paid endpoint                                                                        |
| 502                                  | Model down or bad provider response                                                         | Add `models` fallbacks; retry; check provider uptime                                                                    |
| 503 no provider                      | `order`/`only`/`zdr`/`data_collection`/`quantizations` filters leave nothing                | Loosen filters; list `/models/{a}/{s}/endpoints` and `/endpoints/zdr`                                                   |
| 400 on `/messages` with fallbacks    | `fallbacks` with `models`, more than 3 entries or extra per-entry fields                    | One field `model` per entry, at most 3                                                                                  |
| Feature (tools, JSON schema) ignored | Provider does not support it                                                                | `provider.require_parameters: true`; `:exacto`; pick a model whose `supported_parameters` has it                        |
| Different model than requested       | Fallback or router (`openrouter/auto`, `~...-latest`)                                       | Read response `model`; remove fallbacks; pin ID                                                                         |
| Cost differs from list price         | `:nitro`/`:floor` tier endpoint, BYOK fee, plugin or server tool charges                    | Read `GET /generation?id=`; response reports the tier                                                                   |
| Claude Code fails or hangs           | Non-Anthropic provider chosen, wrong base URL (`/v1` suffix), `ANTHROPIC_API_KEY` not blank | Anthropic 1P first in `order`, base `https://openrouter.ai/api`, blank API key                                          |
| Same answer every time               | Response caching on                                                                         | Send `X-OpenRouter-Cache-Clear: true` or disable caching                                                                |
| Preset ignored                       | Missing `@preset/` prefix in `preset` field                                                 | Use `@preset/slug`                                                                                                      |
| Streaming dies mid-way               | Error arrives as SSE event, status already 200                                              | Parse the error event; retry with fallbacks                                                                             |

Report suspected platform bugs through the feedback page (guides/overview/report-feedback) with the generation id from the `X-Generation-Id` header or response `id`.
