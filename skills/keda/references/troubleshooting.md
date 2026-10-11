# Troubleshooting KEDA for LLM serving

> Verified against KEDA v2.21.0, 2026-10-11

First capture:

```bash
kubectl describe scaledobject <name> -n <ns>                 # conditions: Ready, Active, Fallback, Paused
kubectl get hpa keda-hpa-<name> -n <ns> -o yaml | head -80
kubectl logs -n keda deploy/keda-operator --tail=100
kubectl logs -n keda deploy/keda-operator-metrics-apiserver --tail=50
kubectl get apiservice v1beta1.external.metrics.k8s.io
```

| Symptom                                          | Cause                                                                    | Fix                                                                                                                       |
| ------------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| ScaledObject not Ready, "target not found"       | Wrong `scaleTargetRef` kind/name/namespace                               | Same namespace as the ScaledObject; set `kind` for StatefulSet or CRD (needs `/scale`).                                   |
| Admission webhook denies: HPA already targets it | Another HPA owns the Deployment                                          | Delete it, or use `scaledobject.keda.sh/transfer-hpa-ownership`. Never run two.                                           |
| `FailedGetExternalMetric`, HPA `<unknown>`       | Metrics API unavailable or a second external-metrics provider            | APIService must be Available; one provider only; check metrics-apiserver logs.                                            |
| Never scales up, ACTIVE False                    | Query returns nothing or 0: wrong label, wrong namespace, series missing | Run the query in Prometheus; `keda_scaler_empty_upstream_responses_total`; set `ignoreNullValues: "false"` to surface it. |
| Stuck at 0 replicas after traffic                | Signal came from the pods that are gone                                  | Use a gateway, HTTP add-on, queue or cron trigger (`references/scale-to-zero.md`).                                        |
| Scales to 0 / min while busy                     | `activationThreshold` above load, or `avg` instead of `sum`              | Lower the activation; `sum(...)` with `AverageValue`.                                                                     |
| Flapping up and down                             | Short stabilization, replicas that are still loading                     | `scaleDown.stabilizationWindowSeconds` 600+, a `scaleUp` policy, `initialCooldownPeriod`.                                 |
| Replicas overshoot then idle                     | New pods take minutes to serve, queue persists                           | Rate-limit scale-up; include in-flight/running in the formula.                                                            |
| Prometheus 401/403                               | Missing or wrong `authModes`/token; audience not approved (2.21)         | `references/authentication.md`.                                                                                           |
| Prometheus TLS error                             | Self-signed cert                                                         | Provide `ca` in the TriggerAuthentication; `unsafeSsl` only for tests.                                                    |
| Condition Fallback True                          | Scaler failed `failureThreshold` times                                   | Fix the source; check the `fallback` behavior chosen.                                                                     |
| Replicas ignore the ScaledObject                 | Paused annotation present, or `minReplicaCount`/`maxReplicaCount` clamps | `kubectl get scaledobject -o jsonpath='{.metadata.annotations}'`.                                                         |
| Pending GPU pods at max                          | Not enough GPUs/nodes                                                    | Cluster autoscaler or lower `maxReplicaCount`; KEDA scales pods, not nodes.                                               |
| Deleted ScaledObject left odd replica count      | Default keeps the last count                                             | Set the Deployment's replicas, or `restoreToOriginalReplicaCount: true` next time.                                        |
| Upgrade broke auth                               | 2.21 enforces token audiences                                            | `references/updating.md`.                                                                                                 |

Enable KEDA's own metrics (chart `prometheus.*`) and watch `keda_scaler_active`, `keda_scaler_metrics_value`,
`keda_scaler_detail_errors_total`.
