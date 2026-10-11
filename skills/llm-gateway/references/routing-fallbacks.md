# Routing, retries and fallbacks

> Verified against LiteLLM v1.105.0 (docs: routing, proxy/load_balancing, proxy/reliability, proxy/timeout, proxy/config_settings router_settings reference), 2026-10-11

## What it is and when to use it

Every `model_name` is a model group. When several `model_list` entries share a name, the router picks a deployment per request, retries failures, puts failing deployments in cooldown, and falls back to other groups when a whole group fails. Use it to spread load across replicas, survive a backend restart, and overflow from local to cloud.

## Minimal working config

```yaml
model_list:
  - model_name: coder
    litellm_params: { model: openai/qwen-coder, api_base: http://node-a:8080/v1, api_key: "none", rpm: 30 }
  - model_name: coder
    litellm_params: { model: openai/qwen-coder, api_base: http://node-b:8080/v1, api_key: "none", rpm: 30 }
  - model_name: coder-cloud
    litellm_params: { model: openrouter/<vendor>/<model>, api_key: os.environ/OPENROUTER_API_KEY }

router_settings:
  routing_strategy: simple-shuffle     # weighted by rpm/tpm when set
  num_retries: 2
  timeout: 120                         # seconds, per request
  stream_timeout: 60                   # seconds to first chunk on streaming requests
  allowed_fails: 3                     # failures per minute before cooldown
  cooldown_time: 30                    # seconds a deployment stays out
  fallbacks:
    - coder: [coder-cloud]
  context_window_fallbacks:
    - coder: [coder-cloud]
  enable_pre_call_checks: true         # enforce model_info.max_input_tokens before calling
```

`fallbacks`, `context_window_fallbacks`, `num_retries`, `allowed_fails` and `cooldown_time` are accepted under both `litellm_settings` and `router_settings` in upstream examples; keep them in one place (`router_settings`) to avoid confusion.

## Routing strategies

| `routing_strategy` | Picks | Use when |
|---|---|---|
| `simple-shuffle` (default) | Random, weighted by `rpm`/`tpm`/`weight` when set | Default; best throughput in upstream load tests when rpm/tpm are set |
| `least-busy` | Fewest in-flight requests | Uneven request lengths on equal hardware |
| `latency-based-routing` | Lowest recent latency | Mixed hardware or regions |
| `usage-based-routing` | Lowest TPM/RPM usage against limits | Hard provider rate limits |
| `cost-based-routing` | Cheapest deployment | Cost-sensitive cloud mixes |

Other ordering tools: `litellm_params.order` (lower number = higher priority, the strategy picks among equal orders) and routing groups that apply a different strategy to a subset of model names. With more than one LiteLLM instance, share router state through Redis (`router_settings.redis_host`, `redis_port`, `redis_password`).

## Fallback types

- `fallbacks`: any error after retries on the group.
- `context_window_fallbacks`: `ContextWindowExceededError`; route long prompts to a bigger model.
- `content_policy_fallbacks`: provider content-policy refusals.
- `default_fallbacks`: list used when a group has no specific fallback.

## Retries and cooldowns

- `num_retries` retries within the same group (another deployment when available).
- `retry_policy` sets retries per error type: `AuthenticationErrorRetries`, `TimeoutErrorRetries`, `RateLimitErrorRetries`, `ContentPolicyViolationErrorRetries`, `BadRequestErrorRetries`, `NotFoundErrorRetries`, `InternalServerErrorRetries`, `ServiceUnavailableErrorRetries`, `DefaultRetries`. Set auth and not-found retries to `0`.
- `allowed_fails_policy` sets cooldown thresholds per error type.
- `disable_cooldowns: true` turns cooldown off (useful with a single deployment you never want benched).

## Timeouts

- Precedence, most specific wins: per-deployment `litellm_params.timeout` (whole response) and `stream_timeout` (first chunk), then `router_settings.timeout`, then `litellm_settings.request_timeout` (default 6000 s, also bounds each chunk wait on native `/v1/responses` and `/v1/messages` streams).
- Local engines that load models on demand (llama-swap) need a first-token timeout long enough for a cold load; otherwise the first request after idle fails and triggers a fallback.

## Known pitfalls

- A single-deployment group with default cooldown gets benched for `cooldown_time` after a few errors, and every request fails fast in that window. Use `disable_cooldowns` or more replicas.
- Retrying 400s from unsupported params only multiplies the error; fix with `drop_params` (see `models-and-providers.md`).
- Fallback to a model with a smaller context window turns a context error into another context error. Order fallbacks by window size.
- Streaming requests that fail after the first byte cannot be retried transparently; the client sees a broken stream.
- Without Redis, each instance has its own cooldown and rate-limit state.

## Official links

- Router and strategies: https://docs.litellm.ai/docs/routing
- Proxy load balancing: https://docs.litellm.ai/docs/proxy/load_balancing
- Fallbacks and reliability: https://docs.litellm.ai/docs/proxy/reliability
- Timeouts: https://docs.litellm.ai/docs/proxy/timeout
- router_settings reference: https://docs.litellm.ai/docs/proxy/config_settings
