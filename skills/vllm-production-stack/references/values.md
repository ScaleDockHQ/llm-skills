# Values reference

> Verified against production-stack chart vllm-stack 0.1.13 (helm/values.yaml, values.schema.json, tutorials/assets), 2026-10-11

The commented defaults in `helm/values.yaml` are the source of truth; list them with
`helm show values vllm/vllm-stack --version 0.1.13`. Top-level sections: `servingEngineSpec`, `routerSpec`,
`cacheserverSpec`, `loraAdapters`, `loraController`, `sharedPvcStorage`, `grafanaDashboards`, `extraObjects`, and the
sub-charts `kube-prometheus-stack`, `prometheus-adapter`, `k8s-aibom`.

## servingEngineSpec (engines)

| Key                                                                   | Meaning                                                                    |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `enableEngine`, `labels`, `extraPorts`                                | Toggle and metadata                                                        |
| `runtimeClassName`                                                    | Default `"nvidia"`; set `""` if the cluster has no such RuntimeClass       |
| `vllmApiKey`                                                          | String (stored in a generated Secret) or `{secretName, secretKey}`         |
| `containerPort` / `servicePort`                                       | 8000 and 80                                                                |
| `startupProbe`, `livenessProbe`, `readinessProbe`                     | HTTP `/health` on 8000 by default; raise `failureThreshold` for big models |
| `tolerations`, `imagePullPolicy`, `securityContext`, `serviceMonitor` | Pod scheduling and metrics scrape                                          |
| `modelSpec[]`                                                         | One entry per deployed model (below)                                       |

### modelSpec entry

The `modelSpec` in `helm/values.yaml` is a disabled example; unlisted keys have no default.

| Key                                                                             | Meaning                                                                                                                                  |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `name`, `enabled`                                                               | Unique name (used in Service and Deployment names); `enabled: false` skips it                                                            |
| `repository`, `tag`, `imagePullSecret`                                          | Engine image; LMCache features need `lmcache/vllm-openai`                                                                                |
| `modelURL`, `modelRevision`                                                     | Hugging Face id or path; pin a revision                                                                                                  |
| `replicaCount`                                                                  | Replicas                                                                                                                                 |
| `requestCPU`, `requestMemory`, `requestGPU`, `requestGPUType`                   | Simple resources (`nvidia.com/gpu` by default; MIG or HAMi types supported); `limitCPU/limitMemory` optional, `resources:` overrides all |
| `pvcStorage`, `pvcAccessMode`, `storageClass`, `pvcExistingClaimName`           | Model cache PVC (the bundled example uses 50Gi); use an existing claim for GitOps                                                        |
| `shmSize`                                                                       | `/dev/shm` (example 20Gi)                                                                                                                |
| `hf_token`                                                                      | String, or `{secretName, secretKey}` to use an existing Secret; `envFromSecret` and `env` also available                                 |
| `chatTemplate`, `enableTool`, `toolCallParser`                                  | Chat template and tool calling                                                                                                           |
| `enableLoRA`, `loraAdapters`                                                    | LoRA                                                                                                                                     |
| `initContainer`                                                                 | Downloads the model into the PVC before start                                                                                            |
| `affinity`, `nodeSelectorTerms`, `nodeName`, `tolerations`, `tolerationsPolicy` | Placement                                                                                                                                |
| `raySpec`                                                                       | Deploy the model as a Ray cluster (pipeline parallel), head node resources                                                               |
| `keda`                                                                          | Per-model KEDA `ScaledObject` (see `scaling-and-observability.md`)                                                                       |

### vllmConfig (engine arguments)

`enablePrefixCaching`, `enableChunkedPrefill`, `maxModelLen`, `dtype`, `tensorParallelSize`,
`maxNumSeqs`, `maxLoras`, `gpuMemoryUtilization`, `runner`, `convert` (embedding and pooling models), `v0`, and
`extraArgs` for any other flag (for example `["--scheduling-policy","priority"]`). Look flags up with skill `vllm`. The
bundled example `modelSpec` is disabled and its numbers (TP 2, `v0: "1"`, `runner: pooling`, `convert: embed`) are illustrative, not defaults; omit `v0` so vLLM v1 is used. `requestGPU` must equal `tensorParallelSize` per replica.

### lmcacheConfig

`enabled`, `cpuOffloadingBufferSize` (GB), `logLevel`, plus controller fields for `kvaware` routing
(`enableController`, `controllerPort`, `controllerReplyPort`, `workerPorts`, `p2pHost`, `p2pInitPorts`,
`workerHeartbeatTime`, `instanceId` when running several instances).

## routerSpec

| Key                                                                                                                        | Meaning                                                      |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `enableRouter`, `replicaCount`, `repository`, `tag`, `imagePullPolicy`                                                     | Router image `lmcache/lmstack-router`                        |
| `serviceType`, `servicePort`, `nodePort`, `ingress`, `route`                                                               | Exposure (Gateway API `route.main` / `route.http` supported) |
| `serviceDiscovery` (`k8s`/`static`), `k8sServiceDiscoveryType` (`pod-ip`/`service-name`), `staticBackends`, `staticModels` | How backends are found                                       |
| `routingLogic`                                                                                                             | See `routing.md`                                             |
| `sessionKey`, `prefixMinMatchLength`                                                                                       | Session header name and prefix routing threshold             |
| `engineScrapeInterval`, `requestStatsWindow`                                                                               | Metrics windows (15 s and 60 s)                              |
| `extraArgs`, `env`, `resources`, `autoscaling`, `pdb`, `otel`, `serviceMonitor`, `vllmApiKey`                              | Operations                                                   |

## Other sections

`cacheserverSpec` (LMCache remote cache server), `loraController` and `loraAdapters`, `sharedPvcStorage` (shared
model storage: size, storage class, hostPath or NFS), `grafanaDashboards.enabled`, `extraObjects`.

## Secrets pattern

```bash
kubectl create secret generic hf-token --from-file=token=/path/to/token-file
kubectl create secret generic vllm-api-key --from-file=key=/path/to/key-file
```

```yaml
servingEngineSpec:
  vllmApiKey: { secretName: vllm-api-key, secretKey: key }
  modelSpec:
    - name: llama
      hf_token: { secretName: hf-token, secretKey: token }
```

## Sources

- <https://github.com/vllm-project/production-stack/blob/vllm-stack-0.1.13/helm/values.yaml>
- <https://docs.vllm.ai/projects/production-stack/en/latest/deployment/helm.html>
