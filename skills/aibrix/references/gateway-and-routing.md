# Gateway and routing

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

The gateway (Envoy Gateway plus the `aibrix-gateway-plugins` external processor) is the single entry. Find its
address:

```bash
SVC=$(kubectl get svc -n envoy-gateway-system -o name | grep envoy-aibrix | head -1)
kubectl -n envoy-gateway-system get $SVC -o jsonpath='{.status.loadBalancer.ingress[0].ip}'    # EKS shows .hostname
kubectl -n envoy-gateway-system port-forward $SVC 8888:80
```

## Strategies

Set per request with the `routing-strategy` header, globally with the `ROUTING_ALGORITHM` env on the gateway
plugin, or per model with the config annotation.

- **Load:** `random`, `least-request`, `least-busy-time`, `least-latency`, `least-kv-cache`, `least-gpu-cache`,
  `least-utilization`, `throughput`, `power-of-two`.
- **KV-cache aware:** `prefix-cache`, `prefix-cache-preble`.
- **Fairness:** `vtc-basic`. **SLO-aware:** `slo`, `slo-pack-load`, `slo-least-load`, `slo-least-load-pulling`.
- **Specialized:** `pd` (prefill/decode), `session-affinity` (sticky via the `x-session-id` response header, a
  base64 pod address, not a security token).

Some strategies read Prometheus metrics (PromQL); configure Prometheus access per the observability doc.

## Headers

Request: `routing-strategy`, `user` (rate-limit identity), `external-filter` (Kubernetes label selector, such as
`environment=production,tier=frontend`, narrows candidate pods; only with `routing-strategy`; an empty result
fails with "no ready pods for routing"). Debug response headers: `target-pod`, `request-id`, `x-error-user`,
`x-error-routing`, `x-error-response-unmarshal`.

## Rate limiting and auth

Per-user RPM and TPM limits apply when the `user` header is present (users are managed through the metadata
service; see `pkg/metadata/README.md` in the repo). Authentication is delegated to the engine: vLLM `--api-key` or
`VLLM_API_KEY`; clients send `Authorization: Bearer <key>`. The gateway is internet-facing if exposed, so enable it.

## Several gateway replicas

Set `gatewayPlugin.replicaCount`, give Redis both `gatewayPlugin.dependencies.redis` (empty host uses the
chart-managed `<release>-redis-master`) and `gatewayPlugin.container.envs.AIBRIX_STATESYNC_ENABLED: "true"`
(default false). Without state sync, multi-replica `prefix-cache` routing is inconsistent. Size the bundled Redis
under `metadata.redis`. Envoy proxy replicas and resources live under `gateway.envoyProxy`.

## Sources

- <https://aibrix.readthedocs.io/latest/features/gateway-plugins.html>
- <https://aibrix.readthedocs.io/latest/production/gateway.html>
