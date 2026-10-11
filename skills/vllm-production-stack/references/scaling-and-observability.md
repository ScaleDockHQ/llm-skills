# Scaling and observability

> Verified against production-stack chart vllm-stack 0.1.13 and router (tutorials, helm templates, src/vllm_router), 2026-10-11

## KEDA per model (tutorial 20)

Install KEDA (`helm repo add kedacore https://kedacore.github.io/charts; helm install keda kedacore/keda -n keda
--create-namespace`), a Prometheus reachable from the cluster, then:

```yaml
modelSpec:
  - name: llama
    keda:
      enabled: true
      minReplicaCount: 1
      maxReplicaCount: 5
      pollingInterval: 15
      cooldownPeriod: 360
      triggers:
        - type: prometheus
          metadata:
            serverAddress: http://prometheus-operated.monitoring.svc:9090
            query: vllm:num_requests_waiting
            threshold: "5"
```

The chart renders `<release>-<name>-scaledobject` targeting `<release>-<name>-deployment-vllm`. Other keys:
`idleReplicaCount` (0 for scale-to-zero), `initialCooldownPeriod`, `fallback`, `advanced`. Cold start is a model
load, so keep PVC caching and generous probes. See skill `keda`.

An alternative is HPA through prometheus-adapter (tutorial 10, `assets/hpa-10.yaml`). `routerSpec.autoscaling` scales
the router.

## Observability

```yaml
servingEngineSpec: { serviceMonitor: { enabled: true } }
routerSpec: { serviceMonitor: { enabled: true } }
grafanaDashboards: { enabled: true }
# no Prometheus yet: kube-prometheus-stack: {enabled: true}
```

Router metrics are at `/metrics` (router-side QPS and per-engine stats from `engineScrapeInterval`). Engine metrics
use the `vllm:` prefix (queue, running, KV usage). Key signals: `vllm:num_requests_waiting`,
`vllm:gpu_cache_usage_perc`, time-to-first-token and e2e histograms.

```bash
kubectl get servicemonitor | grep vllm
kubectl port-forward svc/vllm-router-service 30080:80 &
curl -s localhost:30080/metrics | rg -i 'vllm:|router' | head
```

## Sources

- <https://github.com/vllm-project/production-stack/blob/vllm-stack-0.1.13/helm/templates/scaledobject-vllm.yaml>
- <https://github.com/vllm-project/production-stack/blob/vllm-stack-0.1.13/observability/README.md>
