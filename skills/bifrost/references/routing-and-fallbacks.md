# Routing, retries and fallbacks

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/features/retries-and-fallbacks>, `/providers/provider-routing`, `/providers/routing-rules`, `/features/governance/routing`.

## Retries (per provider)

Configured in the provider's `network_config`. Defaults: `max_retries: 0`, `retry_backoff_initial: 500` ms, `retry_backoff_max: 5000` ms.

```json
{
  "network_config": {
    "max_retries": 3,
    "retry_backoff_initial": 500,
    "retry_backoff_max": 5000
  }
}
```

Behaviour: permanent per-key failures (401, 402, 403) mark the key dead for that request and rotate immediately without backoff; 429 rotates keys but still backs off; 5xx, DNS and connection errors reuse the key with exponential backoff and jitter. If every key is dead, Bifrost returns `502 upstream_credentials_exhausted`, not the raw 4xx.

## Fallbacks (per request)

Retries handle transient errors inside one provider; fallbacks switch providers after retries are exhausted. Each fallback is a fresh request, so plugins (cache, governance, logging) run again.

```bash
curl -sS http://localhost:8080/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "openai/<model>",
  "messages": [{"role":"user","content":"ping"}],
  "fallbacks": ["anthropic/<model>", "bedrock/<model-id>"],
  "max_tokens": 16
}' | jq '.extra_fields.provider'
```

`extra_fields.provider` tells you who answered. Use real model ids from each provider; the docs examples use older ids.

## Load balancing

Several keys under one provider are weighted (`weight`); virtual keys split traffic across providers with `provider_configs[].weight`. Adaptive load balancing is Enterprise.

## Routing rules

CEL-expression rules decide provider and model from request context (headers, parameters), evaluated before governance selection. See `providers/routing-rules` for variables and examples; test a rule in the UI before enabling it.

## Model aliases and custom pricing

`providers/aliasing-models` and `providers/custom-pricing` document aliases and cost overrides for private models, which matters for budgets on self-hosted providers (otherwise cost can read as zero; verify in the docs).
