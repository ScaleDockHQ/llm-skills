# Troubleshooting

> Verified against production-stack chart vllm-stack 0.1.13 and router (tutorials, helm templates, src/vllm_router), 2026-10-11

Start with: `kubectl get pods`, `kubectl describe pod <p>`, `kubectl logs <engine-pod>`,
`kubectl logs deploy/vllm-deployment-router`, `curl localhost:30080/engines`.

| Symptom                                                           | Cause                                                      | Fix                                                                           |
| ----------------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Pod `ContainerCreating` or error "runtime class nvidia not found" | Chart default `runtimeClassName: "nvidia"`                 | Install the NVIDIA RuntimeClass (GPU Operator) or set `runtimeClassName: ""`  |
| Pod `Pending`, insufficient `nvidia.com/gpu`                      | `requestGPU` too high, no GPU nodes, device plugin missing | `kubectl describe node`; match `requestGPU` to `tensorParallelSize`           |
| Pod `Pending`, PVC unbound                                        | No default StorageClass                                    | Set `storageClass` or `pvcExistingClaimName`                                  |
| CrashLoop, CUDA out of memory                                     | Context or utilization too high, TP too low                | Lower `maxModelLen`, `gpuMemoryUtilization`; raise TP                         |
| Killed during model load                                          | Probe timeout                                              | Raise `startupProbe.failureThreshold`                                         |
| `401`/gated repo                                                  | Missing token                                              | Use `hf_token: {secretName, secretKey}`; accept the model licence             |
| `/v1/models` empty or `/engines` empty                            | Engines not ready or label mismatch                        | Wait for Ready; check service discovery type and namespace RBAC (`role.yaml`) |
| Router 400 "model not found"                                      | Request `model` differs from `modelURL`                    | Use the id from `/v1/models`                                                  |
| `helm install` schema error on `routingLogic`                     | Chart schema lacks that logic                              | See `routing.md` gotcha; upgrade the chart                                    |
| Prefix or KV routing does nothing                                 | Prefix caching off, wrong image, controller ports          | See `routing.md`; check router logs                                           |
| Tutorial values fail on 0.1.13                                    | Tutorials track `main`                                     | Check out tag `vllm-stack-0.1.13` for values files                            |
| `ImagePullBackOff`                                                | Tag missing or rate limit                                  | Verify tag on Docker Hub, set `imagePullSecret`                               |
| Slow restarts                                                     | Model re-downloaded                                        | Keep the PVC; use `pvcExistingClaimName` or `sharedPvcStorage`                |

Escalate with `helm get manifest vllm | less` to see what the chart rendered, and the project's issues:
<https://github.com/vllm-project/production-stack/issues>.

## Sources

- <https://docs.vllm.ai/projects/production-stack>
