# Xinference replicas, clusters and distributed serving

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

## Replicas on one machine

`--replica N` loads N identical instances and load-balances requests under one model UID. `--n-gpu` sets GPUs
per replica. With `XINFERENCE_ALLOW_MULTI_REPLICA_PER_GPU=1` (default) replicas can share a GPU (for example
three replicas on one GPU with enough VRAM) and replica counts need not match GPU counts (3 replicas on 2 GPUs
puts two on GPU0 and one on GPU1). Placement policy is idle first (`XINFERENCE_LAUNCH_STRATEGY`).

Pin replicas with `--replica-config` (JSON array, one entry per replica, mutually exclusive with
`--worker-ip`, `--gpu-idx`, non-auto `--n-gpu` and `--n-worker > 1`):

```bash
xinference launch -e http://SUP:9997 --model-name qwen2.5-instruct --model-engine vLLM --replica 2 \
  --replica-config '[{"replica_uid":"a","devices":[{"worker_ip":"10.0.0.10:9978","n_gpu":1,"gpu_idx":[0]}]},{"replica_uid":"b","devices":[{"worker_ip":"10.0.0.11:9978","n_gpu":1,"gpu_idx":[0]}]}]'
```

Worker addresses must be the full registered `IP:port` (see `client.get_workers_info()`). Scale a running
model with `client.add_model_replica(uid, replica=2, ...)` and `terminate_model_replica(uid, replica_id=...)`
(not for Xavier models or `n_worker > 1`; deleting the last replica terminates the model). Concurrent launches
per worker are capped by `XINFERENCE_MAX_CONCURRENT_LAUNCHES` (5).

## Cluster: supervisor and workers

```bash
xinference-supervisor -H SUPERVISOR_IP                                   # UI at http://SUPERVISOR_IP:9997/ui
xinference-worker -e http://SUPERVISOR_IP:9997 -H WORKER_IP              # on each worker
xinference launch -e http://SUPERVISOR_IP:9997 ...                       # clients always target the supervisor
```

- Same Xinference version and engine environment everywhere. Workers need access to model files (own cache or
  a shared path) and to package indexes.
- With auth on, every process running the RESTful API must share `XINFERENCE_HOME` or the same
  `XINFERENCE_AUTH_*` variables.
- The docs do not describe authentication for supervisor to worker traffic: keep it on an isolated private network. Local `service`
  commands manage single-machine mode only.
- Helm deploys one supervisor with workers (`install.md`).

## Model across workers (too big for one node)

`--n-worker M --n-gpu G` (G is GPUs per worker). Engines: SGLang, vLLM (v1.4.1+), MLX (limited models:
DeepSeek V3 and R1, Qwen2.5-instruct, Qwen3 and Qwen3-MoE architectures). For vLLM V1 (0.11.1+) TP and PP run
through Xinference's xoscar executor, no Ray: defaults `tensor_parallel_size` = GPUs per worker and
`pipeline_parallel_size` = worker count (two workers of four GPUs gives TP 4, PP 2); explicit values need TP x PP
= total GPUs, equal GPU counts per worker, and a model architecture that supports PP. Xavier and native NIXL
P/D need TP=1 and PP=1.

## Xavier: share prefix KV cache across replicas

`enable_xavier=True` at launch (kwarg or Web UI). vLLM: V1 connector needs vLLM >= 0.21.0 (V0 adapter for

> = 0.7.0 and < 0.11.0); NVIDIA GPU transfer path; start with a real address (`xinference-local -H 192.168.x.y`),
> not `0.0.0.0`. SGLang >= 0.5.21 (v4.0): HiCache storage backend for unquantized FP16 Qwen2, Qwen3 and Llama text
> models, TP=PP=DP=1. MLX (v4.0): Apple Silicon, mlx-lm >= 0.31.2, same model limits, FP16 weights and KV.
> `xavier_cache_bytes` (default 512 MiB) bounds the shared CPU cache.

## Prefill/decode (P/D) separation (community edition)

Prefill replicas compute KV, decode replicas reuse it (Xavier or native NIXL), round-robin within each role.
Launch with roles in `replica_config`:

```python
client.launch_model(model_uid="qwen-pd", model_name="qwen2.5-instruct", model_size_in_billions="0_5",
  model_format="pytorch", quantization="none", model_engine="vLLM", replica=2,
  replica_config=[
    {"role": "prefill", "devices": [{"worker_ip": "10.0.0.10:9997", "n_gpu": 1, "gpu_idx": [0]}]},
    {"role": "decode",  "devices": [{"worker_ip": "10.0.0.10:9997", "n_gpu": 1, "gpu_idx": [1]}]}])
```

v4.0 supports vLLM, SGLang and MLX roles and cross-engine pairs (vLLM and SGLang) and NVIDIA to Apple Silicon.
GPU P/D needs Linux, NVIDIA, vLLM >= 0.21.0 and `xoscar[nixl]>=0.11.1` in both worker and model
environments; a missing NIXL fails the launch (no CPU fallback). SGLang P/D needs
`disaggregation_decode_enable_radix_cache=false`; handoff wait is `XINFERENCE_SGLANG_XAVIER_TRANSFER_TIMEOUT`
(600 s). Relaunch after a worker restart. Measure TTFT and throughput against plain replicas first: P/D only
pays off for long prompts at scale (`disaggregated-serving` skill).

## Reload engine settings without reloading weights (v4.0)

Opt in at launch: `enable_weight_cache=true` (Web UI: Keep GPU weights for reload). Needs vLLM 0.31.0+ or SGLang
0.5.21+, Linux with CUDA or ROCm, one worker, one replica, fixed tensor parallelism; not with PP/DP, LoRA,
speculative decoding, weight offload or P/D.

```bash
xinference reload --model-uid UID --model-config '{"max_num_seqs": 32}'     # 202 with an operation_id
curl -s http://127.0.0.1:9997/v1/models/UID/reload                         # poll status
```

vLLM can change `max_num_seqs`, `max_num_batched_tokens`, `max_model_len`, `gpu_memory_utilization`,
`enforce_eager`; SGLang `max_running_requests`, `max_prefill_tokens`, `context_length`, `chunked_prefill_size`,
`mem_fraction_static`, `disable_cuda_graph` and others. Reload drains in-flight requests (`drain_timeout`
default 300 s, max 3600) and returns 503 for new ones meanwhile.
