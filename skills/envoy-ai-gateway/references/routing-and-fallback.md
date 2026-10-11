# Routing, fallback, aliases and mutations

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs, CRDs and examples (provider_fallback), 2026-10-11

## How routing works

The gateway's ext-proc reads `model` from the request body and sets the header `x-ai-eg-model`. `AIGatewayRoute.spec.rules[].matches` match on that header; the first matching rule's `backendRefs` serve the request. Model selection can also be done by sending the header yourself. No matching rule gives 404.

```yaml
apiVersion: aigateway.envoyproxy.io/v1beta1
kind: AIGatewayRoute
metadata: { name: llm, namespace: default }
spec:
  parentRefs:
    - { name: llm, kind: Gateway, group: gateway.networking.k8s.io }
  rules:
    - matches:
        - headers:
            - { type: Exact, name: x-ai-eg-model, value: qwen3-32b }
      backendRefs:
        - name: vllm-qwen # AIServiceBackend
          modelNameOverride: Qwen/Qwen3-32B
    - matches:
        - headers:
            - { type: RegularExpression, name: x-ai-eg-model, value: "gpt-.*" }
      backendRefs:
        - { name: openai }
```

`backendRefs` fields: `name`, `weight` (default 1, same as Gateway API), `priority` (default 0; lower is preferred), `modelNameOverride`, `namespace` (needs a `ReferenceGrant`), `group`+`kind` (only `InferencePool`). Per-ref `headerMutation` and `bodyMutation` also exist (below). `weight` splits traffic across refs with the same priority; `priority` creates fallback tiers.

A rule can set `excludeFromModelsEndpoint: true` (v1.2.0) to keep an alias out of `/v1/models` and `/anthropic/v1/models` while it still routes. `GET /v1/models` lists the model names your routes match.

## Model name virtualization

Clients use one stable name; each backend gets its own via `modelNameOverride`:

```yaml
rules:
  - matches:
      [
        {
          headers: [{ type: Exact, name: x-ai-eg-model, value: claude-sonnet }],
        },
      ]
    backendRefs:
      - {
          name: anthropic-direct,
          priority: 0,
          modelNameOverride: <anthropic model id>,
        }
      - {
          name: bedrock-claude,
          priority: 1,
          modelNameOverride: <bedrock model id>,
        }
```

Model IDs differ by provider (Bedrock IDs, Vertex `@` snapshots); take them from the provider's current list, not from memory. Azure OpenAI ignores the body `model` and uses the deployment name in the URL; responses report the real versioned model. Metrics keep `gen_ai.original.model` (client-supplied), `gen_ai.request.model` (after override) and `gen_ai.response.model`. A `QuotaPolicy` `modelName` must equal the route's `modelNameOverride`.

## Provider fallback

Fallback is priority plus retries, not a separate resource. Put the primary at `priority: 0` and the fallback at `priority: 1`, then attach a `BackendTrafficPolicy` to the generated `HTTPRoute` (same name as the `AIGatewayRoute`) so failures retry onto the next priority. Template: `assets/fallback-policy.yaml`.

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata: { name: llm-fallback, namespace: default }
spec:
  targetRefs:
    - { group: gateway.networking.k8s.io, kind: HTTPRoute, name: llm }
  retry:
    numRetries: 5
    numAttemptsPerPriority: 1 # one try per tier, then move to the next
    perRetry:
      backOff: { baseInterval: 100ms, maxInterval: 10s }
      timeout: 30s
    retryOn:
      httpStatusCodes: [500]
      triggers: [connect-failure, retriable-status-codes]
```

Notes:

- Add `429`, `502`, `503`, `504` to `httpStatusCodes` if rate limits and overloads should fail over. Add `reset` or `5xx` triggers per Envoy Gateway retry docs.
- Retries replay the request body; a per-request credential header can reach the fallback backend. Prefer `credentialOverride.fromDynamicMetadata` on fallback routes.
- Schemas can differ per tier (OpenAI primary, Bedrock fallback); the gateway translates. Features missing in the fallback provider (tools, structured output) fail there.
- Do not also retry in the client or LiteLLM; one layer owns retries.
- Streaming responses that have started cannot be retried onto another provider.
- Weighted load balancing for same-model replicas: give refs the same `priority` and different `weight`. For GPU replicas, an InferencePool does endpoint-aware balancing (`mcp-and-inference.md`).
- Timeouts for long generations: set `BackendTrafficPolicy.timeout` and, for streams, see `examples/stream_idle_timeout`.

Test it (read-only except one request):

```bash
kubectl get httproute,backendtrafficpolicy -n default
curl -sS -i -H 'Content-Type: application/json' -d '{"model":"claude-sonnet","messages":[{"role":"user","content":"ping"}]}' "$GATEWAY_URL/v1/chat/completions" | head -20
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=llm -c envoy --tail=20 | jq -r '.upstream_host? // .' 2>/dev/null
```

## Header and body mutations

Per `AIServiceBackend` (all traffic to it) or per route `backendRef` (that rule only; route-level wins on conflict):

```yaml
headerMutation:
  set: [{ name: x-team, value: platform }] # max 16
  remove: [x-internal-header] # case-insensitive, max 16
bodyMutation:
  set: [{ path: service_tier, value: '"flex"' }] # JSON values, quoted strings
  remove: [user]
```

Use for provider-specific headers, forcing `service_tier` or `max_tokens`, and stripping fields upstreams reject. `AIServiceBackend.spec.headerValueFilters` (v1.2.0, Anthropic-style schemas) drops or allow-lists individual `anthropic-beta` values per backend. Check the field names with `kubectl explain aiservicebackend.spec --api-version=aigateway.envoyproxy.io/v1beta1 --recursive | head -60` before relying on them.

## Vendor-specific fields

Provider extensions go inline in the OpenAI-shaped request and are applied after the standard translation. A unified `thinking` field maps to Gemini `generationConfig.thinkingConfig` on Vertex, and is used directly for GCP Anthropic and Bedrock. Vertex also takes `safetySettings`. The "Extension fields" docs list the supported fields per schema; check them before relying on one.

## Other Envoy Gateway policies that apply

`ClientTrafficPolicy` (buffers, HTTP/2 windows, TLS), `BackendTrafficPolicy` (retries, timeouts, circuit breakers, rate limits), `SecurityPolicy` (inbound auth, CORS), `EnvoyProxy` (replicas, resources, access log). They attach to the Gateway, the generated HTTPRoute or the `Backend` through `targetRefs`.
