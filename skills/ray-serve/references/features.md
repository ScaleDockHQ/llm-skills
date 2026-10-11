# Features: routing, prefill/decode, LoRA, streaming

> Verified against Ray 2.59.0 (docs `serve/llm/user-guides/*`), 2026-10-11

## Request routers (`deployment_config.request_router_config`)

| Router                      | Routes on                               | Notes                                                    |
| --------------------------- | --------------------------------------- | -------------------------------------------------------- |
| default (power of two)      | queue length                            | baseline                                                 |
| `RoundRobinRouter`          | order                                   | simplest even spread                                     |
| `ConsistentHashRouter`      | `x-session-id` header                   | sticky sessions; a hot session can saturate its replica  |
| `PrefixCacheAffinityRouter` | prompt text prefix tree (alpha)         | needs `enable_prefix_caching: true`                      |
| `KVAwareRouter`             | token load using vLLM KV events (alpha) | needs direct streaming, `pip install "ai-dynamo>=1.4.0"` |

`PrefixCacheAffinityRouter` params: `imbalanced_threshold` (default infinity), `match_rate_threshold` (0.1),
`do_eviction` (False), `eviction_threshold_chars` (400000), `eviction_target_chars` (360000),
`eviction_interval_secs` (10). With a match rate under 10% it picks the least-utilized replica; when queue
imbalance exceeds the threshold it falls back to power of two. Verify the effect with vLLM's prefix cache hit metric.

`KVAwareRouter` environment (set before starting Serve):

```bash
export RAY_SERVE_ENABLE_HA_PROXY=1
export RAY_SERVE_LLM_ENABLE_DIRECT_STREAMING=1
export RAY_SERVE_INGRESS_REQUEST_ROUTER_FORWARD_BODY=1
```

HAProxy forwards only a prefix of bodies over `RAY_SERVE_HAPROXY_INGRESS_REQUEST_ROUTER_BUFSIZE` (256 KiB default);
raise it when `serve_haproxy_ingress_router_truncations_total` grows. For routing across Kubernetes pods
instead (not Ray replicas), see skill `gateway-api-inference-extension`.

## Direct streaming (experimental)

Removes the ingress hop: `LLMServer` is the HTTP ingress, HAProxy forwards straight to replicas. Set
`RAY_SERVE_ENABLE_HA_PROXY=1` and `RAY_SERVE_LLM_ENABLE_DIRECT_STREAMING=1`. Single model per application.

## Prefill/decode disaggregation

Entry point `build_pd_openai_app({"prefill_config": ..., "decode_config": ...})`, vLLM v1 only. KV transfer
through `engine_kwargs.kv_transfer_config`:

```yaml
kv_transfer_config: { kv_connector: NixlConnector, kv_role: kv_both }
```

Alternative `LMCacheConnectorV1` (`pip install lmcache`, per-role LMCache config files). Prefill and decode scale
independently and may use different node types. NIXL is bundled in `ray-llm` images. General guidance and
gates: skill `disaggregated-serving`.

## Multi-LoRA

```yaml
lora_config:
  {
    dynamic_lora_loading_path: "s3://bucket/loras",
    max_num_adapters_per_replica: 16,
  }
engine_kwargs: { enable_lora: true, max_lora_rank: 32, max_loras: 16 } # max_loras == max_num_adapters_per_replica
```

Adapters are subfolders of the path. Query with `"model": "<model_id>:<adapter_folder>"`. Routing prefers a
replica already holding the adapter and not overloaded; adapters are cached per replica, LRU.

## KV cache offloading

`kv_transfer_config` with an offloading connector; see the Ray guide `kv-cache-offloading` and skill
`kv-cache-offloading`.

## Other

- SGLang via `server_cls` (`pip install "ray[llm]" "sglang[all,ray]"`, set `RAY_EXPERIMENTAL_NOSET_CUDA_VISIBLE_DEVICES=0`);
  early-stage community support.
- TPU serving has its own guide; KubeRay ships a TPU v6e sample.
- Streaming batching: `experimental_configs.stream_batching_interval_ms` (50).

## Sources

https://docs.ray.io/en/latest/serve/llm/user-guides/index.html
