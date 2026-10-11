# LoRA, P/D, multi-node and KV cache

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

## LoRA (`ModelAdapter`, `model.aibrix.ai/v1alpha1`)

The base Deployment's pods need labels `model.aibrix.ai/name` and `adapter.model.aibrix.ai/enabled: "true"` (and
the runtime sidecar or a vLLM with dynamic LoRA loading enabled).

```yaml
apiVersion: model.aibrix.ai/v1alpha1
kind: ModelAdapter
metadata:
  {
    name: qwen-code-lora,
    labels:
      { model.aibrix.ai/name: qwen-code-lora, model.aibrix.ai/port: "8000" },
  }
spec:
  baseModel: qwen-coder-1-5b-instruct
  podSelector:
    {
      matchLabels:
        {
          model.aibrix.ai/name: qwen-coder-1-5b-instruct,
          adapter.model.aibrix.ai/enabled: "true",
        },
    }
  artifactURL: huggingface://<org>/<adapter> # or s3:// or an absolute path
  schedulerName: default # or least-adapters
```

`replicas` may be omitted (all matching pods) or 1. Phases: Pending, Scheduled, Loading, Bound, Running; up to 5
retries per pod. Inspect with `kubectl describe modeladapter <name>`. Clients use the adapter name as `model`.
Credentials go in Secrets (samples: `adapter-s3-example.yaml`, `adapter-api-key.yaml`).

## StormService (P/D and multi-node)

`orchestration.aibrix.ai/v1alpha1` `StormService` defines `roles` (for example `prefill` and `decode`), each with
a pod template, replicas and `stateful`; modes: replica (`replicas` N) or pool (`replicas: 1` with role-level
autoscaling). Samples in `samples/disaggregation/vllm`: `1p1d.yaml`, `pool.yaml`, `replica.yaml`, `router.yaml`. They
use AIBrix-enhanced images with NIXL and LMCache and RDMA pod-network annotations from Volcano Engine; adapt the
image and networking to your cluster. Route with `routing-strategy: pd`. Also SGLang and Neuron samples. P/D pays off
only with fast interconnects and long prompts (skill `disaggregated-serving`).

## Ray fleets (multi-node, optional)

`RayClusterFleet` and `RayClusterReplicaSet` (needs KubeRay), samples `samples/distributed/fleet*.yaml`. Prefer
`StormService` unless you already use Ray.

## KV cache offload

AIBrix KV cache offloading is usable standalone (vLLM V0/V1 and SGLang connectors; FlashAttention and XFormers
backends only). L1 (host memory) example: engine started with
`--kv-transfer-config '{"kv_connector":"AIBrixOffloadingConnectorV1Type3","kv_role":"kv_both"}'`, `VLLM_USE_V1=1`,
`AIBRIX_KV_CACHE_OL_L1_CACHE_ENABLED=1`, `AIBRIX_KV_CACHE_OL_L1_CACHE_EVICTION_POLICY` (default S3FIFO) and
`AIBRIX_KV_CACHE_OL_L1_CACHE_CAPACITY_GB` (default 10; keep well below pod memory). L2 uses the `KVCache` CRD and
distributed backends (InfiniStore, Vineyard samples in `samples/kvcache`). Concepts: skill `kv-cache-offloading`.

## Engine images

Stock engines work for plain serving. KV offload and P/D need AIBrix-enhanced images; the documented release is
`aibrix/vllm-openai:v0.10.2-aibrix-v0.5.0-nixl-0.7.1-20251123` (vLLM 0.10.2, CUDA 12.8, NIXL 0.7.1) and the SGLang
equivalent, which is the latest tag on Docker Hub at verification time. Check compatibility before mixing with a
newer vLLM.

## Sources

- <https://aibrix.readthedocs.io/latest/features/lora-dynamic-loading.html>
- <https://aibrix.readthedocs.io/latest/features/pd-disaggregation.html>
- <https://aibrix.readthedocs.io/latest/features/kvcache-offloading.html>
- <https://aibrix.readthedocs.io/latest/getting_started/container-images.html>
