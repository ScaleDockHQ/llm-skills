# Troubleshooting KServe

> Verified against KServe v0.21.0 (website status reference and install docs; repo samples), 2026-10-11

Start with the objects, then the controller:

```bash
kubectl describe llminferenceservice <n> -n <ns> | sed -n '/Conditions/,$p'
kubectl get llminferenceservice <n> -n <ns> -o json | jq '.status.conditions[]|select(.status!="True")'
kubectl logs -n kserve deploy/llmisvc-controller-manager --tail=100
kubectl logs -n kserve deploy/kserve-controller-manager --tail=100
kubectl get events -n <ns> --sort-by=.lastTimestamp | tail -20
```

| Symptom                                                  | Likely cause                                                                                    | Fix                                                                                    |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `PresetsCombined` false, nothing created                 | A `baseRefs` config missing or unresolvable (looked up in the service namespace, then `kserve`) | Create the config or fix the name; `kubectl get llminferenceserviceconfig -A`          |
| `RouterReady` false, `GatewaysReady` false               | No `Gateway`/`GatewayClass`, Envoy Gateway not installed, no external LB                        | Install the llmisvc dependencies; `kubectl get gatewayclass,gateway -A`                |
| `InferencePoolReady` or `SchedulerWorkloadReady` false   | Inference Extension CRDs missing or version mismatch; EPP image pull                            | Check `kubectl get crd                                                                 | grep inference.networking`; EPP logs |
| `WorkloadsReady` false, pod Pending                      | No GPU node, wrong resource name, taint without toleration                                      | `kubectl describe pod`; add `nvidia.com/gpu` limit and tolerations                     |
| Pod Running but not Ready for minutes                    | Large model download or load; liveness probe kills it too early                                 | Raise `initialDelaySeconds` and `failureThreshold`; watch the storage-initializer logs |
| Storage initializer fails, 401 or 403 from Hugging Face  | Missing or wrong `HF_TOKEN` Secret, no `ClusterStorageContainer` for `hf://`                    | Create the Secret and `hf-hub` container (see `inferenceservice-huggingface.md`)       |
| Multi-node `InferenceService` rejected                   | `TENSOR_PARALLEL_SIZE` env set, autoscaler not `none`, storage not `pvc://` or PVC not RWX      | Use `workerSpec.*`, `autoscalerClass: none`, RWX PVC                                   |
| `ScaledObject` not created                               | Not Standard mode, KEDA missing, wrong `autoscalerClass`                                        | Set deployment mode Standard; install KEDA                                             |
| LLM autoscaling never scales                             | WVA not installed or Prometheus not scraping WVA; HPA path lacks Adapter rule                   | Check WVA pods, `wva_desired_replicas` in Prometheus, the actuator object              |
| Canary shifts traffic poorly after raising weight from 0 | Dark deploy warmed no backend                                                                   | Start at `weight: 1`                                                                   |
| 404 through the gateway                                  | Wrong path; llmisvc path includes `/<ns>/<name>/` before `/v1/...`                              | Use `status.url`                                                                       |
| Webhook errors on apply (`x509`, `no endpoints`)         | cert-manager not ready or the controller is down                                                | `kubectl get pods -n cert-manager`; restart the controller after certs issue           |
| `helm install` of a chart version fails: not found       | Chart tag not published (no plain `v0.21.0` chart at check time)                                | List tags (see `install.md`) or use the release manifests                              |
| Apply with an old `apiVersion` converts oddly            | `v1alpha1` is served but `v1alpha2` is stored                                                   | Move manifests to `v1alpha2`                                                           |

Collect for an upstream issue: KServe version, `kubectl get llminferenceservice -o yaml` (strip secrets), controller
logs, gateway and EPP pod logs.

## Sources

- <https://kserve.github.io/website/docs/model-serving/generative-inference/llmisvc/llmisvc-status>
- <https://kserve.github.io/website/docs/install/dependencies>
