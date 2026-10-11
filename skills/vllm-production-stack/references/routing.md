# Routing

> Verified against production-stack chart vllm-stack 0.1.13 and router (tutorials, helm templates, src/vllm_router), 2026-10-11

Set `routerSpec.routingLogic`. Service discovery (`k8s` by default) finds engine pods by label; check with
`curl localhost:30080/engines`.

| Logic                                                         | Behaviour                                                                  | Needs                                                                                       |
| ------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `roundrobin` (default)                                        | Even spread                                                                | nothing                                                                                     |
| `session`                                                     | Sticky by request header named in `sessionKey` (for example `x-user-id`)   | `routerSpec.sessionKey`                                                                     |
| `prefixaware`                                                 | Hash-trie of prompts; reuses the endpoint with the longest matching prefix | engines with `enablePrefixCaching: true`; `prefixMinMatchLength`                            |
| `kvaware`                                                     | Asks the LMCache controller which instance holds the KV                    | LMCache image, controller ports, unique `instanceId`; `--kv-aware-threshold` (default 2000) |
| `disaggregated_prefill`, `disaggregated_prefill_orchestrated` | Prefill and decode on separate model pools                                 | NIXL via LMCache; labels per role                                                           |
| `priority`                                                    | Request priority header or body field; lower number is higher priority     | Engine `--scheduling-policy priority`; chart newer than 0.1.13 may be needed                |

**Chart schema gotcha:** `values.schema.json` in 0.1.13 accepts only the first six values. The router code also has
`loadaware` and `priority`, so passing them can fail `helm install` validation. Check
`helm show values vllm/vllm-stack --version <v>` and the schema; on 0.1.13 set the extra logic through
`routerSpec.extraArgs` only if the schema allows, otherwise upgrade to a newer chart.

## Session routing

```yaml
routerSpec:
  routingLogic: "session"
  sessionKey: "x-user-id"
```

Clients send `-H 'x-user-id: alice'`. Requests with no header fall back to load balancing.

## Prefix-aware

```yaml
servingEngineSpec:
  modelSpec:
    - name: llama
      vllmConfig: { enablePrefixCaching: true }
routerSpec:
  routingLogic: "prefixaware"
```

Test: send two completions with the same long prefix, then read router logs
(`kubectl logs deploy/vllm-deployment-router`) and engine `vllm:prefix_cache_hits_total`. The router's prefix
trie lives in memory per router replica, so with `replicaCount > 1` hit rates drop. For cluster-wide precise
routing see skill `llm-d`.

## KV-aware (LMCache controller)

Use the tutorial values (`tutorials/assets/values-17-kv-aware.yaml`): engines with
`lmcacheConfig.enableController: true`, `controllerPort: 9000`, `controllerReplyPort: 9001`, `workerPorts`,
`p2pHost`, `p2pInitPorts`, `workerHeartbeatTime`; router with `routingLogic: kvaware`,
`lmcacheControllerPort: 9000`, `lmcacheControllerReplyPort: 9001`, `lmcacheControllerHeartbeatPort: 9002`.
Each additional replica instance needs its own `instanceId`. The tutorial uses engine image
`lmcache/vllm-openai:v0.3.9post2`; match the LMCache version to the router's controller protocol.

## Priority

Router flags via `routerSpec.extraArgs`: `--priority-header x-request-priority`, `--priority-field priority`,
`--priority-default 0`, `--priority-threshold 0` (priority strictly below the threshold counts as high). Engines get
`vllmConfig.extraArgs: ["--scheduling-policy","priority"]`.

## Disaggregated prefill

Two `modelSpec` entries (producer and consumer) with `lmcacheConfig.kvRole` (`kv_producer`/`kv_consumer`),
`enableNixl`, `nixlRole`, `nixlPeerHost`, `nixlPeerPort`, buffer size and device, and router
`routingLogic: disaggregated_prefill` with prefill and decode model labels. Needs NVLink or RDMA-capable
networking to pay off; benchmark first (skill `disaggregated-serving`).

## Router endpoints

OpenAI-style: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/responses`, `/v1/messages`,
`/v1/rerank`, `/v1/score`, audio and image routes; plus `/v1/models`, `/engines`, `/health`, `/version`,
`/metrics`, `/sleep`, `/wake_up`, `/is_sleeping`, `/tokenize`, `/detokenize`.

## Sources

- <https://github.com/vllm-project/production-stack/tree/vllm-stack-0.1.13/tutorials>
- <https://github.com/vllm-project/production-stack/blob/vllm-stack-0.1.13/src/vllm_router>
