# InferencePool, HTTPRoute and model servers

> Verified against Gateway API Inference Extension v1.6.2 (site docs `api-types/inferencepool`, `reference/spec`, model server protocol proposal) and llm-d router v0.11.0, 2026-10-11

## InferencePool (`inference.networking.k8s.io/v1`, GA since v1.0.0)

```yaml
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata:
  name: vllm-qwen3-32b
spec:
  selector:
    matchLabels: { app: vllm-qwen3-32b } # same namespace as the pool; exact match on pod labels
  targetPorts:
    - number: 8000 # 1 to 8 ports; each podIP:port is its own endpoint
  endpointPickerRef:
    name: vllm-qwen3-32b-epp
    port: { number: 9002 } # EPP Service port (ext-proc)
    failureMode: FailOpen # API default is FailClose
```

- `appProtocol`: `http` (default) or `kubernetes.io/h2c`.
- `endpointPickerRef`: `group`, `kind` (default `Service`), `name`, `port` (required for a Service), `failureMode`.
- Status: `status.parents[]` (up to 32) reports, per Gateway, whether the pool is accepted and its refs resolved.
- Replaces a `Service` as the **backend**: it is not a Service, it carries the EPP reference.
- The chart creates the pool for you (`router.inferencePool.create=true`); write it by hand only when running the EPP yourself.

## HTTPRoute to the pool

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: vllm-qwen3-32b }
spec:
  parentRefs: [{ name: inference-gateway }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs:
        - group: inference.networking.k8s.io
          kind: InferencePool
          name: vllm-qwen3-32b
      timeouts: { request: 300s } # LLM requests are long; the llm-d guide sample uses 30s, the chart default is 300s
```

Streaming and long generations need generous request timeouts on the Gateway and any load balancer in front.
Several pools (several base models) on one Gateway: add a rule per pool and route by path or by a header; body-based
model routing was split to `llm-d/llm-d-inference-payload-processor` (the old BBR package moved), check its docs.

## Requirements for the pods in a pool

- Same base model, accelerator type and model server in the pool; one pool per base model (LoRA adapters of one base
  model share a pool).
- Implement the OpenAI completions and chat APIs.
- Prometheus endpoint with queue length, running requests and KV-cache use. vLLM: `vllm:num_requests_waiting`,
  `vllm:num_requests_running`, `vllm:kv_cache_usage_perc`. Other engines (from the protocol doc): Triton TensorRT-LLM
  `nv_trt_llm_request_metrics`, trtllm-serve `trtllm_num_requests_waiting`, SGLang `sglang:num_queue_reqs`,
  `sglang:num_running_reqs`, `sglang:token_usage`. Set `router.modelServers.type` to match.
- LoRA affinity needs `vllm:lora_requests_info` with `max_lora`, `running_lora_adapters`, `waiting_lora_adapters`.
- Prefix-cache aware scoring wants prefix caching enabled on the engine (vLLM automatic prefix caching).
- Readiness probes that reflect real readiness: the EPP discovers pods through the InferencePool selector and Pod status.

## Verify

```bash
kubectl get inferencepool vllm-qwen3-32b -o yaml | sed -n '/status:/,$p'
kubectl get endpoints,pods -l app=vllm-qwen3-32b -o wide
GW=$(kubectl get gateway inference-gateway -o jsonpath='{.status.addresses[0].value}')
curl -s http://$GW/v1/models | jq '.data[].id'
curl -s http://$GW/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"<served-model-name>","messages":[{"role":"user","content":"hi"}],"max_tokens":16}' | jq '.choices[0].message'
```

## Sources

https://gateway-api-inference-extension.sigs.k8s.io/, https://github.com/kubernetes-sigs/gateway-api-inference-extension
