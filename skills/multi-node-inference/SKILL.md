---
name: multi-node-inference
description: Serve one LLM across several machines with tensor, pipeline, data and expert parallelism over NCCL, ConnectX-7, RoCE or InfiniBand (vLLM Ray and mp --nnodes, SGLang --nnodes --dist-init-addr, TensorRT-LLM MPI trtllm-serve, llama.cpp RPC, exo, TensorFold, DGX Spark dual node). Use for "model too big for one node", "--tensor-parallel-size 16", "multi-node vLLM", "NCCL hang", "NET/Socket", "No available node types", "ray status". Not for P/D splits (disaggregated-serving) or single-node tuning.
license: MIT
compatibility: Reads docs and inspects hosts with bash, curl, jq and ssh. Needs two or more Linux (or Apple Silicon for exo) machines on a private network. Installs, network changes, firewall rules and cluster starts need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Multi-Node Inference

Decide whether a model really needs more than one machine, pick the parallelism layout, bring up the cluster with the engine's documented flags, prove the interconnect is doing RDMA, and gate any numerics change. Exact flags, defaults and constraints per engine are in `references/`, read from upstream on 2026-10-11.

**Scope:** this cross-product technique. Installing one engine stays in its product skill (see Companion skills).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect before changing anything. Every command is read-only and prints no secrets. Run on every node (`ssh <node> '<cmd>'` for the others).

```bash
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
nvidia-smi topo -m                                   # GPU and NIC paths
ibv_devinfo -l 2>/dev/null; ibdev2netdev 2>/dev/null # RDMA devices
ip -br addr; ip -br link
free -h; df -h ~/.cache/huggingface 2>/dev/null
command -v vllm sglang trtllm-serve llama-server ray mpirun srun exo 2>/dev/null
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null
ray status 2>/dev/null | head -20
ss -ltn | grep -E ':(6379|8265|5000|50052|52415|30000|8000)\b'   # Ray, SGLang, RPC, exo, API ports
```

Ask only what cannot be discovered: model and context target, how many nodes and GPUs each, what cable or fabric links them, whether downtime is acceptable and who owns the network.

## Decision flow

1. **Does it fit on one node?** If weights plus KV fit, prefer one node plus replicas (data parallel) behind a router; cross-node TP is slower. Use `choosing-hardware` if undecided.
2. **Pick the layout** (vLLM rule of thumb): TP = GPUs per node, PP = number of nodes; for uneven splits or GPUs without NVLink prefer PP. MoE: add EP (`--enable-expert-parallel`, SGLang `--ep-size`, TensorRT-LLM `moe_expert_parallel_size`), often with DP attention. -> `references/engine-matrix.md`
3. **Pick the engine**: vLLM (Ray or mp) and SGLang for GPU clusters, TensorRT-LLM under SLURM/MPI, llama.cpp RPC for GGUF experiments on a trusted network, exo or TensorFold speed-up for Apple Silicon over Thunderbolt 5. `choosing-inference-engine` if undecided.
4. **Verify the fabric first**: RDMA devices, GID, interface names, `nccl-tests` across nodes. -> `references/interconnect-and-dgx-spark.md`
5. **Bring up the cluster** with the flags in the matrix; start workers before the head serves traffic; keep Ray, RPC and discovery ports private.
6. **Numerics?** Changing TP/PP degree changes the reduction order; lossy KV, quantized all-to-all or TensorFold speed-up change outputs. Run the gate below before the cluster serves users.

## Rules

- **Ask before changing the system.** Installs, netplan or firewall edits, cluster starts and stopping other services need approval and an undo path (previous netplan file, previous single-node unit).
- **Secrets never touch output.** API keys, `HF_TOKEN` and SSH material live in `0600` files or environment variables; never echo them.
- **Verify upstream.** Flags and defaults drift. Re-read the docs for the installed version. "(unverified)" items in references are leads only.
- **Private networks only.** vLLM's Ray traffic is unencrypted and exploitable; llama.cpp RPC is documented as insecure; exo discovers peers automatically. Never expose these ports publicly. Set `VLLM_HOST_IP` to a private address.
- **Same everything on every node.** Engine image or version, driver, NCCL, model files at the same path.
- **Gate numerics changes.** Any option that changes numerics (different TP/PP layout, lossy or FP8 KV cache, quantization, quantized all-to-all, TensorFold speed-up) must pass the `llm-evals` gate below. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.

## Techniques per engine

- [ ] **vLLM** (v0.31.0): Ray (`run_cluster.sh --head|--worker`, `VLLM_HOST_IP`, `vllm serve ... --tensor-parallel-size 8 --pipeline-parallel-size 2 --distributed-executor-backend ray`) or mp (`--nnodes 2 --node-rank 0|1 --master-addr <ip>`, `--headless` on workers). DP: `--data-parallel-size`, `--data-parallel-address`, `--data-parallel-rpc-port`; EP: `--enable-expert-parallel`, `--all2all-backend`. -> `references/engine-matrix.md`
- [ ] **SGLang** (v0.5.21): same command per node with `--dist-init-addr <node0>:<port> --nnodes N --node-rank R --tp-size T`; `--enable-dp-attention`, `--moe-a2a-backend`. Deadlock tip: `--disable-cuda-graph`. -> `references/engine-matrix.md`
- [ ] **TensorRT-LLM** (v1.2.1): `srun --mpi=pmix ... trtllm-llmapi-launch trtllm-serve <local model dir> --tp_size 16`; MPI tasks must equal the parallelism product; no HF download in Slurm mode. -> `references/engine-matrix.md`
- [ ] **llama.cpp RPC** (build b11556): `ggml-rpc-server` on workers, `llama-server --rpc host:port,...`; insecure by design; `-ts`, `-sm`. -> `references/engine-matrix.md`
- [ ] **exo / TensorFold** on Apple Silicon: macOS >= 26.2 and TB5 RDMA; TensorFold `--speed-up` duplicates weights per Mac (not memory pooling). -> `references/engine-matrix.md`
- [ ] **Interconnect and DGX Spark dual node**: NCCL variables (`NCCL_SOCKET_IFNAME`, `NCCL_IB_HCA`, `NCCL_IB_GID_INDEX`), `nccl-tests`, NVIDIA playbooks, interface-choice nuance. -> `references/interconnect-and-dgx-spark.md`
- [ ] **Numerics gate** (needed for any numerics-changing option; use the `llm-evals` skill workflow "Quality-gate a numerics change"):
  1. Write the gate first: golden-set metric, threshold (within baseline-vs-baseline noise, zero regressions on critical items), decision owner.
  2. Baseline = the single-node or current production layout; candidate = exactly one change (new TP/PP degree, FP8 KV, speed-up mode, a different all-to-all backend).
  3. Same prompts, sampling, seed, `max_tokens` and chat template through the same gateway to both; include long-context prompts, since cross-node bugs show up at length.
  4. Run the baseline against itself to measure noise; score with promptfoo on the golden set (at least 100 real prompts).
  5. Record pass, fail or pass-with-conditions with links; keep the single-node deployment available for rollback until it passes.
- [ ] **Verify** (done when all are true): every node is listed by the engine (`ray status`, SGLang logs for all ranks, MPI ranks up); engine logs with `NCCL_DEBUG=INFO` show IB/RoCE rather than `NET/Socket`; a long-prompt request completes with a normal answer; tokens/s and TTFT beat the single-node-plus-replicas alternative or the model could not otherwise be served; killing one worker in staging produces a clean failure and a documented restart; the gate decision is recorded.

## Reference index

- `references/engine-matrix.md`: per-engine multi-node commands, flags, defaults, constraints (vLLM, SGLang, TensorRT-LLM, llama.cpp RPC, TensorFold, exo). Load when writing launch commands.
- `references/interconnect-and-dgx-spark.md`: link types, NCCL variables, fabric proof with nccl-tests, DGX Spark dual-node specifics and a failure map. Load before bringing up or debugging a cluster.

## Companion skills

- `llm-evals`: quality-gates numerics-changing options. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `self-hosted-llms`: serving stack, memory safety and benchmarks on owned GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `nvidia-dgx-spark`: Spark setup and networking. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `disaggregated-serving`: prefill/decode splits and transport flags. Install: `npx skills add ScaleDockHQ/llm-skills --skill disaggregated-serving`.
- `prefix-aware-routing`: routing across replicas. Install: `npx skills add ScaleDockHQ/llm-skills --skill prefix-aware-routing`.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `tensorfold`: engine skills. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `moe-serving`, `choosing-hardware`, `choosing-inference-engine`: sibling techniques, by name.
- Planned product skills, by name: `exo`, `ray-serve`, `kserve`, `dynamo`.
