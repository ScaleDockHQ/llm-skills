# Multi-GPU, CPU offload and cache tiers

> Verified against ExLlamaV3 v1.6.1 and TabbyAPI main (config_sample.yml, docs), 2026-10-11

## Single node only

ExLlamaV3 describes "flexible tensor-parallel and expert-parallel inference for consumer hardware setups" inside one machine. No multi-node or pipeline-across-hosts mode is documented upstream. To spread a model over several machines use `vllm`, `sglang` or `multi-node-inference` (planned); to serve more throughput run one TabbyAPI per node behind `llm-gateway` / `litellm`.

## Layer split (default)

With several GPUs and `tensor_parallel: false`, `gpu_split_auto: true` fills GPUs in order, reserving `autosplit_reserve` MB (default `[96]`, array per GPU; a negative value excludes that GPU). Manual split: `gpu_split_auto: false` and `gpu_split: [20, 25]` (GB per GPU), also usable with tensor parallel. Draft models have `draft_gpu_split` and autosplit when it is empty. Choose visible GPUs with `CUDA_VISIBLE_DEVICES` or the container's `--gpus`.

## Tensor parallel

```yaml
model:
  tensor_parallel: true
  tensor_parallel_backend: native # PCIe GPUs; use nccl for NVLink
```

- `gpu_split_auto` is ignored when tensor parallel is on; give `gpu_split` for uneven cards (falls back to autosplit if absent).
- Backend: `native` recommended for PCIe, `nccl` for NVLink.
- Tensor parallel and NCCL use POSIX shared memory: containers need `--shm-size=8g` or `--ipc=host`, or loading fails naming the limit.
- Some fast paths fall back under TP (for example the graph-captured decode attention declines TP configs, per `doc/env_vars.md`); measure TP versus layer split on your cards, since TP is not always faster on slow interconnects.
- A shared MoE expert is placed whole on one rank under TP (`EXL3_MOE_SHARED_COOP`, default 1).
- CPU MoE offload is not supported with tensor parallel.

## Expert parallel and CPU MoE offload

Mixture-of-expert models can keep experts in system RAM:

```yaml
model:
  cpu_moe_offload_layers: 999 # whole MoE layers on CPU (layer-split mode only)
  # or
  cpu_moe_split_experts: 8 # coldest N routed experts per layer on CPU, hot ones stay in VRAM
  cpu_moe_threads: 16 # else EXL3_MOE_CPU_THREADS, else half the cores
```

The two options are mutually exclusive. AVX2 and AVX512 paths exist. CPU expert offload (and int8 GEMV) needs the default `mul1` codebook from conversion. Handoff buffers use `/dev/shm` (see above). Expect much lower decode speed than all-VRAM; use it to fit a big MoE, then tune `cpu_moe_threads`.

## Host-memory and disk cache tiers

`memory.sysmem_kv_cache` (MB, default 0) adds a second-tier K/V page cache in system RAM: pages evicted from GPU are restored on prompt-cache hits instead of recomputed. `memory.disk_cache_dir` adds an experimental third tier on disk (needs ExLlamaV3 1.6.2 or later and `sysmem_kv_cache` > 0; budget `disk_cache_size` 51200 MB; survives restarts). `sysmem_recurrent_cache` (4096 MB) bounds recurrent-state checkpoints for hybrid/linear-attention models (Qwen3-Next, Qwen3.5, Kimi Linear).

## Embedding tables

`embed_stream_from_disk` streams token embeddings from disk for large-vocabulary models; `ngram_ram` keeps PLE n-gram tables in RAM (tens of GB) instead of streaming.

## Mixed GPUs

A Triton workaround for mixed-architecture setups landed in v1.6.1 (autotune issue). Prefer same-architecture GPUs for tensor parallel; set `gpu_split` proportionally to VRAM for layer split.

## Checks

```bash
nvidia-smi --query-gpu=index,memory.used --format=csv   # confirm both GPUs hold weights
curl -s http://127.0.0.1:5000/health
```
