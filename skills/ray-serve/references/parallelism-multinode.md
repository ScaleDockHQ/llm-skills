# Parallelism and multi-node

> Verified against Ray 2.59.0 (docs `serve/llm/user-guides/cross-node-parallelism`, `data-parallel-attention`), 2026-10-11

## Tensor and pipeline parallel

```yaml
engine_kwargs:
  tensor_parallel_size: 4 # shard each replica over 4 GPUs
  pipeline_parallel_size: 2 # stages; spans nodes. GPUs per replica = TP x PP = 8
```

- Default placement strategy is `PACK`: as few nodes as possible, spilling to others when needed.
  So cross-node deployment happens automatically when one node is too small.
- Which rank lands on which GPU is vLLM's decision, not configurable through Ray Serve LLM.
- Serve injects accelerator-type labels into bundles and merges the first bundle with the replica actor's resources.
- TP inside a node (NVLink) first; PP across nodes. For the networking side (NCCL, ConnectX, RoCE) use skill
  `multi-node-inference`.

## Placement groups

```yaml
placement_group_config:
  bundle_per_worker: { CPU: 1, GPU: 1 } # replicated TP*PP times; mutually exclusive with bundles
  strategy: SPREAD # spread across nodes for fault tolerance
# or explicit:
# bundles: [{CPU: 1, GPU: 1}, {CPU: 1, GPU: 1}, {CPU: 1, GPU: 1}, {CPU: 1, GPU: 1}]
# strategy: STRICT_PACK
```

Omitted `CPU` or `GPU` keys count as 0; set both explicitly when workers need both.

## Data-parallel attention (MoE)

Entry point `build_dp_openai_app`. Use for sparse MoE models with MLA where attention can't shard over KV heads;
not for dense models or when TP is enough (GQA: TP up to the KV head count first).

```yaml
applications:
  - name: dp_llm_app
    route_prefix: /
    import_path: ray.serve.llm:build_dp_openai_app
    args:
      llm_config:
        model_loading_config: { model_id: Qwen/Qwen2.5-0.5B-Instruct }
        deployment_config: { num_replicas: 2 } # number of DP groups
        engine_kwargs: { data_parallel_size: 4, tensor_parallel_size: 2 }
```

GPUs = `num_replicas * data_parallel_size * tensor_parallel_size`. Placement is forced to `STRICT_PACK`; replicas in
a group are gang-scheduled. `num_replicas: "auto"` autoscales on queue length.

## Kubernetes sizing

Worker pod `nvidia.com/gpu` limit must be at least the GPUs one replica needs on that pod. The KubeRay sample
puts 4 GPUs in one worker (`rayStartParams: num-gpus: "4"`). Multi-host TP needs several worker pods whose
GPU total covers TP x PP, with fast pod networking.

## Sources

https://docs.ray.io/en/latest/serve/llm/user-guides/cross-node-parallelism.html, https://docs.ray.io/en/latest/serve/llm/user-guides/data-parallel-attention.html
