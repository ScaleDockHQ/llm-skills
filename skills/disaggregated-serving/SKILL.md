---
name: disaggregated-serving
description: Split LLM inference into prefill and decode pools with KV transfer (vLLM NixlConnector/MooncakeConnector, SGLang --disaggregation-mode, TensorRT-LLM cache_transceiver_config, Dynamo, llm-d, NIXL, Mooncake), and decide when it helps or hurts. Use for "prefill decode disaggregation", "P/D split", "kv_producer", "kv_consumer", "--disaggregation-transfer-backend", "kv-transfer-config", xPyD, TTFT vs ITL tuning, "NIXL handshake failed" or "Failed to register memory". Not for routing alone (prefix-aware-routing) or single-engine setup (engine skills).
license: MIT
compatibility: Reads docs and inspects hosts with bash, curl and jq. Multi-GPU Linux hosts with NVIDIA GPUs (RDMA NICs for production), or Kubernetes for llm-d. Installs, service changes and anything touching production traffic need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Disaggregated Serving

Run prefill (prompt processing) and decode (token generation) on separate GPU pools, move the KV cache between them, and prove that the split improves your latency SLOs without changing answers. Per-engine flags, defaults and constraints are in `references/`; they were read from upstream on 2026-10-11 and must be re-checked for newer releases.

**Scope:** this cross-product technique. Installing and tuning one engine stays in its product skill (see Companion skills).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect before changing anything. Every command is read-only and prints no secrets.

```bash
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader
nvidia-smi topo -m                          # NVLink vs PCIe vs NIC paths between GPUs
ibv_devinfo -l 2>/dev/null; ibdev2netdev 2>/dev/null   # RDMA devices (IB / RoCE)
ip -br addr; ip -br link
command -v vllm sglang trtllm-serve python3 && python3 -m pip list 2>/dev/null | grep -Ei '^(vllm|sglang|tensorrt.llm|nixl|mooncake|ai-dynamo)'
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null
kubectl get inferencepools -A 2>/dev/null   # llm-d / Gateway API Inference Extension
ss -ltn | grep -E ':(5600|5601|8998|8100|8200|30000|30001|8000)\b'   # ports these stacks use
curl -s http://127.0.0.1:8000/v1/models | jq '.data[].id'   # what the current endpoint serves
```

Ask the user only what cannot be discovered: latency targets (TTFT, ITL), typical prompt and output lengths, expected concurrency, whether downtime or a canary is allowed, and whether an RDMA fabric is available between the pools.

## Decision flow

1. **Is a split justified?** Read `references/when-it-helps-and-gates.md`. If you have one GPU, short prompts, low concurrency, or no fast fabric, stop: stay aggregated and use chunked prefill. vLLM's own docs say disaggregated prefill does not improve throughput; it tunes TTFT and ITL separately.
2. **Which stack?**
   - Kubernetes with Gateway API: llm-d (vLLM or SGLang pods, EPP plus decode sidecar).
   - One or a few servers, vLLM: Dynamo (`dynamo.vllm`), or two `vllm serve` instances with a proxy.
   - One or a few servers, SGLang: `sglang_router.launch_router --pd-disaggregation`, or Dynamo.
   - One or a few servers, TensorRT-LLM: `trtllm-serve disaggregated` or Dynamo.
   - Other engines (llama.cpp, Ollama, ExLlamaV3, TensorFold): not verified for P/D; do not offer it.
3. **Which transport?** NIXL (UCX; LIBFABRIC for EFA) is the common default. Mooncake is the SGLang default and a vLLM option. Both need RDMA for production. Details: `references/orchestrators.md`.
4. **Engine flags** from `references/engine-flags.md`, with P and D on the same engine version, same model, same KV dtype.
5. **Numerics?** If you change KV dtype, use heterogeneous TP, use `recompute`, or add any lossy option, run the gate in `references/when-it-helps-and-gates.md` before it serves users.

## Rules

- **Ask before changing the system.** Installs, port changes, service restarts and routing production traffic need approval and an undo path (the aggregated deployment stays up until the gate passes).
- **Secrets never touch output.** Keys and tokens live in `0600` files or environment variables. Never echo `HF_TOKEN` or API keys in launch commands you print.
- **Verify upstream.** Flags and defaults drift. Re-read the engine docs for the installed version before using a flag from a reference. Anything marked "(unverified)" is a lead, not a fact.
- **Do not expose side channels.** NIXL side-channel ports, Mooncake bootstrap ports, SGLang bootstrap ports, Ray and ZMQ KV-event ports are unauthenticated internal interfaces: bind to a private network only.
- **Gate numerics changes.** Any option that changes numerics (lossy or lower-precision KV, heterogeneous TP, recompute-on-failure, quantization) must pass the `llm-evals` gate. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- **One change at a time.** P/D split first, then one numerics option per gate run.

## Techniques per engine

Flag names below are the ones upstream documents for the versions in the references.

- [ ] **vLLM** (v0.31.0): two `vllm serve` instances with `--kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_producer"}'` (prefill) and `"kv_role":"kv_consumer"` (decode). Unique `VLLM_NIXL_SIDE_CHANNEL_PORT` per worker (default 5600), `VLLM_NIXL_SIDE_CHANNEL_HOST` when hosts differ, `UCX_TLS` / `UCX_NET_DEVICES` for the fabric. `kv_both` is deprecated for NixlConnector. `kv_load_failure_policy` defaults to `fail`; `recompute` hurts production. MooncakeConnector needs the same TP on both sides. -> `references/engine-flags.md`
- [ ] **SGLang** (v0.5.21): `--disaggregation-mode prefill|decode`, `--disaggregation-transfer-backend mooncake|nixl|...` (default `mooncake`), `--disaggregation-bootstrap-port` (8998), `--disaggregation-ib-device`, then `python -m sglang_router.launch_router --pd-disaggregation --prefill URL [bootstrap] --decode URL`. PD does not support stateful Responses features. -> `references/engine-flags.md`
- [ ] **TensorRT-LLM** (v1.2.1): `cache_transceiver_config: {backend: DEFAULT|UCX|NIXL|MPI, max_tokens_in_buffer: N}` on both servers, `disable_overlap_scheduler: true` on context servers, `trtllm-serve disaggregated -c disagg_config.yaml`. Decoder-only models, beam width 1. -> `references/engine-flags.md`
- [ ] **Dynamo / llm-d / production-stack / AIBrix / SGLang gateway**: orchestration, discovery, routing and operational behaviour (leases, scale-down, rollouts). -> `references/orchestrators.md`
- [ ] **Validate**: baseline vs candidate at three concurrencies, P:D ratio sweep, failure drills, then the numerics gate. -> `references/when-it-helps-and-gates.md`
- [ ] **Verify** (done when all are true): both pools show `Running`/healthy; a request through the front end returns a normal completion; engine logs show the KV transfer backend you configured (not a fallback); `curl -s http://<prefill>/metrics | head` and the decode metrics show activity on both sides; TTFT/ITL and goodput beat the aggregated baseline at expected load; the gate decision is written down; killing one decode and one prefill worker in staging recovers without stuck memory.

## Reference index

- `references/engine-flags.md`: exact flags, env vars, defaults and constraints for vLLM connectors (NIXL, Mooncake), SGLang `--disaggregation-*`, TensorRT-LLM `cache_transceiver_config`. Load when writing launch commands.
- `references/orchestrators.md`: Dynamo, llm-d (EPP config, sidecar, operations), vLLM production-stack, AIBrix, SGLang gateway, and the NIXL/Mooncake transports. Load when choosing or operating the stack.
- `references/when-it-helps-and-gates.md`: when a split helps or hurts, the validation procedure, which options change numerics and the concrete `llm-evals` gate. Load before recommending a split and before shipping.

## Companion skills

- `llm-evals`: quality-gates numerics-changing options. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `self-hosted-llms`: benchmarks and serving stack on owned GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `vllm`: engine install and tuning. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: engine install and tuning. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `tensorrt-llm`: engine install and tuning. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `prefix-aware-routing`: KV/prefix-aware request routing across replicas. Install: `npx skills add ScaleDockHQ/llm-skills --skill prefix-aware-routing`.
- `multi-node-inference`: TP/PP/DP/EP across nodes and the interconnect. Install: `npx skills add ScaleDockHQ/llm-skills --skill multi-node-inference`.
- `kv-cache-offloading`: tiered KV storage. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-offloading`.
- `choosing-inference-engine`, `choosing-hardware`: pick engine and GPUs first. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- Planned product skills, by name: `dynamo`, `llm-d`, `aibrix`.
