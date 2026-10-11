# Parallelism, NUMA and expert placement

> Verified against KTransformers v0.7.1 (kt-kernel README, `experts-sched-Tutorial.md`, `Native-Precision-Tutorial.md`, `DeepSeek-V4-Flash.md`), 2026-10-11

KT has three separate axes: GPU tensor parallelism (SGLang), CPU thread and NUMA layout (kt-kernel), and which experts sit on GPU.

## GPU tensor parallelism

`--tensor-parallel-size N` (`kt run --tp N`) shards the GPU part across N GPUs; `--kt-num-gpu-experts` then counts experts per MoE layer for
the whole deployment. Examples upstream: 1 GPU with 24 GB (Qwen3-30B-A3B, Qwen3-Coder-Next), 4x RTX 4090 (Qwen3.5), 1/2/4/8x 48 GB cards (Kimi K2
Thinking). In the DeepSeek-V4-Flash Docker image, `CUDA_VISIBLE_DEVICES` plus `TP` select GPUs and degree (TP must not exceed visible GPUs).
`--enable-p2p-check` appears in upstream multi-GPU recipes. On hosts with several NICs set `NCCL_SOCKET_IFNAME`.

## CPU threads and NUMA

```bash
lscpu | grep -E "^CPU\(s\)|Thread\(s\) per core|Socket\(s\)|NUMA node\(s\)"
numactl --hardware | grep available
# physical cores = CPU(s) / Thread(s) per core      -> --kt-cpuinfer
# NUMA nodes (from lscpu, not the socket count)     -> --kt-threadpool-count
```

- `--kt-cpuinfer`: physical cores, never the hyperthread count (upstream: hyperthreads degrade performance). Leave a few cores for the OS and the HTTP
  server if the box is shared.
- `--kt-threadpool-count`: the NUMA node count; one pool per node spreads memory bandwidth. NUMA nodes are memory domains, a single CPU can expose several.
- `--kt-numa-nodes 0 1`: explicit ids per pool when you want to skip nodes (length must equal the pool count).
- A model whose CPU experts straddle nodes loses bandwidth: check that each node has enough free memory (`numactl --hardware`).

## Expert placement on GPU

- `--kt-num-gpu-experts N` (per layer) or `--kt-gpu-experts-ratio R` (fraction of all experts; overrides the count). More GPU experts means lower latency and more VRAM.
- `--kt-expert-placement-strategy`: `uniform` (equal per layer), `frequency` (top experts by activation count; needs `--init-expert-location file.pt`),
  `front-loading` (fill from the first MoE layer), `random` (fixed seed 42). The README documents `uniform` as default while the fork's help text says
  `frequency`: set the strategy explicitly.
- `--kt-enable-dynamic-expert-update`: during layerwise prefill, record routing statistics and re-place GPU experts. Needs `--kt-gpu-prefill-token-threshold`, and
  prefill length must reach the threshold. Upstream finds it most effective at 10% to 70% GPU expert ratios.

## Multi-node

Upstream documents no multi-node KT deployment (the Docker packaging mentions SGLang's DeepEP and gdrcopy, but there is no KT cluster guide in 0.7.1). Treat
multi-node as unsupported until you find a tutorial. For multi-node GPU serving of models that fit in VRAM use `vllm` or `sglang` (skill `multi-node-inference`).
