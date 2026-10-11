# Prefix-aware routing: router flag and config matrix

> Verified against llm-d v0.10.0 (guides: optimized-baseline, precise-prefix-cache-aware, pd-disaggregation), llm-d-router v0.11.0 (plugin READMEs under pkg/epp/framework/plugins), Gateway API Inference Extension v1.6.2, NVIDIA Dynamo v1.5.1 (kv-aware-routing, router configuration-and-tuning, frontend-configuration), vLLM production-stack vllm-stack-0.1.13 (router parser), SGLang v0.5.21 (docs: advanced_features/sgl_model_gateway), AIBrix v0.7.0 (docs: gateway routing), 2026-10-11

A prefix-aware router sends a request to the replica that already holds the longest matching KV prefix, while still protecting against overload. There are two mechanisms:

- **Approximate**: the router keeps its own tree or LRU of what it sent where and assumes the replica still holds it. No engine integration, but it drifts when the engine evicts.
- **Precise**: engines publish KV cache events (stored and removed blocks) over ZMQ, the router builds an exact index. Needs matching block size, hash algorithm and a tokenizer in the router.

Both only help if requests share long literal prefixes (system prompts, tool schemas, few-shot examples, document context, multi-turn history) and the engine's own prefix cache is on.

## Which router

| Router                                                  | Mechanism                                                                                                                                      | Deploy shape                                                   | Engines                        |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------ |
| llm-d inference scheduler (EPP in llm-d-router v0.11.0) | Approximate (`approx-prefix-cache-producer`) or precise (`precise-prefix-cache-producer`)                                                      | Kubernetes, Gateway API, `InferencePool`                       | vLLM, SGLang                   |
| Gateway API Inference Extension v1.6.2                  | API (`InferencePool`, `InferenceObjective`) plus a lightweight round-robin reference EPP (`lwepp`). Prefix scoring lives in llm-d-router's EPP | Kubernetes                                                     | any pool of model servers      |
| Dynamo KV router                                        | Precise via KV events, or approximate with TTL (`--no-router-kv-events`)                                                                       | Frontend process (`dynamo.frontend`), Kubernetes or bare metal | vLLM, SGLang, TensorRT-LLM     |
| vLLM production-stack router                            | `prefixaware` (HashTrie, approximate), `kvaware` (LMCache controller), `session`, `roundrobin`, `loadaware`                                    | Kubernetes Helm chart or static backends                       | vLLM                           |
| SGLang Model Gateway (`sglang_router`)                  | `cache_aware` approximate radix tree                                                                                                           | Single binary or Kubernetes discovery                          | SGLang                         |
| AIBrix gateway                                          | `prefix-cache`, `prefix-cache-preble`, optional KV-event sync                                                                                  | Kubernetes, Envoy gateway                                      | vLLM, SGLang (see AIBrix docs) |

## llm-d / llm-d-router EPP

EPP config shape: `apiVersion: llm-d.ai/v1alpha1`, `kind: EndpointPickerConfig`, with `plugins`, `schedulingProfiles` and `dataLayer`. Run a **single** EPP replica for precise indexing (the guide does); two replicas would hold different indexes.

### Approximate mode

| Plugin                         | Parameter                | Default  | Meaning                                                                                                                                               |
| ------------------------------ | ------------------------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `approx-prefix-cache-producer` | `autoTune`               | `true`   | Derive block size and per-server LRU capacity from engine metrics where available.                                                                    |
|                                | `blockSizeTokens`        | `16`     | Hash block size when not auto-tuned. Keep it equal to the engine block size the guide uses (`--block-size=64` for vLLM, `--page-size=64` for SGLang). |
|                                | `maxPrefixBlocksToMatch` | `2048`   |                                                                                                                                                       |
|                                | `maxPrefixTokensToMatch` | `131072` |                                                                                                                                                       |
|                                | `lruCapacityPerServer`   | `31250`  | Blocks tracked per replica.                                                                                                                           |
| `prefix-cache-scorer`          | `matchLengthWeight`      | `0.0`    | Weight of absolute matched length versus match ratio.                                                                                                 |
|                                | `matchLengthScaleTokens` | `8192`   | Token count at which the length bonus saturates.                                                                                                      |

The llm-d optimized-baseline example mixes scorers with weights: queue-scorer 2, kv-cache-utilization-scorer 2, prefix-cache-scorer 3, no-hit-lru-scorer 2. Treat as a starting point for the chat workload it was tuned on and re-tune on yours.

### Precise mode

Plugins named in the guide: `token-producer`, `precise-prefix-cache-producer`, `endpoint-notification-source`, `inflight-load-producer`, `prefix-cache-affinity-filter`, `token-load-scorer`.

| Setting                                                                | Default         | Meaning                                                                                                             |
| ---------------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------- |
| `precise-prefix-cache-producer` `tokenProcessorConfig.blockSizeTokens` | none            | **Must equal** the engine block size (vLLM `--block-size`, SGLang `--page-size`).                                   |
| `...` `speculativeIndexing`                                            | `false`         | Pre-insert a routed request's blocks before the engine confirms them.                                               |
| `...` `speculativeTTL`                                                 | `2s`            | Lifetime of a speculative entry.                                                                                    |
| `...` `kvEventsConfig.topicFilter`                                     | `kv@`           | ZMQ topic prefix filter.                                                                                            |
| `...` `kvEventsConfig.discoverPods`                                    | see guide       | Subscribe to each pod discovered via the pool.                                                                      |
| `...` `podDiscoveryConfig.socketPort` / `replaySocketPort`             | `5556` / `5559` | Pod publisher and replay ports used by the EPP.                                                                     |
| `prefix-cache-affinity-filter` `peakPrefillThroughput`                 | none            | Measured peak prefill tokens/s of one replica. The guide uses `33821` for its reference hardware: measure your own. |

Engine side for the precise guide (vLLM): `--block-size=64`, `--kv-events-config '{"enable_kv_cache_events":true,"publisher":"zmq","endpoint":"tcp://*:5556","replay_endpoint":"tcp://*:5559","topic":"kv@<pod>@<model>"}'` (ports above are the EPP defaults; adjust in both places), and `--enable-scale-out` on vLLM 0.30 to serve the `/v1/*/render` endpoints the token producer uses. For SGLang use `--page-size=64` and a standalone render pool as the guide describes. Cache isolation: vLLM honours `cache_salt`; SGLang does not emit `extra_keys`, so do not rely on salts to isolate tenants on SGLang pools.

### Pool wiring (Gateway API Inference Extension)

```yaml
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata: { name: <pool> }
spec:
  selector:
    matchLabels: { app: <model-server-label> }
  targetPorts: [{ number: 8000 }]
  endpointPickerRef:
    name: <epp-service>
    port: { number: 9002 }
    failureMode: FailOpen
```

`endpointPickerRef` is optional since GAIE v1.5.0. With `FailOpen` the gateway keeps serving when the picker is unavailable (check the GAIE docs for the exact fallback), so prefix hits can silently drop to chance: alert on EPP health.

## Dynamo KV router (v1.5.1)

Enable on the frontend: `python -m dynamo.frontend --router-mode kv`. Router flags (frontend-configuration, router configuration-and-tuning):

| Flag                                                                        | Default         | Meaning                                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--router-mode`                                                             | `round-robin`   | `round-robin`, `random`, `power-of-two`, `kv`, `direct`, `least-loaded`, `device-aware`.                                                                                                                                                                                |
| `--router-kv-events` / `--no-router-kv-events` (`DYN_ROUTER_USE_KV_EVENTS`) | `true`          | Use worker KV events; with `--no-router-kv-events` the router predicts cache state instead.                                                                                                                                                                             |
| `--router-ttl-secs`                                                         | `120.0`         | Only with `--no-router-kv-events`: lifetime of predicted blocks.                                                                                                                                                                                                        |
| `--router-event-threads`                                                    | `4`             | Event processing threads.                                                                                                                                                                                                                                               |
| `--router-replica-sync`                                                     | `false`         | Sync state between router replicas.                                                                                                                                                                                                                                     |
| `--kv-cache-block-size`                                                     | null (auto)     | Must match the engine block size when set.                                                                                                                                                                                                                              |
| `--router-kv-overlap-score-credit`                                          | `1.0`           | Weight of cache overlap in the cost function (a `...-decay` companion defaults to `0`).                                                                                                                                                                                 |
| `--router-prefill-load-scale`                                               | `1`             | Weight of prefill load.                                                                                                                                                                                                                                                 |
| `--router-host-cache-hit-weight` / `--router-disk-cache-hit-weight`         | `0.75` / `0.25` | Weight of host and disk tier hits relative to GPU hits.                                                                                                                                                                                                                 |
| `--router-temperature`                                                      | `0`             | `0` is deterministic best choice; above `0` samples.                                                                                                                                                                                                                    |
| `--router-queue-threshold`                                                  | off             | Queue requests above this load. `--router-queue-policy`: `fcfs` or `wspt`.                                                                                                                                                                                              |
| `--router-policy-config`                                                    | none            | YAML. `worker_selection` type `default` or `dynamo-two-tier-cost-fn` (`cache_threshold` 0.5, `balance_abs_threshold` 32, `balance_rel_threshold` 1.1). Env `DYN_ROUTER_WORKER_SELECTION_POLICY`, flags `--router-prefill-policy` and `--router-decode-policy` override. |
| `--router-session-affinity-ttl-secs`                                        | see docs        | Pin a session to a worker.                                                                                                                                                                                                                                              |
| `--router-min-initial-workers`                                              | `0`             | Wait for workers at startup.                                                                                                                                                                                                                                            |
| `--load-aware`                                                              | off             | Load-aware selection.                                                                                                                                                                                                                                                   |
| `--http-port`                                                               | `8000`          | Frontend port.                                                                                                                                                                                                                                                          |

For vLLM workers set `PYTHONHASHSEED=0` on every worker so block hashes are consistent across processes. vLLM workers publish events via `--kv-events-config`, as in the Dynamo disagg example: `{"publisher":"zmq","topic":"kv-events","endpoint":"tcp://*:20081","enable_kv_cache_events":true}` (one distinct endpoint per worker on a host). SGLang workers use `--kv-events-config` (JSON; enables Dynamo-format KV event publishing) and `--page-size` that matches the router block size.

## vLLM production-stack router (vllm-stack-0.1.13)

| Flag                                  | Default              | Meaning                                                                                                                                                                                                       |
| ------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--routing-logic`                     | none (required)      | `roundrobin`, `session`, `kvaware`, `loadaware`, `prefixaware`, `disaggregated_prefill`, `disaggregated_prefill_orchestrated`, `priority`.                                                                    |
| `--service-discovery`                 | none                 | `static`, `k8s` or `external-only`. With `static`: `--static-backends`, `--static-models`, `--static-model-labels`. With `k8s`: `--k8s-port` (`8000`), `--k8s-namespace` (`default`), `--k8s-label-selector`. |
| `--session-key`                       | none                 | HTTP header used for `session` routing.                                                                                                                                                                       |
| `--lmcache-controller-port`           | `9000`               | `kvaware` only; needs the LMCache controller.                                                                                                                                                                 |
| `--kv-aware-threshold`                | `2000`               | `kvaware` only.                                                                                                                                                                                               |
| `--prefix-min-match-length`           | `0`                  | `prefixaware` only; the HashTrie works on 128-character chunks.                                                                                                                                               |
| `--loadaware-beta` (`LOADAWARE_BETA`) | `1.0`                | `loadaware` only.                                                                                                                                                                                             |
| `--engine-stats-interval`             | `30`                 | Seconds between engine scrapes.                                                                                                                                                                               |
| `--request-stats-window`              | `60`                 | Seconds.                                                                                                                                                                                                      |
| `--priority-header`                   | `x-request-priority` | `priority` routing.                                                                                                                                                                                           |

`prefixaware` assumes no engine cache eviction. Helm values: `routerSpec.routingLogic`, and `lmcacheConfig.enableController` for `kvaware`.

## SGLang Model Gateway (v0.5.21)

Start with `python -m sglang_router.launch_router` (or the `sgl-model-gateway` binary, Docker image `lmsysorg/sgl-model-gateway`); worker selection is by URL list or Kubernetes discovery (flag name for the URL list: check `--help`).

| Flag                                                         | Default               | Meaning                                                                                        |
| ------------------------------------------------------------ | --------------------- | ---------------------------------------------------------------------------------------------- |
| `--policy`                                                   | `cache_aware`         | `random`, `round_robin`, `power_of_two`, `cache_aware`, `bucket`.                              |
| `--cache-threshold`                                          | `0.3`                 | Minimum prefix match ratio to route by cache.                                                  |
| `--balance-abs-threshold`                                    | `64`                  | Absolute load-imbalance trigger for the cache-aware policy (see upstream for exact semantics). |
| `--balance-rel-threshold`                                    | `1.5`                 | Relative imbalance trigger.                                                                    |
| `--eviction-interval-secs`                                   | `120`                 | Approximate tree cleanup.                                                                      |
| `--max-tree-size`                                            | `67108864`            | Max nodes in the approximate tree.                                                             |
| `--host` / `--port`                                          | `127.0.0.1` / `30000` | Default bind is loopback.                                                                      |
| `--max-concurrent-requests`                                  | `-1`                  | No limit.                                                                                      |
| `--request-timeout-secs`                                     | `600`                 |                                                                                                |
| `--retry-max-retries`, `--cb-failure-threshold`              | `5`, `5`              | Retries and circuit breaker.                                                                   |
| `--service-discovery`, `--selector`                          | off                   | Kubernetes discovery by label.                                                                 |
| `--pd-disaggregation`, `--prefill-policy`, `--decode-policy` | off                   | PD mode, with separate policies per side.                                                      |
| `--enable-igw`                                               | off                   | Inference Gateway mode.                                                                        |

## AIBrix v0.7.0

Strategy per request via header `routing-strategy`, or global default via the gateway env `ROUTING_ALGORITHM`. Strategies listed in the docs: `random`, `least-request`, `least-busy-time`, `least-latency`, `least-kv-cache`, `least-gpu-cache`, `least-utilization`, `throughput`, `power-of-two`, `prefix-cache`, `prefix-cache-preble`, `vtc-basic`, `slo`, `slo-pack-load`, `slo-least-load`, `slo-least-load-pulling`, `pd`, `session-affinity`.

| Env (gateway)                                                                                            | Default     | Meaning                                                                                                                                                                                                                                                                                                                           |
| -------------------------------------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AIBRIX_PREFIX_CACHE_TOKENIZER_TYPE`                                                                     | `character` | or `tiktoken`.                                                                                                                                                                                                                                                                                                                    |
| `AIBRIX_PREFIX_CACHE_BLOCK_SIZE`                                                                         | `128`       |                                                                                                                                                                                                                                                                                                                                   |
| `AIBRIX_PREFIX_CACHE_BLOCK_NUMBER`                                                                       | `200000`    |                                                                                                                                                                                                                                                                                                                                   |
| `AIBRIX_PREFIX_CACHE_POD_RUNNING_REQUEST_IMBALANCE_ABS_COUNT`                                            | `16`        |                                                                                                                                                                                                                                                                                                                                   |
| `AIBRIX_PREFIX_CACHE_STANDARD_DEVIATION_FACTOR`                                                          | `2`         |                                                                                                                                                                                                                                                                                                                                   |
| `AIBRIX_PREFIX_CACHE_KV_EVENT_SYNC_ENABLED`, `..._USE_REMOTE_TOKENIZER`, `..._REMOTE_TOKENIZER_ENDPOINT` | off         | Precise KV-event mode. Needs a ZMQ-enabled gateway build (`-tags="zmq"`, libzmq) and the pod label `model.aibrix.ai/kv-events-enabled`. vLLM args shown upstream: `--enable-kv-cache-events --kv-events-publisher=zmq --kv-events-endpoint=tcp://*:5557 --kv-events-replay-endpoint=tcp://*:5558 --kv-events-buffer-steps=10000`. |

`session-affinity` encodes the pod address in the `x-session-id` response header: it is a routing hint, not a security token; do not treat it as authentication. The AIBrix gateway is publicly reachable by design: enable authentication (vLLM `--api-key` or `VLLM_API_KEY` on the engines) before exposing it.

## Not verified here

- Dynamo `--router-session-affinity-ttl-secs` default, `--load-aware` semantics (names only).
- llm-d `kvEventsConfig.discoverPods` default, whether `blockSizeTokens` is clamped when `autoTune` is on.
- AIBrix `ROUTING_ALGORITHM` default value; which AIBrix engine versions support KV events.
- SGLang gateway behaviour with `--policy bucket` (name only).
