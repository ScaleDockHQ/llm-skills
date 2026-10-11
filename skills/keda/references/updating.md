# Updating KEDA

> Verified against KEDA v2.21.0, 2026-10-11

## Before

```bash
helm list -n keda
kubectl get scaledobject,scaledjob -A                   # note READY/ACTIVE now
kubectl get triggerauthentication,clustertriggerauthentication -A
helm get values keda -n keda > /tmp/keda-values.yaml    # review for secrets before sharing
```

Read the release notes for every version you skip (github.com/kedacore/keda/releases). Upgrade the operator, metrics
server and webhooks together (one chart version). KEDA is tested against specific Kubernetes versions; 2.21 covers
1.34-1.36.

## 2.20 to 2.21 breaking changes

1. **Service account token audiences** (CVE-2026-77524): affects `boundServiceAccountToken` and Vault Kubernetes auth
   only. Migrate before upgrading (`references/authentication.md`); complete reviewed Helm values required.
2. **Temporal scaler**: `buildId`, `selectAllActive`, `selectUnversioned` removed.
3. **Azure Pipelines scaler**: `scaleOnInFlight` defaults true.

None touches Prometheus-with-secret or queue triggers. The Liiklus scaler is deprecated.

## Upgrade

```bash
helm repo update
helm upgrade keda kedacore/keda -n keda --version 2.21.0 -f /tmp/keda-values.yaml     # needs approval
kubectl rollout status deploy -n keda --timeout=5m
kubectl get scaledobject -A                                                            # READY True again
```

## Roll back

`helm rollback keda <revision> -n keda`. CRDs are chart-managed; a rollback across a CRD change may need the
matching `keda-<version>-crds.yaml`. During an upgrade window, pause scaling with the
`autoscaling.keda.sh/paused: "true"` annotation on critical ScaledObjects.

## HTTP add-on

Upgrade its chart (`kedacore/keda-add-ons-http`) separately; it is beta and may change CRDs or env variables between
minors (v0.16.0 deprecated the `KEDA_HTTP_PROXY_TLS_*` variables in favor of `KEDA_HTTP_TLS_*`).
