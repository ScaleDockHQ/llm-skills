# Portkey routing and configs

> Verified against Portkey AI Gateway v1.15.2 (src/middlewares/requestValidator/schema/config.ts, src/globals.ts) and docs.portkey.ai (configs, fallbacks, load-balancing, automatic-retries, request-timeouts, conditional-routing, circuit-breaker, cache-simple-and-semantic), 2026-10-11

A config is JSON that decides how a request is routed. In the open-source gateway send it inline in the `x-portkey-config` header (or the SDK `config` argument). Saved config IDs (`pc-...`), default configs on API keys and Config management are hosted features. The validator (zod schema in the repo) is the ground truth for open-source keys: `strategy`, `provider`, `api_key`, `targets`, `weight`, `retry`, `request_timeout`, `cache`, `custom_host`, `forward_headers`, `input_guardrails`, `output_guardrails`, `before_request_hooks`, `after_request_hooks`, `override_params` and provider-specific fields (`aws_*`, `vertex_*`, `azure_*`, `openai_project`). A config must have `provider` plus `api_key`, or `strategy` plus `targets`, or `cache`, `retry`, `request_timeout`, hooks or guardrails.

## Strategies

`strategy.mode`: `single`, `fallback`, `loadbalance`, `conditional`.

- **fallback:** try `targets` in order. By default any non-2xx triggers the next target; narrow with `strategy.on_status_codes`.
- **loadbalance:** pick a target by `weight` (weights are relative). Use it to spread across keys or providers.
- **conditional:** `strategy.conditions[]` each with `query` and `then` (a target `name`), plus `default`. Query paths: `metadata.<key>` (from `x-portkey-metadata`), `params.<key>` (request body), `url.pathname`. Only two-segment, flat keys and primitive values. Operators include `$eq`; read the docs list for the rest. Circuit breakers do not evaluate conditional strategies.
- Strategies nest: a target can itself have `strategy` and `targets`, inheriting `retry`, `cache`, `request_timeout` and `override_params` from the parent unless overridden.

Target fields: `provider`, `api_key`, `custom_host`, `weight`, `name`, `retry`, `override_params` (always overwrite fields such as `model`), plus `default_params` and `drop_params` where the hosted docs describe them (verify they exist on your open-source tag before use; they appear in docs, not in the 1.15.2 validator).

Examples: `assets/config-fallback.json`, `assets/config-loadbalance.json`, `assets/config-conditional.json`. Replace placeholder keys at render time from the environment; never commit real keys.

## Retries

`retry: {"attempts": N, "on_status_codes": [...], "use_retry_after_header": true}`. Attempts maximum 5 (`MAX_RETRIES`). The open-source default retry codes in `src/globals.ts` are 429, 500, 502, 503, 504; the hosted docs also list 529. Setting `on_status_codes` replaces the defaults. Exponential backoff applies, and `use_retry_after_header` makes the gateway honor `retry-after-ms`, `x-ms-retry-after-ms` or `retry-after` (the hosted docs spell the key `use_retry_after_headers`; the open-source validator uses the singular `use_retry_after_header`). Backoff is capped at 60 seconds (`MAX_RETRY_LIMIT_MS`).

Fallback and retry interact: each target retries first, then the strategy moves to the next target. Keep total time within the client timeout.

## Timeouts

`request_timeout` in milliseconds, in the config or via `x-portkey-request-timeout`. On timeout the gateway returns 408 (`REQUEST_TIMEOUT_STATUS_CODE`), which you can list in `on_status_codes` to fall back. Set it above the slowest legitimate first token (reasoning models, long prompts).

## Cache

`cache: {"mode": "simple", "max_age": 60}` or `semantic`. In the open-source build there is only an in-memory cache and only when `conf.json` has `"cache": true` at build; semantic caching and TTL beyond memory need the hosted or Enterprise product. Cache hits are marked `x-portkey-cache-status`. A request differing in any parameter or in `x-portkey-metadata` misses; `x-portkey-cache-force-refresh` bypasses. Caching is off by default for files, batches, fine-tunes and image edits.

## Circuit breaker

Documented as `strategy.cb_config`: `failure_threshold`, `failure_threshold_percentage`, `minimum_requests`, `cooldown_interval` (milliseconds, minimum 30 seconds), `failure_status_codes`. The open-source source references `cb_config`; confirm it has an effect on your tag by forcing failures before relying on it.

## Verify

- [ ] Force a failure on the first target (wrong model or key) and confirm the response header `x-portkey-last-used-option-index` shows the next target.
- [ ] `x-portkey-retry-attempt-count` matches the retry config on a forced 429 or 503.
- [ ] Total worst-case latency (timeouts times retries times targets) is below the client timeout.
