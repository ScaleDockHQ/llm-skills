---
name: kv-cache-offloading
description: Extend LLM KV cache capacity by offloading to CPU RAM, disk, object storage or peer instances (vLLM OffloadingConnector, LMCache, SGLang HiCache, TensorRT-LLM host_cache_size, llama.cpp -cram, TabbyAPI), with exact per-engine flags. Use for "--kv-offloading-size", "--enable-hierarchical-cache", "host_cache_size", "-nkvo", low prefix cache hit rate, evicted prefixes, slow time to first token on long repeated prompts, or sharing KV across instances.
license: MIT
compatibility: Linux host with NVIDIA, AMD or Intel GPUs for vLLM, SGLang and TensorRT-LLM; also llama.cpp and TabbyAPI. Read-only discovery uses nvidia-smi, free, df, curl and jq. Restarting an engine, changing flags and writing cache to disk need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# KV Cache Offloading

Keep evicted KV blocks in a larger, slower tier (pinned CPU RAM, local disk, object storage, or another instance) so long or repeated prefixes are loaded back instead of recomputed. Offloading adds capacity for reuse. It does not make a single request's active KV fit when the GPU cannot hold it.

**Scope:** this cross-product technique, with per-engine flags and safeguards. Product install and tuning stay in product skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Engine, version and any existing offload or transfer flags
ps -eo pid,args | grep -E 'vllm|sglang|trtllm|llama-server|lmcache|tabby' | grep -v grep
vllm --version 2>/dev/null; llama-server --version 2>&1 | head -2

# Host memory (offload tiers live here) and NUMA layout
free -g; numactl --hardware 2>/dev/null | head -8
ulimit -l      # locked-memory limit; pinned memory can fail when low

# Disk tier candidates: free space, filesystem, mount
df -hT "${CACHE_DIR:-/var/tmp}"

# Is there reuse to exploit? Look at prefix-cache hit and KV usage counters
curl -fsS "${BASE_URL:-http://127.0.0.1:8000}/metrics" 2>/dev/null | grep -iE 'prefix|kv_cache|cache_hit' | head -20

nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv 2>/dev/null
```

Also ask: how long are shared prefixes (system prompts, RAG documents, agent histories), how many users share them, whether instances must share cache, and whether tenants are mutually untrusted.

## Decision flow

1. **Is there reuse?** Offloading pays off when prefixes are requested again after the GPU prefix cache evicted them: multi-turn chat, agents, shared system prompts, repeated documents. Unique prompts see no benefit. Measure the prefix-cache hit rate and whether evictions precede re-requests before spending host RAM.
2. **Capacity or recompute problem?** If a single request's KV does not fit, shrink the cache (`kv-cache-quantization` skill), shard (`multi-node-inference` skill) or shorten context. Offloading helps the cold tail, not the active set.
3. **Pick the lightest tier that works:** CPU RAM first (DMA copies overlap with compute), then disk or object storage for persistence and sharing, then remote or peer tiers for multi-instance reuse.
4. **Size the tier:** vLLM native CPU tier should be larger than the aggregate GPU KV cache, otherwise it only mirrors the GPU (upstream tuning tip). Leave RAM headroom for the OS and the engine. See `references/engine-matrix.md` for each engine's size flag and unit.
5. **Decide the sharing scope and trust boundary** before enabling any shared tier. See Security.
6. **Apply on a staging instance, keep the baseline, verify, roll out.**

## Rules

- **Ask before changing the system.** Restarting an engine, reserving large host memory, or writing cache to disk needs approval and an undo path.
- **Secrets never touch output.** Object-store keys live in `0600` files, environment variables or workload identity, never in commands that echo or in committed files.
- **Cached KV is derived from prompts.** Treat disk, object and remote tiers as sensitive data: restrictive permissions, retention limits, no shared tier across mutually untrusted tenants without isolation (cache salt or separate namespaces).
- **Verify upstream.** Connector and flag names change fast (vLLM's offloading moved to a new connector). Check `--help` of the installed engine.
- **One feature at a time.** Combining offload with quantized KV, speculative decoding or disaggregation has engine-specific limits (see matrix).

## Quality gate

Plain byte-for-byte offload and reload is not meant to change outputs, but reuse of cached KV can differ from recomputation through batch-shape and kernel effects (llama.cpp warns `cache_prompt` can make results nondeterministic). Options that reuse non-prefix KV or compress KV (for example LMCache blending or compression features, (details unverified here)) are lossy and need the full gate.

Gate with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`):

1. **Baseline:** the same engine and model without the offload tier.
2. **Candidate:** only the offload configuration changes.
3. **Eval set:** the user's golden set, run twice for the candidate (cold, then warm so blocks are served from the offload tier), including multi-turn and long-prefix items.
4. **Threshold, chosen by the user before running:** the allowed pass-rate drop for warm versus baseline beyond baseline-vs-baseline noise. Lossless tiers should land inside noise; lossy options must meet the threshold explicitly.
5. **Rollback:** keep the baseline launch command and unit file; on failure restart without the tier and clear the cache directory or namespace.

## Techniques per engine

- [ ] Confirm there is reuse and that evictions precede re-requests.
- [ ] Pick the tier and the engine path in `references/engine-matrix.md`.
- [ ] Size the host tier and check `ulimit -l`, NUMA placement and free RAM.
- [ ] Decide security scope (shared or per-tenant) and set permissions on any disk path.
- [ ] Start a staging instance; keep the baseline running.
- [ ] Send the same long prompt twice, then flood the GPU cache with other prompts, then resend it. The third request should hit the offload tier.
- [ ] Run the quality gate where required.
- [ ] Verify: offload hit counters rise, time to first token on the repeat is lower than baseline, host RAM and disk stay within budget, throughput of unrelated traffic did not drop, and the rollback command is recorded.

## Reference index

- `references/engine-matrix.md`: per-engine flags and config keys with defaults and constraints for vLLM (native, tiering, LMCache), SGLang HiCache, TensorRT-LLM, llama.cpp, TabbyAPI/ExLlamaV3, TensorFold and Ollama. Load for any apply step.
- `references/sharing-security-and-troubleshooting.md`: tier scopes, cache-key and hashing security, sizing arithmetic, and troubleshooting. Load before sharing across instances or tenants, or when hits stay low.

## Companion skills

- `llm-evals`: A/B quality gate and decision record. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `vllm`: install and operate vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: install and operate SGLang. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `tensorrt-llm`: install and operate TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `llama-cpp`: install and operate llama.cpp. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `ollama`: install and operate Ollama. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
- `tensorfold`: install and operate TensorFold. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorfold`.
- `exllamav3`: install and operate ExLlamaV3 and TabbyAPI. Install: `npx skills add ScaleDockHQ/llm-skills --skill exllamav3`.
- `kv-cache-quantization`: shrink the cache instead of moving it. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`.
- `prefix-aware-routing`: route requests to the instance that holds their prefix. Install: `npx skills add ScaleDockHQ/llm-skills --skill prefix-aware-routing`.
- `disaggregated-serving`: prefill/decode split that shares KV between instances. Install: `npx skills add ScaleDockHQ/llm-skills --skill disaggregated-serving`.
- `multi-node-inference`: spread weights and KV across nodes. Install: `npx skills add ScaleDockHQ/llm-skills --skill multi-node-inference`.
- `long-context`: long-context serving and evaluation. Install: `npx skills add ScaleDockHQ/llm-skills --skill long-context`.
- `choosing-hardware`: size RAM, GPUs and storage. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `self-hosted-llms`: run the stack on owned GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
