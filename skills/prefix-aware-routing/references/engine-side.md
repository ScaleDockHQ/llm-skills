# Prefix-aware routing: engine-side settings, validation and gates

> Verified against vLLM v0.31.0 (vllm/config/cache.py, vllm/config/kv_events.py), SGLang v0.5.21 (docs: advanced_features/server_arguments), llm-d v0.10.0 (precise prefix cache guide), NVIDIA Dynamo v1.5.1 (kv-aware-routing), llm-evals skill quality-gates procedure, 2026-10-11

Routing only pays off when each replica's own prefix cache works and the router agrees with the engine on how a prompt is cut into blocks.

## vLLM v0.31.0

| Flag / field                                                                       | Default                                      | Notes                                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--enable-prefix-caching` / `--no-enable-prefix-caching` (`enable_prefix_caching`) | `true`                                       | On by default in v0.31.0.                                                                                                                                                                                                                                   |
| `--prefix-caching-hash-algo`                                                       | `sha256`                                     | Router and engine must agree when the router computes hashes itself (precise mode). Changing it invalidates any hash index.                                                                                                                                 |
| `--block-size`                                                                     | platform-chosen (field has no fixed default) | Set it explicitly and give the **same** number to the router (`blockSizeTokens` in llm-d, `--kv-cache-block-size` in Dynamo). The llm-d guide uses `64`.                                                                                                    |
| `--kv-events-config`                                                               | none                                         | JSON. `enable_kv_cache_events` (`false`), `publisher` (`null` or `zmq`; unset means no publishing), `endpoint` (`tcp://*:5557`), `replay_endpoint` (none), `buffer_steps` (`10000`), `hwm` (`100000`), `max_queue_size` (`100000`), `topic` (empty string). |
| `--enable-scale-out`                                                               | off                                          | Needed on vLLM 0.30 to serve the `/v1/*/render` endpoints llm-d's token producer calls (per the llm-d guide).                                                                                                                                               |
| `cache_salt` (request field)                                                       | none                                         | Isolates prefix-cache entries per salt. llm-d notes it is isolated for vLLM.                                                                                                                                                                                |

Per-worker rules: one distinct `endpoint` and `replay_endpoint` per engine process on a host (data-parallel ranks too); set `PYTHONHASHSEED=0` when a router (Dynamo) compares hashes across processes.

Check the cache really hits (read-only): `curl -s http://<engine>:8000/metrics | grep -i prefix`, and compare TTFT of the second identical long request against the first.

## SGLang v0.5.21

| Flag                      | Default | Notes                                                                                                                                                                     |
| ------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--disable-radix-cache`   | `False` | RadixAttention prefix cache is on unless you pass this.                                                                                                                   |
| `--page-size`             | `1`     | Tokens per KV page. Set it to the router block size (llm-d guide uses `64`).                                                                                              |
| `--radix-eviction-policy` | `lru`   | `lru`, `lfu`, `slru`, `priority`.                                                                                                                                         |
| `--schedule-policy`       | `fcfs`  | `lpm` (longest prefix match) reorders the engine's own queue for hits; others: `random`, `dfs-weight`, `lof`, `priority`, `routing-key`.                                  |
| `--enable-cache-report`   | `False` | Returns cached token counts in `usage.prompt_tokens_details`. Turn it on to measure hits per request.                                                                     |
| `--kv-events-config`      | none    | JSON; publishes KV events in the format Dynamo's router consumes.                                                                                                         |
| `--load-publish-endpoint` | off     | Runtime-load PUB socket for load-aware routers; requires `--kv-events-config`; startup fails if it overlaps the KV event ports. `auto` reserves ports after the KV range. |

## Make the hit rate real

1. Put stable content first: system prompt, tool definitions, few-shot examples, then documents, then the user turn. A timestamp or request id at the top of the prompt defeats every router on this page.
2. Keep the chat template and tool serialization byte-stable between turns. Reasoning models that strip earlier thinking from history change the prefix on every turn (see the `reasoning-models` skill).
3. Use session or affinity keys only to break ties. Overweighting affinity creates hot replicas; Dynamo's `--router-queue-threshold` and the llm-d scorer weights exist to rebalance.
4. Size the router's index to the engine: llm-d `lruCapacityPerServer` (31250 blocks), AIBrix `AIBRIX_PREFIX_CACHE_BLOCK_NUMBER` (200000), SGLang gateway `--max-tree-size` (67108864). An approximate tree larger than the engine cache lies about hits.

## Validate

1. **Baseline**: same replicas behind plain round-robin or least-load. Record TTFT p50/p95, tokens/s, and per-replica cache hit rate on a replay of real traffic (or a workload with real shared prefixes; random prompts will show no gain).
2. **Candidate**: enable one router mode (approximate first, precise second). Compare the same metrics. Expect gains only for workloads with long shared prefixes.
3. **Skew check**: per-replica running requests and queue depth. One replica taking most traffic is a routing failure even when hit rate looks great.
4. **Failure drills** (staging): kill the router/EPP, kill one replica, restart one replica (cold cache). With precise mode a restarted engine must republish or replay events; check the index drops its old blocks. Alert on EPP availability: with GAIE `FailOpen` traffic continues without prefix awareness.
5. **Verify** (done when): a repeated long prompt lands on the same replica and shows a cache hit in engine metrics or `usage.prompt_tokens_details`; TTFT of repeats falls versus baseline; no replica exceeds your load-skew budget.

## Numerics: what to gate

Exact prefix routing does not change what a replica computes for a given token sequence, but these related options change outputs or cache behaviour and must pass the `llm-evals` gate (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`):

- Any change of KV-cache dtype used to make the prefix cache larger (for example FP8 KV): lossy, gate it.
- Engine upgrades or attention-backend changes made while enabling precise routing.
- Any option that reuses KV from something other than an exact prefix, such as blending or approximate reuse in an external cache (unverified for the engines above; treat as lossy).
- Caching reasoning output: SGLang's opt-in flag that skips caching reasoning-model output on finish "changes cache contents".

Gate procedure:

1. Write the gate first: metric (golden-set pass rate), threshold (within baseline-vs-baseline noise, no regression on critical items), decision owner.
2. Baseline = routing and cache settings as in production; candidate = one change.
3. Replay the same multi-turn and shared-prefix prompts, same sampling, seed, `max_tokens` and chat template, through baseline and candidate. Include requests that are cache hits and requests that are cold misses, since a bug in prefix handling shows up as hit-only differences.
4. Run the baseline against itself to measure noise.
5. Score with promptfoo on the golden set; compare hit-only versus miss-only subsets separately.
6. Decide pass, fail, or pass-with-conditions, record it, and keep the previous routing config for rollback.

## Security

- KV-event ZMQ ports, side channels and the engine metrics endpoints are internal: bind to a private network and firewall them.
- Cross-tenant prefix reuse can leak information through timing (general caution, not stated in the upstream docs read here) and through `cache_salt`-less sharing. Use per-tenant salts on vLLM pools; llm-d notes SGLang does not emit `extra_keys`, so isolate tenants by pool instead.
- AIBrix `x-session-id` encodes a pod address: never accept it from untrusted clients as an authorization signal.
