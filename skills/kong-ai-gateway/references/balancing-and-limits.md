# Load balancing, fallback, rate limits and cost

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

Load balancing and token limits are paid features: `ai-proxy-advanced` and `ai-rate-limiting-advanced` on Kong Gateway Enterprise, or the AI Model `config.balancer` and the AI Rate Limiting Advanced policy on AI Gateway 2.x. OSS `ai-proxy` has one target and no failover.

## Balancer (`ai-proxy-advanced` `config.balancer`, same on a 2.x AI Model)

- `algorithm` (default `round-robin`): `round-robin`, `consistent-hashing` (with `hash_on_header`), `least-connections`, `lowest-latency` (with `latency_strategy`), `lowest-usage` (with `tokens_count_strategy`), `priority` (tiered failover across model groups), `semantic` (needs `vectordb` and `embeddings`).
- Targets carry `weight` (1 to 65535, default 100, `ai-proxy-advanced` only).
- Retry and fallback: `retries`, `failover_criteria` (any of `error`, `timeout`, `http_403`, `http_404`, `http_429`, `http_500`, `http_502`, `http_503`, `http_504`, `invalid_header`, `non_idempotent`), `connect_timeout`, `read_timeout`, `write_timeout`. By default only `error` and `timeout` fail over; add HTTP codes (429, 5xx) deliberately. Fallback works across providers, so you can mix OpenAI-style and other formats.
- Circuit breaker: `max_fails` and `fail_timeout`; a target that reaches the threshold is skipped until the timeout elapses.
- Semantic routing needs an embeddings model (providers include `openai`, `azure`, `bedrock`, `gemini`, `huggingface`, `mistral`, `ollama`) and a vector DB (Redis or pgvector). The embedding dimension must match the index; see troubleshooting.

## Rate limiting (`ai-rate-limiting-advanced`)

- `llm_providers`: per provider (`openai`, `azure`, `anthropic`, `bedrock`, `cohere`, `gemini`, `huggingface`, `llama2`, `mistral`, `customCost`, `requestPrompt`), each with arrays `limit` and `window_size` (seconds) that must be the same length.
- `tokens_count_strategy`: `total_tokens` (default), `prompt_tokens`, `completion_tokens` or `cost`. Using `cost` needs per-model `input_cost` and `output_cost` set by you.
- `identifier` (default `consumer`): `consumer`, `consumer-group`, `credential`, `header`, `ip`, `path`, `service`. Limits per tenant need authenticated consumers or a header identifier you trust.
- `strategy`: `local` (default, per node), `redis` or `cluster` (not supported for DB-less or hybrid, per a support article). `sync_rate` controls counter sync (`0` synchronous, `-1` local only). Limits across several nodes need Redis.
- `error_hide_providers` hides provider names in limit errors; `retry_after_jitter_max` spreads client retries after a 429.

## Cost management

2.x models take cost parameters on targets (`input_cost`, `output_cost`, cache and service-tier factors); the docs page "Model cost management" explains the formula. Supply your own current rates from your provider; they are not stored in this skill. `kong.gen_ai.llm.cost` is the matching metric (see observability).

## Discover

```bash
curl -s http://127.0.0.1:8101/plugins | jq '.data[] | select(.name=="ai-proxy-advanced" or .name=="ai-rate-limiting-advanced") | {name,config: (.config|{balancer,llm_providers,strategy,identifier})}'
curl -sI http://127.0.0.1:8100/v1/chat/completions | grep -i -E 'ratelimit|retry-after|x-kong'
```
