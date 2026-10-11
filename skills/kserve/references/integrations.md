# Integrations: gateways, clients, observability, security

> Verified against KServe v0.21.0 (website Envoy AI Gateway and llmisvc docs, repo config presets), 2026-10-11

## Endpoints

| Resource              | Base URL                                                                                         |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| `LLMInferenceService` | `<gateway>/<namespace>/<name>/v1/...` (`status.url` gives the root), OpenAI completions and chat |
| `InferenceService`    | `<isvc-url>/openai/v1/...` with the `huggingface` runtime                                        |

Get the URL and test with a port-forward when there is no external load balancer:

```bash
kubectl get llminferenceservice <n> -n <ns> -o jsonpath='{.status.url}{"\n"}'
SVC=$(kubectl get svc -n envoy-gateway-system -l serving.kserve.io/gateway=kserve-ingress-gateway -o name | head -1)
kubectl port-forward -n envoy-gateway-system "$SVC" 8001:80 &
curl -s http://localhost:8001/<ns>/<name>/v1/models | jq
```

## LiteLLM or any OpenAI client

KServe speaks the OpenAI protocol; register it as an OpenAI-compatible upstream. Keys and budgets belong in the
gateway (skill `litellm`), not in the model service.

```yaml
model_list:
  - model_name: qwen
    litellm_params:
      model: openai/Qwen/Qwen2.5-7B-Instruct # the spec.model.name
      api_base: http://<gateway-host>/<ns>/<name>/v1
      api_key: os.environ/KSERVE_API_KEY # only if you enable auth upstream
```

Inside the cluster, point `api_base` at the in-cluster gateway Service DNS name, not a port-forward.

## Envoy AI Gateway

KServe docs integrate an `InferenceService` with the Envoy AI Gateway in the same or a different cluster (AIGatewayRoute,
backends, API-key security policy, token-rate limiting). Both gateway pieces are already prerequisites of the llmisvc
install, so you can attach rate limits and API keys at the gateway. Follow
<https://kserve.github.io/website/docs/model-serving/generative-inference/ai-gateway/envoy-ai-gateway> and the llmisvc
variant `llmisvc-envoy-ai-gateway`; a `llmisvc-agentgateway` page documents the agentgateway option.

## Observability

- Engine metrics: vLLM serves `/metrics`; `InferenceService` sets Prometheus annotations
  (`prometheus.kserve.io/port: '8080'`, `/metrics` in the runtime). For `LLMInferenceService`, scrape the workload pods
  with a `PodMonitor` selecting the labels from `kubectl get pods -n <ns> --show-labels`.
- Useful vLLM series for scaling: `vllm:num_requests_running`, `vllm:num_requests_waiting` (see `vllm`).
- Scheduler: the EPP pod (`SchedulerWorkloadReady`) exposes scheduling metrics; the `llm-d` skill lists them.
- Tracing: the repo ships a `config-llm-tracing` preset; enable it by adding it to `spec.baseRefs`.
- Status: `kubectl get llminferenceservice -A` and the condition tree in `llminferenceservice.md`.

## Security

- Keep model Services internal; expose only the Gateway. Add NetworkPolicies so only the gateway reaches workloads.
- v0.21.0 added integration with the cluster TLS security profile and hardened controller ClusterRoles.
- Pod `securityContext`: the CPU demo image needs `runAsNonRoot: false`; GPU images from the llm-d presets run as
  designed, so do not copy that override.
- Hugging Face and cloud credentials: Secrets referenced from `ClusterStorageContainer` or the service account.
  Never print them; create from `0600` files.

## Sources

- <https://kserve.github.io/website/docs/model-serving/generative-inference/ai-gateway/envoy-ai-gateway>
- <https://github.com/kserve/kserve/tree/v0.21.0/config/llmisvcconfig>
