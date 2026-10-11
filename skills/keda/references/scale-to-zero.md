# Scale to zero for LLM serving

> Verified against KEDA v2.21.0, 2026-10-11

## How activation works

KEDA owns 0 to 1 (the `IsActive` check of each trigger, polled every `pollingInterval`); the HPA owns 1 to N. A
scaler activates only when its value is **greater than** `activationThreshold` (default 0). Scale to zero needs
`minReplicaCount: 0` (the default) and at least one non-CPU, non-memory trigger. After the last active trigger,
KEDA waits `cooldownPeriod` (300 s default) before dropping to 0.

## The trap: the signal disappears with the pods

`vllm:num_requests_waiting` is exported by the vLLM pod. With zero pods there is no series, so a Prometheus query on
it returns nothing and (with `ignoreNullValues: "true"`, the default) reads as 0: **the deployment never wakes up**.
Requests either fail or wait in front of the model. Pick a signal that survives zero replicas:

| Option                   | How                                                                                                                                         | Cost                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Gateway or router metric | Query request counters or in-flight gauge from the layer in front (Envoy/Gateway API gateway, LiteLLM, EPP) with `rate(...[1m])` or a gauge | Needs a front layer that queues or retries.                                           |
| KEDA HTTP add-on         | An interceptor holds requests while KEDA scales the Deployment from 0                                                                       | Beta (v0.16.0); streaming and long-lived LLM connections need a load test; extra hop. |
| Queue trigger            | Async/batch: jobs wait in RabbitMQ, SQS, Redis                                                                                              | Not for interactive chat.                                                             |
| Cron trigger             | Warm the model for office hours, scale in at night                                                                                          | Cannot react to surprise load.                                                        |

Combine them: a gateway-based trigger for 0 to 1 and the vLLM waiting trigger for scale-out. Both live on the same
ScaledObject; the HPA uses the highest.

## Cold start budget

Time from request to first token = scheduling + (GPU node provisioning) + image pull + weight download/load + warm-up.
Measure it on the real model. Reduce it with a pre-pulled image, weights on a shared PVC or local NVMe, or a model
cache; and set client timeouts above it. Use `initialCooldownPeriod` so a just-created ScaledObject does not kill a
loading pod, and `idleReplicaCount: 0` with `minReplicaCount: 1` if you want "one warm replica while active, zero when idle".

## HTTP add-on (v0.16.0, beta)

- Chart `kedacore/keda-add-ons-http` 0.16.0 (a separate Helm release); routing is configured with `InterceptorRoute`
  custom resources. Confirm the CRD shape on your cluster: `kubectl explain interceptorroute.spec`.
- The interceptor holds pending requests during cold start; v0.16.0 can bound that queue
  (`coldStart.maxPendingRequests`, `coldStart.overflow`) and exports `interceptor_cold_start_duration_seconds`.
- It can route direct to pod IPs (bypassing the Service, kube-proxy and Service-level policies).
- It is declared beta with minor breaking changes still possible before v1.0. Test with streamed completions
  (SSE) and your longest generation before relying on it.
- Docs: keda.sh/http-add-on/latest.

## Rules

- Do not enable scale to zero on a shared or latency-sensitive endpoint without telling the user the cold start.
- Never rely on a trigger that is derived from the pods you are scaling to zero.
- GPU node autoscalers add their own minutes; include them in the budget.
