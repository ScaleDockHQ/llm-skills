# Troubleshooting

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

Start: `kubectl get pods -n aibrix-system`, `kubectl logs -n aibrix-system deploy/aibrix-gateway-plugins`,
`kubectl get httproute -A`, `kubectl describe httproute <model>-router -n aibrix-system`.

| Symptom                             | Cause                                                                      | Fix                                                                        |
| ----------------------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| 404 or "model not found"            | `model` in request differs from `model.aibrix.ai/name`                     | Align Service name, label, `--served-model-name`, request                  |
| "no ready pods for routing"         | Pods not Ready, label missing, or `external-filter` excludes all           | Check pod Ready, labels `model.aibrix.ai/name` and `port`; drop the filter |
| HTTPRoute missing                   | Labels absent or controller down                                           | Check controller-manager logs; add required labels                         |
| Gateway unreachable                 | Envoy Service has no external IP                                           | Use port-forward; EKS uses a hostname                                      |
| Routing ignored (EnvoyPatchPolicy)  | Envoy Gateway lacks `enableEnvoyPatchPolicy`                               | Patch `envoy-gateway-config`, restart envoy-gateway                        |
| Inconsistent `prefix-cache` routing | Several gateway replicas without Redis sync                                | `AIBRIX_STATESYNC_ENABLED: "true"` and Redis                               |
| Strategy errors on metrics          | Prometheus not reachable                                                   | Configure Prometheus API access                                            |
| PodAutoscaler does nothing          | `scaleTargetRef.name` mismatch, wrong metric port                          | Match the Deployment name; check `/metrics` on 8000                        |
| ModelAdapter stuck in Loading       | Pods lack `adapter.model.aibrix.ai/enabled`, bad `artifactURL`, no runtime | Check labels, URL, `kubectl describe modeladapter`                         |
| P/D pods fail                       | Image or RDMA network assumptions                                          | Use matching AIBrix image; remove cloud-specific annotations               |
| Ray fleet pods absent               | KubeRay not installed                                                      | Install KubeRay or use StormService                                        |
| `ImagePullBackOff` on sample images | Sample registry unreachable                                                | Use `docker.io/aibrix` images or your mirror                               |

Issues: <https://github.com/vllm-project/aibrix/issues>.

## Sources

- <https://aibrix.readthedocs.io/latest/>
