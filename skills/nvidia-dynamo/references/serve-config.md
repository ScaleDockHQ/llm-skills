# NVIDIA Dynamo serve configuration

> Verified against Dynamo v1.5.1 (PyPI ai-dynamo 1.5.1), 2026-10-11

Sources: `components/src/dynamo/frontend/frontend_args.py`, `kv_router_args.py`, vLLM configuration reference at v1.5.1.
Every option is a CLI flag and a `DYN_*` environment variable; the flag wins. Booleans are negatable (`--no-x`).
Always confirm with `--help` on the installed version.

## Frontend (`python3 -m dynamo.frontend`)

| Flag                                | Env                                | Default             | Notes                                                         |
| ----------------------------------- | ---------------------------------- | ------------------- | ------------------------------------------------------------- |
| `--http-host`                       | `DYN_HTTP_HOST`                    | `0.0.0.0`           | Set `127.0.0.1` unless fronted by a gateway                   |
| `--http-port`                       | `DYN_HTTP_PORT`                    | `8000`              | Also serves `/metrics`                                        |
| `--namespace`                       | `DYN_NAMESPACE`                    | none                | Restrict discovery to one runtime namespace                   |
| `--namespace-prefix`                | `DYN_NAMESPACE_PREFIX`             | none                | Watch all namespaces with the prefix (rolling updates)        |
| `--discovery-backend`               | `DYN_DISCOVERY_BACKEND`            | `etcd`              | `kubernetes`, `etcd`, `file`, `mem`                           |
| `--request-plane`                   | `DYN_REQUEST_PLANE`                | `tcp`               | `nats` or `tcp`                                               |
| `--event-plane`                     | `DYN_EVENT_PLANE`                  | unset               | `nats` or `zmq`                                               |
| `--router-mode`                     | `DYN_ROUTER_MODE`                  | `round-robin`       | `kv` for KV-aware; `direct` for GAIE sidecar                  |
| `--migration-limit`                 | `DYN_MIGRATION_LIMIT`              | `0`                 | Max request migrations after worker failure                   |
| `--kserve-grpc-server`              | `DYN_KSERVE_GRPC_SERVER`           | off                 | KServe gRPC endpoint; metrics on `--grpc-metrics-port` (8788) |
| `--enable-anthropic-api`            | `DYN_ENABLE_ANTHROPIC_API`         | off                 | Anthropic Messages API (Claude Code)                          |
| `--reasoning-field-name`            | `DYN_REASONING_FIELD_NAME`         | `reasoning_content` | or `reasoning`                                                |
| `--dyn-chat-processor`              | `DYN_CHAT_PROCESSOR`               | `dynamo`            | `dynamo`, `vllm`, `sglang`                                    |
| `--tokenizer`                       | `DYN_TOKENIZER`                    | `default`           | also `fastokens`, `basetenkenizer`                            |
| `--tls-cert-path`, `--tls-key-path` | `DYN_TLS_*`                        | none                | HTTPS on the frontend                                         |
| `--model-name`, `--model-path`      | `DYN_MODEL_NAME`, `DYN_MODEL_PATH` | none                | Override served name / local path                             |
| `--metrics-prefix`                  | `DYN_METRICS_PREFIX`               | none                | Rename metric families                                        |
| `--trust-remote-code`               | `DYN_TRUST_REMOTE_CODE`            | off                 | Only for models you trust                                     |

Other: `--enable-streaming-tool-dispatch`, `--enable-streaming-reasoning-dispatch`, `--dump-config-to`,
`--serve-indexer` (needs `kv`), TCP/NATS TLS paths (`--tcp-tls-*`, `--nats-tls-*`).

## KV router flags (frontend, with `--router-mode kv`)

| Flag                                                | Default       | Meaning                                                                                           |
| --------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------- |
| `--router-kv-events` / `--no-router-kv-events`      | on            | Event-backed cache state; off = prediction-based                                                  |
| `--load-aware`                                      | off           | Load-only routing                                                                                 |
| `--router-kv-overlap-score-credit`                  | `1.0`         | Weight of cache overlap                                                                           |
| `--router-temperature`                              | `0.0`         | Softmax sampling over workers                                                                     |
| `--router-ttl-secs`                                 | `120.0`       | TTL for approximate cache entries                                                                 |
| `--router-approximate-cache-policy`                 | `ttl`         | `ttl` or `lru`                                                                                    |
| `--router-queue-threshold`, `--router-queue-policy` | unset, `fcfs` | Queueing (`fcfs` or `wspt`)                                                                       |
| `--router-replica-sync`                             | off           | Sync state across router replicas                                                                 |
| `--router-policy-config <file>`                     | none          | Worker-selection policy YAML (`DYN_ROUTER_WORKER_SELECTION_POLICY=default` restores the built-in) |
| `--router-conditional-disagg`                       | off           | Choose local vs remote prefill (needs `kv`)                                                       |
| `--router-prefill-policy`, `--router-decode-policy` | unset         | Per-stage selection                                                                               |

Load shedding (off by default; any one threshold enables it, overload returns HTTP 529):
`--active-decode-blocks-threshold` (0.0-1.0), `--active-prefill-tokens-threshold`, `--active-prefill-tokens-threshold-frac`.

## vLLM worker (`python3 -m dynamo.vllm`)

Accepts every native vLLM engine argument plus Dynamo's:

| Flag                      | Env                            | Notes                                                                                                                             |
| ------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `--disaggregation-mode`   | `DYN_VLLM_DISAGGREGATION_MODE` | `agg` (default), `prefill`, `decode`, `pd` (alias of agg), encode modes for multimodal E/P/D                                      |
| `--headless`              | `DYN_VLLM_HEADLESS`            | Secondary node of a multinode TP/PP worker                                                                                        |
| `--kv-transfer-config`    | none                           | Native vLLM. **Required** on prefill workers: `'{"kv_connector":"NixlConnector","kv_role":"kv_both"}'`                            |
| `--kv-events-config`      | none                           | Native. `'{"enable_kv_cache_events":true,"publisher":"zmq","topic":"kv-events","endpoint":"tcp://*:5557"}'`; one port per DP rank |
| `--enable-prefix-caching` | none                           | Needed for KV routing value                                                                                                       |

The old `--connector` flag and `DYN_CONNECTOR` raise `ValueError`; use `--kv-transfer-config`. Each worker on one host
needs a unique `VLLM_NIXL_SIDE_CHANNEL_PORT` and, for metrics, its own `DYN_SYSTEM_PORT`.
SGLang workers: `python3 -m dynamo.sglang --model-path <m>`; TensorRT-LLM: `python3 -m dynamo.trtllm` (see the backend
configuration pages; flags differ).

## Environment variables worth knowing

`DYN_SYSTEM_PORT` (worker metrics/health port), `DYN_WORKER_GRACEFUL_SHUTDOWN_TIMEOUT` (seconds, 60 in the disagg example),
`DYN_NAMESPACE_WORKER_SUFFIX`, `PYTHONHASHSEED=0` (vLLM KV routing), `DYN_MM_MAX_DATA_URL_MB` (default 16),
`DYN_MM_MAX_FILE_SIZE_MB` (default 64), `DYN_MM_ALLOW_INTERNAL=1`, `DYN_MM_TRUST_EGRESS_PROXY=1`, `DYN_MM_LOCAL_PATH`,
`DYN_HTTP_BACKEND` (only aiohttp remains), `HF_TOKEN`, `ETCD_ENDPOINTS`.
