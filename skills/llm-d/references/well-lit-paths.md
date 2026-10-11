# Well-lit paths

> Verified against llm-d v0.10.0 (docs/well-lit-paths and the guides/ directory at release-0.10), 2026-10-11

Each guide under `guides/<name>/` is a tested recipe: a router values file plus a model-server kustomize overlay per
accelerator. They all follow the install in `install.md` (CRDs, namespace, token Secret, router chart, model server).
Read the guide README on the release branch for exact environment variables.

| Path (guide dir)                                                              | Use when                                                             | Default shape and needs                                                                                                                                                                          |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `optimized-baseline`                                                          | Start here for most vLLM, SGLang, TensorRT-LLM pools                 | Qwen3-32B, 8 replicas at TP=2 (16 GPUs). Prefix-cache affinity filter plus token-load scorer                                                                                                     |
| `precise-prefix-cache-routing`                                                | Multi-turn or agentic traffic with long shared prefixes              | vLLM publishes KV-cache events over ZMQ; the router indexes real block residency. vLLM `--block-size` 64 must match `tokenProcessorConfig.blockSizeTokens`; deploys a render (tokenizer) service |
| `predicted-latency-routing`                                                   | High variance in prompt and output length, per-request SLOs          | XGBoost model trained online by a sidecar; not for heterogeneous pools                                                                                                                           |
| `pd-disaggregation`                                                           | Medium to large models, long inputs (the guide cites 10k in, 1k out) | gpt-oss-120b, 8 prefill at TP=1 plus 2 decode at TP=4. KV moves with NixlConnector (UCX over RDMA or TCP) or MooncakeConnector (same TP both sides)                                              |
| `wide-ep`                                                                     | Very large MoE (DeepSeek-R1-0528)                                    | Prefill DP 16 plus decode DP 16 (32 GPUs, `DisaggregatedSet`), DeepEP over NVSHMEM, needs full-mesh InfiniBand or RoCE                                                                           |
| `tiered-prefix-cache`                                                         | Multi-turn working set larger than GPU KV memory                     | vLLM native `OffloadingConnector` (CPU RAM, optionally shared filesystem), LMCache, MooncakeStore, SGLang HiCache                                                                                |
| `p2p-kv-cache-sharing`                                                        | Reuse another pod's cached prefixes                                  | gpt-oss-120b, CPU to CPU over NIXL                                                                                                                                                               |
| `flow-control`                                                                | Multi-tenant priority and fairness, hold requests at saturation      | Feature gate in the EPP; classifies by `FlowKey` (fairness ID and priority); default policies mimic FCFS                                                                                         |
| `multi-model-routing`                                                         | Several base models behind one `/v1/chat/completions`                | Inference Payload Processor (IPP) maps the request model to `X-Gateway-Base-Model-Name`, HTTPRoutes pick the InferencePool                                                                       |
| `workload-autoscaling`                                                        | Scale on LLM signals                                                 | See `scaling-and-rollouts.md`                                                                                                                                                                    |
| `rollouts`                                                                    | Blue-green and adapter updates                                       | See `scaling-and-rollouts.md`                                                                                                                                                                    |
| `fast-model-actuation-*`, `modelexpress-p2p`, `pod-snapshot`                  | Faster cold starts                                                   | FMA dual-pod sleep/wake; GPU-to-GPU weight loading over NIXL (needs RDMA); GKE pod snapshots (single GPU)                                                                                        |
| `agentic-serving`, `batch-serving`, `multimodal-serving`, `diffusion-serving` | Workload-specific paths                                              | Read the guide; batch uses OpenAI-compatible Batch APIs and an async processor                                                                                                                   |
| `coord-disaggregation`                                                        | Encode/prefill/decode with a Coordinator service                     | **Experimental**, less mature than P/D                                                                                                                                                           |
| `no-kubernetes-deployment`                                                    | Router stack outside Kubernetes                                      | EPP, Envoy and servers as processes or containers                                                                                                                                                |

## Optimized baseline internals

`optimized-baseline.values.yaml` defines an `EndpointPickerConfig` (`apiVersion: llm-d.ai/v1alpha1`) with plugins
`approx-prefix-cache-producer`, `inflight-load-producer`, `prefix-cache-affinity-filter` and `token-load-scorer`, one
scheduling profile `default` running the filter then the scorer, and `modelServers.matchLabels: llm-d.ai/guide:
optimized-baseline`. The affinity filter narrows to endpoints holding the prefix unless they are saturated; the
saturation override depends on `peakPrefillThroughput` (default `15928`, measured for Qwen3-32B on H100 80 GB, TP=2).
For another model or accelerator set your own:

```yaml
- type: prefix-cache-affinity-filter
  parameters:
    peakPrefillThroughput: <measured value>
```

Measure it with `guides/recipes/router/calibration`.

## Prefill/decode and the sidecar

Disaggregation is built into the router: prefill pods and decode pods are separate pools; the decode pod runs the
`llm-d-router-disagg-sidecar` that coordinates the prefill call and KV hand-off. Enable the monitoring component
`monitoring-pd` for the prefill pool. Known NixlConnector limits (TP ratio direction, stale agent caching after
prefill restarts) are listed in `docs/operations/disaggregation`; read them before production. Engine-side
background: skill `disaggregated-serving`. The `pd-disaggregation` guide has a `DisaggregatedSet` variant
(`README.ds.md`) that manages the P/D topology as one LeaderWorkerSet resource with coordinated rollouts.

## Choosing quickly

- No RDMA fabric and mid-size model: baseline, then tiered KV offload if hit rate drops under load.
- RDMA fabric, long prompts: P/D.
- Cache hit rate matters and traffic is sticky: precise prefix-cache routing (needs the render service and vLLM
  KV-events config from the guide).
- One pool, many tenants: flow control on top of baseline.

## Sources

- <https://llm-d.ai/docs/well-lit-paths>
- <https://github.com/llm-d/llm-d/tree/release-0.10/guides>
