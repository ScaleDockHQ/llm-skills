# Disaggregated serving: orchestrators and KV transports

> Verified against NVIDIA Dynamo v1.5.1 (docs: cli/disaggregated-serving, system-architecture/disaggregated-serving, router configuration-and-tuning, frontend-configuration; examples/backends launch scripts), llm-d v0.10.0 (docs: architecture/advanced/disaggregation, operations/disaggregation/vllm, guides/pd-disaggregation), llm-d-router v0.11.0 (disagg plugin README), vLLM production-stack vllm-stack-0.1.13, AIBrix v0.7.0, NIXL v1.5.0, Mooncake v0.3.13.post1, 2026-10-11

A bare engine pair needs something that sends each request to prefill, collects the transfer metadata, then calls decode. These products do that. Pick by where you run.

| You run                                 | Use                                                                                              | Engines                    |
| --------------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------- |
| One or a few GPU servers, no Kubernetes | Dynamo CLI presets, SGLang router, `trtllm-serve disaggregated`, or the vLLM toy proxy for tests | vLLM, SGLang, TensorRT-LLM |
| Kubernetes with Gateway API             | llm-d (EPP + decode sidecar)                                                                     | vLLM, SGLang               |
| Kubernetes, vLLM only                   | vLLM production-stack router                                                                     | vLLM                       |
| Kubernetes with Envoy Gateway           | AIBrix `routing-strategy: pd`                                                                    | vLLM                       |

## NVIDIA Dynamo v1.5.1

Frontend plus typed prefill and decode workers; KV moves GPU to GPU over NIXL. The frontend's `PrefillRouter` picks a prefill worker (KV-aware or load-based), sends the prefill request, receives `disaggregated_params`, picks a decode worker and injects the metadata. Workers join and leave at runtime (runtime-reconfigurable xPyD); the frontend discovers them. Discovery backend default is `etcd`.

Local presets (read them before running them): `examples/backends/{vllm,sglang,trtllm}/launch/disagg.sh` (2 GPUs) and `disagg_router.sh` (adds KV-aware routing).

What each backend launches (from the v1.5.1 scripts):

```bash
python -m dynamo.frontend &                                   # HTTP port 8000 by default
# vLLM
python3 -m dynamo.vllm --model "$MODEL" --disaggregation-mode decode  \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both"}'
VLLM_NIXL_SIDE_CHANNEL_PORT=20097 python3 -m dynamo.vllm --model "$MODEL" --disaggregation-mode prefill \
  --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both"}'
# SGLang
python3 -m dynamo.sglang --model-path "$MODEL" --disaggregation-mode prefill \
  --disaggregation-bootstrap-port 12345 --disaggregation-transfer-backend nixl --page-size 16 --tp 1
python3 -m dynamo.sglang --model-path "$MODEL" --disaggregation-mode decode \
  --disaggregation-bootstrap-port 12345 --disaggregation-transfer-backend nixl --page-size 16 --tp 1
# TensorRT-LLM
python3 -m dynamo.trtllm --model-path "$MODEL" --extra-engine-args prefill.yaml --disaggregation-mode prefill
python3 -m dynamo.trtllm --model-path "$MODEL" --extra-engine-args decode.yaml  --disaggregation-mode decode
```

- Every vLLM worker on a host needs a unique `VLLM_NIXL_SIDE_CHANNEL_PORT` (the presets set them). The shipped example still uses `kv_role: kv_both`, while vLLM v0.31.0 marks `kv_both` deprecated for NixlConnector. Check the Dynamo release notes before changing it.
- The transfer metadata the frontend forwards differs per backend: SGLang `bootstrap_info`, vLLM `kv_transfer_params`, TensorRT-LLM `opaque_state`.
- With KV-aware routing and vLLM, set `PYTHONHASHSEED=0` on every vLLM process so block hashes agree across workers.
- Router and frontend flags (see the `prefix-aware-routing` skill for the full list): `--router-mode kv`, `--router-conditional-disagg` (**experimental**; read the router docs for its prerequisites), `--decode-fallback` (default `false`: fall back to aggregated when no prefill workers exist).
- TensorRT-LLM prefill YAML in the example: `cache_transceiver_config: {backend: DEFAULT}`, `disable_overlap_scheduler: true`, `enable_chunked_prefill: true`.
- Kubernetes: multinode workloads need Grove + KAI Scheduler (default) or LeaderWorkerSet >= v0.7.0 with Volcano for gang scheduling. Dynamo 1.5.x needs KAI Scheduler >= v0.17.0 and Grove >= v0.1.0-alpha.13 when installed externally.
- Dynamo documents that at low concurrency aggregated serving often wins, that separate pools help under sustained prefill/decode contention, and that when decode KV capacity is the bottleneck, adding prefill replicas can reduce total capacity.
- Multinode Dynamo sizing tools (AIConfigurator, Planner) and DynamoGraphDeployment fields: **unverified** here.

## llm-d v0.10.0 (router: llm-d-router v0.11.0)

Kubernetes-native. Prefill and decode pods are in **one** `InferencePool`, told apart by the label `llm-d.ai/role` with values `prefill`, `decode` or `prefill-decode`. Decode pods carry a routing-proxy **sidecar**. Flow: gateway -> EPP picks D (and P if the decider says so) -> sidecar on D sends the request to P with `max_tokens=1` and `do_remote_decode=True` -> D pulls KV from P over NIXL -> D decodes.

EPP config skeleton (plugin type names from the llm-d P/D guide and the llm-d-router plugin READMEs; scorer and picker plugins and the `schedulingProfiles` wiring must be copied from the guide for your release, they are not reproduced here):

```yaml
apiVersion: llm-d.ai/v1alpha1
kind: EndpointPickerConfig
plugins:
  - type: prefix-based-pd-decider # or always-disagg-pd-decider
    parameters: { nonCachedTokens: 256 }
  - type: disagg-profile-handler
    parameters:
      deciders:
        prefill: prefix-based-pd-decider
  - type: prefill-filter
  - type: decode-filter
  - type: approx-prefix-cache-producer
  - type: inflight-load-producer
  - type: prefix-cache-affinity-filter
    parameters: { peakPrefillThroughput: <measure> }
  - type: token-load-scorer
# schedulingProfiles: one `prefill` and one `decode` profile, see the guide
```

`nonCachedTokens: 256` is an illustrative starting point, not an upstream recommendation. The guide's `peakPrefillThroughput` is hardware- and model-specific; measure your own and never copy the guide's number.

| Plugin / setting                                                    | Default                                | Meaning                                                                                           |
| ------------------------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `disagg-profile-handler` `profiles.decode` / `.prefill` / `.encode` | `decode` / `prefill` / `encode`        | Names of the scheduling profiles. Decode always runs first.                                       |
| `disagg-profile-handler` `deciders.prefill`                         | none (P/D off)                         | Name of a decider plugin declared earlier in the same file.                                       |
| `prefix-based-pd-decider` `nonCachedTokens`                         | `0` (decider off, never disaggregates) | Disaggregate only if the uncached prompt suffix on the chosen D pod is at least this many tokens. |
| `prefix-based-pd-decider` `promptTokens`                            | `0` (gate off)                         | Prompts shorter than this never disaggregate.                                                     |
| `prefix-based-pd-decider` `prefixMatchInfoProducerName`             | `approx-prefix-cache-producer`         | Which prefix producer to read.                                                                    |
| `always-disagg-pd-decider`                                          | n/a                                    | Always runs prefill remotely.                                                                     |

Sidecar: vLLM protocol `nixlv2` (default), SGLang protocol `sglang`. Routing header: `x-prefiller-host-port`. For SGLang, the sidecar env `SGLANG_BOOTSTRAP_PORT` must match the engine's `--disaggregation-bootstrap-port`. The sidecar flag that selects the protocol was not verified.

Operational facts from the vLLM operations page:

- A new P-D pair does a one-time NIXL handshake (about 5 s); connections are lazy, no central bootstrap server. Pods join via normal `InferencePool` label selection when `Running`.
- Scale-down of **prefill** pods can fail in-flight KV loads on decode. Set decode `kv_load_failure_policy=recompute` only if you accept recompute jitter; default `fail` is recommended.
- Prefill holds KV for `kv_lease_duration` (default 30 s, vLLM >= v0.22.0 per llm-d) while waiting for decode. Cancelled requests leave a window in which P still holds the blocks.
- vLLM `--shutdown-timeout N` exists for draining on shutdown (exact semantics: read the llm-d page).
- The guide's reference shape: 8 TP=1 prefill pods and 2 TP=4 decode pods (vLLM). Heterogeneous TP is therefore the common case.
- NIXL over TCP works but is for testing; use IB, RoCE or EFA in production.

## vLLM production-stack (Helm chart vllm-stack-0.1.13)

The router has `--routing-logic disaggregated_prefill` and `disaggregated_prefill_orchestrated`. Prefill and decode backends are told apart by model label: `--prefill-model-labels` and `--decode-model-labels` (comma separated, default none). The tutorial wires the engines through LMCache NIXL settings in the Helm values (`enableNixl: true`, `nixlRole: sender|receiver`, `nixlPeerHost`, `nixlPeerPort: "55555"`, `nixlBufferSize`, `nixlBufferDevice: cuda`) and `routerSpec.routingLogic: "disaggregated_prefill"`. This path is LMCache-based, not the vLLM NixlConnector path above. Verify the chart's disaggregated-prefill tutorial for the image tags it pins.

## AIBrix v0.7.0

Per-request header `routing-strategy: pd` selects prefill-decode routing at the Envoy-based gateway; `ROUTING_ALGORITHM` sets the global default. Deployment details for PD pods (labels, engine flags) were **not verified** for this skill.

## SGLang Model Gateway (formerly the SGLang router)

See `engine-flags.md`. It is the supported front end for SGLang PD without Kubernetes: `--pd-disaggregation`, `--prefill`, `--decode`, per-side policies, circuit breaker and retries, Kubernetes service discovery via `--prefill-selector` and `--decode-selector`.

## Transports

| Transport                 | Used by                                                                                     | Facts                                                                                                                                                                                                                                           |
| ------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NIXL (`pip install nixl`) | vLLM NixlConnector, SGLang `nixl` backend, TensorRT-LLM `NIXL` backend, Dynamo, llm-d       | Linux only. Wheel bundles UCX and supports CUDA 12 and 13. Tested with UCX 1.23.x. Backends (plugins): UCX, LIBFABRIC, GDS and others if built. llm-d table: UCX covers IB and RoCE; UCCL covers IB, RoCE, TCP-X and EFA; libfabric covers EFA. |
| Mooncake Transfer Engine  | vLLM MooncakeConnector, SGLang default (`mooncake`), TensorRT-LLM (integrated), NIXL plugin | Zero-copy RDMA. Pip packages `mooncake-transfer-engine-cuda13`, `mooncake-transfer-engine` (CUDA 12), and `mooncake-transfer-engine-efa-cuda13` (x86_64 AWS EFA only; do not install beside the standard package).                              |
| MPI / UCX direct          | TensorRT-LLM `cache_transceiver_config.backend`                                             | `DEFAULT`, `UCX`, `NIXL`, `MPI`; default backend is NIXL.                                                                                                                                                                                       |

Network checks: NCCL variables do not configure NIXL/UCX paths. Set `UCX_TLS` and `UCX_NET_DEVICES` instead (vLLM docs); TensorRT-LLM and SGLang have their own variables (see `engine-flags.md`). Mooncake in vLLM needs the `nvidia-peermem` module unless `WITH_NVIDIA_PEERMEM=0` (DMA-BUF).
