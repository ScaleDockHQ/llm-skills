# Triton instances, multi-GPU and scaling

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Sources: model configuration, architecture, rate limiter, ensemble and BLS docs, vllm_backend README.

## Instance groups (concurrency inside one server)

```protobuf
instance_group [
  { count: 2 kind: KIND_GPU gpus: [ 0 ] },
  { count: 1 kind: KIND_GPU gpus: [ 1 ] }
]
```

- `KIND_GPU` creates `count` instances on each listed GPU (default: every visible GPU); `KIND_CPU` for CPU instances;
  `KIND_MODEL` leaves device placement to the backend (used by multi-GPU vLLM models).
- More instances run requests of one model concurrently on the same GPU: it helps when a single instance leaves the
  GPU idle (small models, CPU pre/post-processing) and costs memory. Measure with `perf_analyzer`.
- `host_policy` and `--host-policy` bind instances to NUMA nodes.
- Ensembles have no instance group; each step model has its own.

## Rate limiter

`--rate-limit` mode with per-instance `rate_limiter { resources [...] priority }` limits how many instances execute at once
across models that compete for GPU resources; see the rate limiter guide before enabling.

## Multi-GPU, multi-model on one node

Run several models in one server (one repository, many model directories). Triton schedules concurrent model
execution on the same GPU. For hard isolation start one server per GPU with `--gpus device=<n>` and different ports,
and put a load balancer in front.

## Ensembles and BLS

- **Ensemble** (`platform: "ensemble"`, `ensemble_scheduling`): fixed DAG of models; each step's tensors are mapped by name.
- **BLS**: a Python-backend model calls other models programmatically (loops, conditionals). Decoupled models and
  BLS together are the usual pattern for LLM pre/post-processing pipelines.

## LLM parallelism

- vLLM backend: `tensor_parallel_size` and friends in `model.json`; `KIND_MODEL` instance group; with TP > 1 set
  `"distributed_executor_backend":"ray"` (release-notes known issue); `GPU_DEVICE_IDS` pins GPUs.
- TensorRT-LLM LLM API backend: `tensor_parallel_size`, `moe_expert_parallel_size` in `model.yaml`; the launch script runs
  one process per rank (`launch_triton_server.py` from the TensorRT-LLM repository).
- Multi-node LLM serving is not a Triton feature: use the engine's own multi-node mode or `nvidia-dynamo`.

## Scaling out

Triton servers are stateless apart from loaded models: scale replicas behind a Kubernetes Service or load balancer. gRPC
uses long-lived HTTP/2 connections, so use a gRPC-aware balancer (or client-side balancing) to spread load. Sequence
(stateful) models need requests of one sequence to reach the same replica. Autoscale on queue time or pending
requests from `/metrics` (`nv_inference_pending_request_count`, queue duration) through Prometheus and HPA/KEDA. Keep
model repositories identical across replicas (shared PVC, object storage, or baked into the image).
