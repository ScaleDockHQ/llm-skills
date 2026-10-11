---
name: prefix-aware-routing
description: Route LLM requests to the replica that already holds the matching KV prefix (llm-d inference scheduler, Gateway API Inference Extension, vLLM production-stack router, SGLang Model Gateway cache_aware, Dynamo --router-mode kv, AIBrix prefix-cache). Use for "prefix cache aware routing", "KV-aware routing", low prefix cache hit rate across replicas, "--routing-logic prefixaware", "--kv-events-config", EndpointPickerConfig, InferencePool, block-size mismatch. Not for single-replica caching or P/D splits (disaggregated-serving).
license: MIT
compatibility: Reads docs and inspects hosts or clusters with bash, curl, jq and optionally kubectl. Needs 2+ replicas of the same model on Linux or Kubernetes. Installs, router changes and production traffic shifts need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Prefix-Aware Routing

Choose and configure a router that sends requests with shared prompt prefixes to the replica that already cached them, then prove the hit rate and TTFT improve without overloading one replica. Exact flags, defaults and plugin parameters are in `references/`, read from upstream on 2026-10-11.

**Scope:** this cross-product technique. Installing one engine or one router stays in its product skill (see Companion skills).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect before changing anything. Every command is read-only and prints no secrets.

```bash
kubectl get inferencepools,gateways,httproutes -A 2>/dev/null          # Gateway API Inference Extension in use?
kubectl get pods -A -l 'llm-d.ai/role' -o wide 2>/dev/null              # llm-d role labels
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null
ps aux | grep -E 'sglang_router|sgl-model-gateway|dynamo.frontend|vllm_router|vllm serve|sglang.launch_server' | grep -v grep | cut -c1-200
ss -ltn | grep -E ':(5557|5556|5559|8000|9002|30000)\b'                  # KV event, EPP, frontend, gateway ports
curl -s http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -s http://127.0.0.1:8000/metrics | grep -iE 'prefix|cache' | head -20   # engine cache counters
```

Ask only what cannot be discovered: replica count, whether prompts share long prefixes (system prompt, tools, RAG documents, multi-turn), whether sessions are tenant-isolated, and whether Kubernetes is available.

## Decision flow

1. **Is routing worth it?** With one replica, or prompts without long shared prefixes, stop: use the engine's own prefix cache (vLLM `--enable-prefix-caching` is on by default in v0.31.0; SGLang radix cache is on unless `--disable-radix-cache`).
2. **Pick the router** by platform (table in `references/router-matrix.md`):
   - Kubernetes + Gateway API: llm-d inference scheduler (EPP) on a GAIE `InferencePool`.
   - Kubernetes, vLLM only: production-stack router (`--routing-logic prefixaware` or `kvaware`).
   - SGLang fleet: SGLang Model Gateway `--policy cache_aware` (default).
   - NVIDIA Dynamo fleet: `dynamo.frontend --router-mode kv`.
   - Envoy gateway users: AIBrix `routing-strategy: prefix-cache`.
3. **Approximate or precise?** Approximate needs no engine changes, drifts on eviction. Precise needs KV events (`--kv-events-config`), matching block size and hash algorithm, and one EPP replica in llm-d. Start approximate, move to precise when hit rate matters and you can run the event plumbing.
4. **Align the engine**: same block size on engine and router, stable prompt prefixes, events on and private. -> `references/engine-side.md`
5. **Numerics?** Routing itself does not change the math. Gate related lossy changes (lower-precision KV for a bigger cache, engine upgrades, non-exact KV reuse) with `llm-evals`: see `references/engine-side.md`.

## Rules

- **Ask before changing the system.** Router swaps, gateway changes and traffic shifts need approval and an undo path (keep the previous routing config).
- **Secrets never touch output.** Keys live in `0600` files or environment variables; do not print `--api-key`, `VLLM_API_KEY` or gateway tokens.
- **Verify upstream.** Router plugin and flag names change between releases. Re-read the version you deploy. Items marked "unverified" in references are leads only.
- **Private event ports.** KV-event ZMQ sockets, EPP ports and metrics are unauthenticated: bind to private networks only. AIBrix `x-session-id` is a routing hint, not auth.
- **Match block sizes.** Router block size must equal the engine block or page size, or hit prediction is wrong.
- **Gate numerics changes.** Any option that changes numerics (FP8 KV, non-exact KV reuse, engine/backend change) must pass the `llm-evals` gate. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- **Watch skew.** Higher hit rate with one hot replica is a regression.

## Techniques per router

- [ ] **llm-d / GAIE**: `InferencePool` (`inference.networking.k8s.io/v1`) with `endpointPickerRef` (`port` 9002, `failureMode: FailOpen`); `EndpointPickerConfig` with `approx-prefix-cache-producer` + `prefix-cache-scorer` (approximate) or `precise-prefix-cache-producer` + `token-producer` (precise). Engine: `--block-size=64`, `--kv-events-config`. -> `references/router-matrix.md`
- [ ] **vLLM production-stack**: `--routing-logic prefixaware` (HashTrie, assumes no eviction) or `kvaware` (LMCache controller, port 9000), `--service-discovery k8s|static`. -> `references/router-matrix.md`
- [ ] **SGLang Model Gateway**: `python -m sglang_router.launch_router --policy cache_aware --cache-threshold 0.3 --balance-abs-threshold 64 --balance-rel-threshold 1.5`; engines `--page-size`, `--enable-cache-report`. -> `references/router-matrix.md`
- [ ] **Dynamo**: `python -m dynamo.frontend --router-mode kv` (events on by default, `--router-kv-events`); vLLM workers need `PYTHONHASHSEED=0`. -> `references/router-matrix.md`
- [ ] **AIBrix**: header `routing-strategy: prefix-cache` or `ROUTING_ALGORITHM`; precise mode needs a ZMQ-enabled gateway build and pod label `model.aibrix.ai/kv-events-enabled`. -> `references/router-matrix.md`
- [ ] **Validate**: baseline vs candidate on shared-prefix traffic, hit rate and TTFT per replica, skew, failure drills. -> `references/engine-side.md`
- [ ] **Verify** (done when all are true): a repeated long prompt lands on the same replica and the engine reports a cache hit (`usage.prompt_tokens_details` with `--enable-cache-report`, or engine metrics); repeat TTFT is lower than baseline; no replica is saturated while others idle; killing the router recovers to a known behaviour you tested; gate decision recorded for any numerics-changing option.

## Reference index

- `references/router-matrix.md`: flags, plugin parameters, defaults and constraints for llm-d/GAIE, Dynamo, production-stack, SGLang Model Gateway and AIBrix. Load when configuring a router.
- `references/engine-side.md`: vLLM and SGLang engine flags that routers depend on, how to raise real hit rate, validation, security and the numerics gate. Load when aligning engines or before shipping.

## Companion skills

- `llm-evals`: quality gates for numerics-changing options. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `disaggregated-serving`: prefill/decode splits that combine with prefix routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill disaggregated-serving`.
- `llm-gateway`: client-facing gateway in front of the pool. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `self-hosted-llms`: benchmarks and stack on owned GPUs. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `vllm`, `sglang`, `tensorrt-llm`: engine skills. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `kv-cache-offloading`, `kv-cache-quantization`, `reasoning-models`, `multi-node-inference`: sibling techniques, by name.
- Planned product skills, by name: `dynamo`, `llm-d`, `aibrix`, `kserve`.
