# Combo: KEDA and plain vLLM Deployments

> Verified against KEDA v2.21.0, 2026-10-11

For a vLLM Deployment you run yourself (skill `vllm`), with Prometheus scraping the pods.

## Wiring

1. Scrape: a PodMonitor or ServiceMonitor on the port that serves `/metrics` (same port as the API, `:8000` by default).
2. Check the series exist: `vllm:num_requests_waiting`, `vllm:num_requests_running`, `vllm:kv_cache_usage_perc`.
3. Apply `templates/scaledobject-vllm.yaml`.
4. Make the Deployment scale-friendly: a readiness probe on `/health`, a startup probe long enough for the model load,
   `terminationGracePeriodSeconds` that covers in-flight generations, `replicas` omitted from the manifest if applied by
   GitOps (otherwise the tool resets the count).
5. One GPU per replica (or TP size per replica): KEDA multiplies replicas, so `maxReplicaCount` x GPUs per replica must fit the cluster.

## Notes

- Waiting stays near 0 until the engine is saturated; set the threshold low (single digits) so scale-out starts early.
- Use the cache-usage guard trigger for long-context traffic (`references/llm-triggers.md`).
- Prefix-cache-aware routing across replicas: put a router in front (`gateway-api-inference-extension`, `prefix-aware-routing`).
  Scale-in loses warm KV caches; keep the scale-down slow.
- KServe: do not hand-write this; use skill `vllm-kserve-keda`.
