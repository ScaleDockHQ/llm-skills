# Token limits and quotas

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs, examples/token_ratelimit and chart values, 2026-10-11

Two mechanisms, both Redis-backed and both answering 429:

|             | Usage-based rate limiting                                                          | `QuotaPolicy`                                                   |
| ----------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Question    | How much may a client use on a route or Gateway?                                   | How many tokens may the platform burn against a provider/model? |
| Config      | `llmRequestCosts` on the route plus Envoy Gateway `BackendTrafficPolicy.rateLimit` | `QuotaPolicy` (v1alpha1) on `AIServiceBackend`s                 |
| Service     | Envoy Gateway's global rate-limit service (addon values file)                      | A dedicated AI Gateway rate-limit service you deploy            |
| Windows     | second, minute, hour, day, month, year                                             | exactly `1s`, `1m`, `1h`, `1d`                                  |
| Token types | Separate limits per input, output, cached, total or CEL                            | One CEL cost per model (default `total_tokens`)                 |
| Scope       | Route or Gateway                                                                   | Backend and model, across all routes                            |

Pick usage-based limits for per-client allowances and long windows, QuotaPolicy for a provider-budget guard. They can coexist and share one Redis.

## Usage-based rate limiting

1. Install Redis (example `examples/token_ratelimit/redis.yaml`, namespace `redis-system`) and add the addon values to the Envoy Gateway release, pointing `config.envoyGateway.rateLimit.backend.redis.url` at it (`install.md`).
2. Record token costs into dynamic metadata on the route:

```yaml
spec:
  llmRequestCosts:
    - { metadataKey: llm_input_token, type: InputToken }
    - { metadataKey: llm_output_token, type: OutputToken }
    - { metadataKey: llm_total_token, type: TotalToken }
    - { metadataKey: llm_cached_input_token, type: CachedInputToken }
    - {
        metadataKey: llm_cache_creation_input_token,
        type: CacheCreationInputToken,
      }
    - metadataKey: llm_cel_weighted
      type: CEL
      cel: "input_tokens + output_tokens * uint(3)" # variables are uint
```

3. Charge them in a `BackendTrafficPolicy` on the Gateway. Request cost 0 means "check only"; the response cost from metadata is charged after the response completes:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata: { name: token-limit, namespace: default }
spec:
  targetRefs:
    - { group: gateway.networking.k8s.io, kind: Gateway, name: llm }
  rateLimit:
    type: Global
    global:
      rules:
        - clientSelectors:
            - headers: [{ name: x-tenant-id, type: Distinct }] # one budget per tenant
          limit: { requests: 200000, unit: Hour } # "requests" counts tokens here
          cost:
            request: { from: Number, number: 0 }
            response:
              {
                from: Metadata,
                metadata:
                  { namespace: io.envoy.ai_gateway, key: llm_total_token },
              }
```

Behavior to know:

- Charging happens after the response, so a client can overshoot by one request; the next request is rejected once charged usage exceeds the limit.
- Budgets are per rule; one rule per token type gives separate input, output and total budgets. Add `x-ai-eg-model` as a selector for per-model budgets.
- `llmRequestCosts` are scoped to their route.
- The tenant header must come from a trusted layer. A client-set `x-tenant-id` is not identity; enforce it with a `SecurityPolicy` or ext-auth that sets it.
- Costs come from usage in the response. After a streamed test, confirm `gen_ai_client_token_usage` increased; if it did not, check that the provider reports usage in streams.

## QuotaPolicy

Prerequisites (not deployed by the chart):

1. Redis for counters.
2. A dedicated rate-limit service for domain `ai-gateway-quota`, configured from the controller's xDS with node ID `envoy-ai-gateway-ratelimit`, listening at the chart value `controller.quotaRateLimitServiceAddr` (default `envoy-ai-gateway-ratelimit.envoy-gateway-system`, port 8081 if none). Example: `tests/e2e/testdata/backend_quota_ratelimit.yaml` in the repo.
3. Decide failure mode: `controller.quotaRateLimitFailureModeDeny` defaults to `false` (fail open: no enforcement if the service is missing). Set `true` to reject instead. `controller.quotaRateLimitTimeout` defaults to 5 seconds.

```yaml
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: QuotaPolicy
metadata: { name: qwen-budget, namespace: default }
spec:
  targetRefs:
    - {
        group: aigateway.envoyproxy.io,
        kind: AIServiceBackend,
        name: vllm-qwen,
      }
  perModelQuotas:
    - modelName: Qwen/Qwen3-32B # must equal the route's modelNameOverride
      quota:
        costExpression: "input_tokens + output_tokens * 4u"
        defaultBucket: { limit: 2000000, duration: "1d" }
        bucketRules:
          - clientSelectors:
              - headers: [{ name: x-tenant-id, type: Distinct }]
            quota: { limit: 200000, duration: "1d" }
            shadowMode: true # observe first, enforce later
```

Details:

- `modelName` only applies when it matches the `modelNameOverride` on the route's `backendRef`; otherwise the quota is silently not applied.
- Mode is `Shared` (only value): a request is charged to every matching bucket plus the default bucket, and allowed if at least one has room.
- Cost variables (all `uint`, so literals need `u`): `input_tokens`, `output_tokens`, `total_tokens`, `cached_input_tokens`, `cache_creation_input_tokens`, `reasoning_tokens`; strings `model`, `backend`, `route_name`.
- Header selector types: `Exact`, `Distinct`, `RegularExpression`.
- `serviceQuota` (backend-wide) exists in the API but is not enforced in this release.
- If several policies target the same model and backend, the alphabetically first namespace/name wins.
- QuotaPolicy is `v1alpha1` only; `kubectl get quotapolicies -A`.

## Verify

```bash
kubectl get quotapolicy,backendtrafficpolicy -A
kubectl get pods -A | grep -Ei 'ratelimit|redis'
# After a few requests, look for 429s and the limit source in Envoy logs
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=llm -c envoy --tail=50 | grep -E '" 429|response_code":429' || echo "no 429s yet"
```
