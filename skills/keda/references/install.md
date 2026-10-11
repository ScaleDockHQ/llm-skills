# Install KEDA

> Verified against KEDA v2.21.0, 2026-10-11

KEDA is three Deployments in one namespace: the operator (activation and HPA management), the metrics API server
(serves `external.metrics.k8s.io` to the HPA) and the admission webhooks. KEDA 2.21 is tested with Kubernetes
1.34-1.36.

## Check before installing

```bash
kubectl version
kubectl get apiservice | grep external.metrics        # an existing provider (another KEDA, Prometheus adapter)?
kubectl get crd | grep keda.sh
helm list -A | grep -i keda
```

The cluster has one `v1beta1.external.metrics.k8s.io` APIService. A second provider (for example prometheus-adapter
exposing external metrics) conflicts; pick one or remove the other with approval.

## Helm (recommended)

```bash
helm repo add kedacore https://kedacore.github.io/charts && helm repo update
helm search repo kedacore/keda -l | head -5           # chart 2.21.0 has appVersion 2.21.0
helm install keda kedacore/keda --namespace keda --create-namespace --version 2.21.0 -f templates/values-keda.yaml
kubectl get pods -n keda                              # operator, metrics-apiserver, admission-webhooks Ready
kubectl get apiservice v1beta1.external.metrics.k8s.io   # AVAILABLE True
```

Chart facts (read from the chart values on the verification date):

- The chart manages the CRDs. If KEDA was once installed from YAML, Helm upgrades can fail on CRD ownership; see the
  upgrade note in the KEDA deploy docs, or apply `keda-2.21.0-crds.yaml` from the GitHub release separately.
- `prometheus.metricServer.enabled`, `prometheus.operator.enabled` and `prometheus.webhooks.enabled` default to false; each
  has a `serviceMonitor.enabled` switch for the Prometheus Operator. Turn them on to get `keda_*` metrics
  (`references/troubleshooting.md`).
- Run two operator replicas for HA; only one is active, the other is standby. The metrics server can run several replicas
  (the docs recommend `--enable-aggregator-routing=true` on the kube-apiserver for load balancing).

## Other install paths

OperatorHub (OLM, OpenShift) and plain YAML exist: keda.sh/docs/2.21/deploy. Use the same version everywhere.

## Uninstall

```bash
kubectl get scaledobject,scaledjob -A                 # remove or pause these first
helm uninstall keda --namespace keda
```

Stuck finalizers on a ScaledObject: `kubectl patch scaledobject <name> -p '{"metadata":{"finalizers":null}}' --type=merge`.
Deleting a ScaledObject leaves the target at its current replica count unless
`advanced.restoreToOriginalReplicaCount: true`.
