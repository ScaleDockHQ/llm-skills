# LLMInferenceService reference

> Verified against KServe v0.21.0 (website llmisvc docs, repo samples under docs/samples/llmisvc, CRD templates), 2026-10-11

`LLMInferenceService` (group `serving.kserve.io`) is KServe's generative-AI resource, built on the llm-d
architecture. The CRD serves `v1alpha1` and stores `v1alpha2`; upstream samples use `v1alpha2`, some doc pages
still show `v1alpha1`. Use `v1alpha2`.

## Spec map

| Field              | Meaning                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `spec.model`       | `uri` (`hf://`, `s3://`, `pvc://`), `name` (served model name), LoRA adapters, criticality |
| `spec.replicas`    | Replica count. Mutually exclusive with `spec.scaling`                                      |
| `spec.template`    | Pod spec of the main (single-node or decode) workload; container name `main`               |
| `spec.worker`      | Multi-node worker pod spec; its presence triggers a LeaderWorkerSet                        |
| `spec.prefill`     | Prefill-only workload (`replicas`, `template`, `worker`) for disaggregated serving         |
| `spec.parallelism` | `tensor`, `data`, `dataLocal`, `expert` (bool), `dataRPCPort`                              |
| `spec.router`      | `gateway`, `route`, `scheduler` (each `{}` for managed defaults, or a `ref`)               |
| `spec.scaling`     | WVA autoscaling (`minReplicas`, `maxReplicas`, `wva`, HPA or KEDA actuator)                |
| `spec.baseRefs`    | Compose `LLMInferenceServiceConfig` presets (see below)                                    |

An empty `router: {gateway: {}, route: {}, scheduler: {}}` creates a managed Gateway, HTTPRoute, an
InferencePool, an InferenceModel and the Endpoint Picker (EPP) deployment. Omit `scheduler` to get plain Kubernetes
Service load balancing with no cache-aware routing or prefill/decode support.

## Single node on GPU

See `templates/llmisvc-gpu.yaml`. Upstream sample (`single-node-gpu`): Qwen2.5-7B-Instruct, three replicas, one
GPU each, `/health` liveness probe on HTTPS port 8000 with a 120 s initial delay.

The default preset image in the v0.21.0 repo is `ghcr.io/llm-d/llm-d-cuda:v0.9.0` and the scheduler image is
`ghcr.io/llm-d/llm-d-router-endpoint-picker:v0.10.0` (`config/llmisvcconfig`). Override `spec.template.containers[0].image`
to pin your own vLLM build. llm-d deprecated `ghcr.io/llm-d/llm-d-cuda` builds in its v0.10.0 release in favor of
`docker.io/vllm/vllm-openai`, so prefer an explicit vLLM image for new deployments.

## Multi-node and parallelism

```yaml
spec:
  parallelism:
    tensor: 4 # TP degree
    data: 8 # total data-parallel ranks
    dataLocal: 4 # ranks per node; 8/4 = 2 LWS replicas
    expert: true # EP for MoE models
  worker: {} # worker pod spec, triggers LeaderWorkerSet
```

Needs the LeaderWorkerSet operator. `spec.template` is the leader pod. Upstream DP/EP sample:
`docs/samples/llmisvc/dp-ep/deepseek-r1-gpu-rdma-roce` (RDMA over RoCE).

## Prefill/decode disaggregation

`spec.prefill` adds a second pool; `spec.template` becomes the decode pool. KV blocks move prefill to decode
through vLLM's `NixlConnector`, configured in the sample via
`VLLM_ADDITIONAL_ARGS=--kv_transfer_config '{"kv_connector":"NixlConnector","kv_role":"kv_consumer"}'`,
`VLLM_NIXL_SIDE_CHANNEL_HOST` from `status.podIP`, UCX variables, and a RoCE network annotation
(`k8s.v1.cni.cncf.io/networks`). The sample's EPP config uses prefill threshold `0` (always split), prefix-cache
scorer weight 2.0 and load-aware scorer weight 1.0. Without RDMA hardware, do not enable it.

## Router and scheduler

- Managed gateway: `gateway: {}`. Referenced gateway: point `gateway.refs` at an existing `Gateway`.
- Route: `route: {}` managed; supports a referenced `HTTPRoute` or a custom spec, and the `group` and `weight`
  fields for canary (see `scaling-and-rollout.md`).
- Scheduler: `scheduler: {}` managed; reference an existing `InferencePool` via `pool.ref`; custom EPP via a
  `ConfigMap` holding an `EndpointPickerConfig`. Precise prefix-cache routing and latency predictor samples are in
  `docs/samples/llmisvc/precise-prefix-kv-cache-routing` and `.../latency-predictor`.

## Config composition

`LLMInferenceServiceConfig` objects are reusable fragments (model, workload template, router, scheduler). A service
merges them from `spec.baseRefs`, then its own spec. The v0.21.0 repo ships these presets in `config/llmisvcconfig`:
`config-llm-template`, `-decode-template`, `-prefill-template`, `-worker-data-parallel`,
`-router-route`, `-scheduler`, `-scheduler-eppconfig-default[-pd]`, `-scheduler-latency-predictor`, `-tokenizer`,
`-tracing`. If a referenced config cannot be resolved, the `PresetsCombined` condition fails and the reconciler
stops before creating workloads.

```bash
kubectl get llminferenceserviceconfig -A
kubectl get llminferenceserviceconfig <name> -n kserve -o yaml | less
```

## Status

`Ready` = `WorkloadsReady` and `RouterReady`. Sub-conditions appear only when the feature is on:
`MainWorkloadReady`, `WorkerWorkloadReady`, `PrefillWorkloadReady`, `ScalingReady`, `GatewaysReady`,
`HTTPRoutesReady`, `InferencePoolReady`, `SchedulerWorkloadReady`. The set present tells you the topology.

```bash
kubectl get llminferenceservice <n> -n <ns> -o json | jq '.status.conditions[]|{type,status,reason,message}'
```

## Sources

- <https://kserve.github.io/website/docs/model-serving/generative-inference/llmisvc/llmisvc-overview> (and `llmisvc-configuration`, `llmisvc-config-composition`, `llmisvc-status`)
- <https://github.com/kserve/kserve/tree/v0.21.0/docs/samples/llmisvc>
- <https://github.com/kserve/kserve/tree/v0.21.0/config/llmisvcconfig>
