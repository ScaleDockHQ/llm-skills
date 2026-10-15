# Parallelism and multi-node

> Verified against TensorRT-LLM v1.2.1 (`docs/source/features/parallel-strategy.md`, `disagg-serving.md`, serve docs), `main` serve docs, DGX Spark playbook, 2026-10-11

## Strategies

| Strategy                  | Flag / YAML key                                         | Best for                                |
| ------------------------- | ------------------------------------------------------- | --------------------------------------- |
| Tensor parallel (TP)      | `--tp_size`, `tensor_parallel_size`                     | Small batches, memory-bound models      |
| Pipeline parallel (PP)    | `--pp_size`, `pipeline_parallel_size`                   | Models too large for one GPU            |
| Data parallel (attention) | `enable_attention_dp: true` (YAML)                      | Large batches, high throughput          |
| Expert parallel (EP)      | `--ep_size`, `moe_expert_parallel_size`                 | MoE models with many experts            |
| Context parallel (CP)     | `--cp_size`                                             | Long contexts                           |
| Wide-EP                   | `moe_config.backend: WIDEEP`, EPLB, `examples/wide_ep/` | DeepSeek-V3/R1, Llama 4, Qwen3 at scale |

Attention module: TP shards GEMM weights and heads (KV is replicated when `num_heads < tp_size` for GQA/MQA/MLA); attention DP replicates weights and partitions KV per request. MoE FFN: TP slices every expert, EP places whole experts per GPU, hybrid ETP does both. The product `moe_tensor_parallel_size * moe_expert_parallel_size` must equal `tensor_parallel_size`.

```yaml
# parallel_config.yaml (use with --config)
tensor_parallel_size: 8
enable_attention_dp: true # DP attention
moe_expert_parallel_size: 8 # EP only
# hybrid: moe_tensor_parallel_size: 4 and moe_expert_parallel_size: 2
```

Upstream plain-language guidance: use TP for latency, attention DP and EP for throughput on big MoE models; PP only when memory forces it. Always benchmark (`performance-tuning.md`).

## One node, several GPUs

```bash
trtllm-serve nvidia/Llama-3.3-70B-Instruct-FP8 --tp_size 4 --host 0.0.0.0 --port 8000
```

TensorRT-LLM starts one worker per GPU through MPI inside the container; no extra launcher is needed on a single node. Use `--ipc=host`. Select GPUs with `CUDA_VISIBLE_DEVICES` or `docker --gpus '"device=0,1"'`.

## Several nodes

The pattern is one process per GPU across nodes, started by MPI or Slurm, wrapped in `trtllm-llmapi-launch` so that only rank 0 runs the HTTP server and the other ranks serve as workers.

### Slurm + pyxis/enroot (upstream example, DeepSeek-V3 on two 8-GPU nodes)

```bash
echo -e "enable_attention_dp: true\npytorch_backend_config:\n  enable_overlap_scheduler: true" > config.yml
srun -N 2 -w [NODES] --output=benchmark_2node.log --ntasks 16 --ntasks-per-node=8 \
  --mpi=pmix --gres=gpu:8 --container-image=<CONTAINER_IMG> \
  --container-mounts=/workspace:/workspace --container-workdir /workspace \
  bash -c "trtllm-llmapi-launch trtllm-serve deepseek-ai/DeepSeek-V3 --max_batch_size 161 \
    --max_num_tokens 1160 --tp_size 16 --ep_size 4 --kv_cache_free_gpu_memory_fraction 0.95 \
    --config ./config.yml"
```

Note `pytorch_backend_config` is an older key shown in that example; current YAML puts options at the top level (use `disable_overlap_scheduler`, not `enable_overlap_scheduler`). Re-check against `--help` for your tag. The image must have Open MPI with PMIx, and on a pip install MPI must be built `--with-slurm` ("OMPI was not built with SLURM support" otherwise).

### Plain MPI (the DGX Spark pattern)

Two containers, one per node, on `--network host` with `/dev/infiniband`, an OpenMPI hostfile, and the CX7 interface names in `UCX_NET_DEVICES`, `NCCL_SOCKET_IFNAME` and `OMPI_MCA_btl_tcp_if_include` (full command in `install.md`). Then from the primary:

```bash
docker exec -e MODEL="nvidia/Qwen3-235B-A22B-FP4" -e HF_TOKEN="$HF_TOKEN" -it trtllm-multinode bash -c '
  mpirun -x HF_TOKEN trtllm-llmapi-launch trtllm-serve $MODEL \
    --tp_size 2 --max_num_tokens 32768 --max_batch_size 4 \
    --extra_llm_api_options /tmp/extra-llm-api-config.yml --port 8355'
```

Download weights on both nodes first: `mpirun -x HF_TOKEN bash -c "hf download $MODEL"` (the playbook does this so each rank has the files). Requirements per node: the same image tag, SSH keys and the hostfile, the IB device, enough disk for the weights. A missing one hangs `mpirun`.

In a llama-swap stack: keep the two containers persistent (systemd), have the model's start wrapper run the `docker exec ... mpirun ...` on the primary with `--host 127.0.0.1 --port "$PORT"`, and make the stop step end that process explicitly (the container name no longer equals the model id). Validate this before relying on it; the pattern is not an upstream recipe. See `llama-swap` (`npx skills add ScaleDockHQ/llm-skills --skill llama-swap`) and `self-hosted-llms`.

### Kubernetes

Use Dynamo's `DynamoGraphDeployment` (`combos/dynamo.md`) or `trtllm-serve` Deployments for single-node replicas (`templates/k8s-deployment.yaml`). For multi-node pods the MPI hostname issue applies (`PMIX_HOSTNAME`).

## Disaggregated serving with trtllm-serve

Context (prefill) and generation (decode) run on separate servers; an orchestrator routes between them. Limits per upstream: decoder-only models, beam width 1, homogeneous per-layer KV (same dtype and heads).

```bash
# prefill (context) servers
echo -e "disable_overlap_scheduler: True\ncache_transceiver_config:\n  backend: UCX\n  max_tokens_in_buffer: 2048" > context_config.yml
CUDA_VISIBLE_DEVICES=0 trtllm-serve TinyLlama/TinyLlama-1.1B-Chat-v1.0 --host localhost --port 8001 --config ./context_config.yml &> log_ctx_0 &
CUDA_VISIBLE_DEVICES=1 trtllm-serve TinyLlama/TinyLlama-1.1B-Chat-v1.0 --host localhost --port 8002 --config ./context_config.yml &> log_ctx_1 &
# decode (generation) server
echo -e "cache_transceiver_config:\n  backend: UCX\n  max_tokens_in_buffer: 2048" > gen_config.yml
CUDA_VISIBLE_DEVICES=2 trtllm-serve TinyLlama/TinyLlama-1.1B-Chat-v1.0 --host localhost --port 8003 --config ./gen_config.yml &> log_gen_0 &

cat > disagg_config.yaml <<'EOF'
hostname: localhost
port: 8000
context_servers:
  num_instances: 2
  urls: ["localhost:8001", "localhost:8002"]
generation_servers:
  num_instances: 1
  urls: ["localhost:8003"]
EOF
trtllm-serve disaggregated -c disagg_config.yaml
```

The overlap scheduler is disabled on context servers because upstream says it is not supported there yet. The v1.2.1 example also passes `--backend pytorch` and a `backend: pytorch` line in the orchestrator YAML; both are the default and can be left out (re-check for newer tags).

`max_tokens_in_buffer` must be at least the largest prompt length (upstream recommends greater than or equal to the maximum ISL; Dynamo reports KV exhaustion deadlocks when it is smaller). Transfer backends: NIXL and UCX recommended, MPI supported; NIXL's underlying backend is selected with `TRTLLM_NIXL_KVCACHE_BACKEND` (`UCX` default, `LIBFABRIC` plugin not in the container by default).

KV transfer environment variables (upstream list): `TRTLLM_DISABLE_KV_CACHE_TRANSFER_OVERLAP`, `TRTLLM_ENABLE_KVCACHE_RECEIVE_PARALLEL`, `TRTLLM_REQUEST_KV_CACHE_CONCURRENT`, `TRTLLM_TRY_ZCOPY_FOR_KVCACHE_TRANSFER`, `TRTLLM_KVCACHE_TRANSFER_BUFFER_SIZE` (default 512 MB), `TRTLLM_KVCACHE_TRANSFER_USE_ASYNC_BUFFER`, `TRTLLM_KVCACHE_SEND_MAX_CONCURRENCY_NUM` (default 1). Also `UCX_MAX_RNDV_RAILS=1` to reduce NIC contention with TEP, and `UCX_CUDA_IPC_ENABLE_MNNVL=n` when servers sit in different NVLink domains. Warm up before benchmarking: connections are created lazily.

Slurm scripts: `examples/disaggregated/slurm` in the repo. For production use Dynamo.

## Verify

- Rank 0 logs the server start; `curl -s http://127.0.0.1:<port>/health` returns 200.
- `nvidia-smi` on every node shows memory in use; `docker exec trtllm-multinode nvidia-smi` per container.
- First request is slow (graph capture, connection setup); benchmark after a warm-up.

## Official links

- Parallelism: https://nvidia.github.io/TensorRT-LLM/features/parallel-strategy.html
- Disaggregated serving: https://nvidia.github.io/TensorRT-LLM/features/disagg-serving.html
- Multi-node with Slurm: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- DGX Spark playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/trt-llm
