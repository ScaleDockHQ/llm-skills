---
name: keda
description: Autoscale LLM serving pods on Kubernetes with KEDA (ScaledObject, TriggerAuthentication, Prometheus scaler on vllm:num_requests_waiting, KV-cache or DCGM metrics, queue scalers, scale to zero, HTTP add-on). Use for keda, ScaledObject, scale vLLM replicas on queue depth, scale to zero, activationThreshold, cooldownPeriod, keda-hpa, ScalingActive false or flapping. Not for Ray Serve replicas (ray-serve), the KServe wiring (vllm-kserve-keda) or routing (llm-d).
license: MIT
compatibility: Kubernetes 1.34-1.36 for KEDA 2.21 with Prometheus scraping the model servers, kubectl, helm, bash, curl and jq. Helm installs, CRDs, ScaledObjects and scale changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# KEDA for LLM autoscaling

Gets the replicas of an LLM Deployment (vLLM, SGLang, TGI, any OpenAI-compatible server) to follow real load: queue depth,
KV-cache pressure, a work queue or GPU metrics, with a controlled scale-down and, if you accept the cold start, scale to
zero. Verified against KEDA v2.21.0 and HTTP add-on v0.16.0 (2026-10-11).

**Scope:** KEDA used for LLM autoscaling only: Prometheus, metrics-api and queue triggers on model servers and workers. Not
a general KEDA manual (other scalers: keda.sh/docs/2.21/scalers). KServe plus KEDA wiring is `vllm-kserve-keda`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens or Secret values.

```bash
kubectl get crd | grep -E 'keda.sh'                     # scaledobjects, triggerauthentications, ...
kubectl get deploy,pods -n keda 2>/dev/null             # operator, metrics-apiserver, admission webhooks
helm list -A | grep -i keda                             # chart and app version
kubectl get apiservice v1beta1.external.metrics.k8s.io  # must be Available; only ONE provider per cluster
kubectl get scaledobject,hpa -A                         # existing scaling objects (HPA name keda-hpa-<so>)
kubectl get svc -A | grep -Ei 'prometheus|thanos|victoria'
kubectl get deploy -A -o wide | grep -Ei 'vllm|sglang|tgi|llm'
kubectl get pods -A -o name | grep -i dcgm              # GPU metrics source (skill dcgm-exporter)
```

## Decision flow

1. **No KEDA** -> `references/install.md` (Helm, pinned, Prometheus metrics on). Metrics-server conflict check first.
2. **Pick the signal** (`references/llm-triggers.md`): sum of `vllm:num_requests_waiting` is the primary trigger;
   `vllm:kv_cache_usage_perc` as a guard; queue length for batch or async workers (RabbitMQ, Redis, SQS, NATS).
   Never GPU utilization alone: it sits near 100% at any load.
3. **Write the ScaledObject** from `templates/scaledobject-vllm.yaml`. Keep `minReplicaCount` at 1 or more unless
   you accept a cold start (`references/scale-to-zero.md`).
4. **Prometheus needs auth or is multi-tenant** -> `references/authentication.md` and `templates/triggerauth-prometheus.yaml`.
5. **Scale to zero wanted** -> the vLLM series vanish with the last pod, so the query must come from something that
   survives (gateway, router or HTTP add-on): `references/scale-to-zero.md`.
6. **Tune** `pollingInterval`, HPA `behavior`, `fallback`, thresholds against a load test:
   `references/scaledobject-tuning.md`.
7. **Already on a stack?** KServe -> `vllm-kserve-keda`. Ray Serve -> do not add KEDA to its workers
   (`references/combos/ray-serve.md`). llm-d or GAIE -> `references/combos/gaie-epp.md`.
8. **Upgrade** -> `references/updating.md`. **Broken** -> `references/troubleshooting.md`.

## Quick start (vLLM Deployment, Prometheus scraping it)

```bash
helm repo add kedacore https://kedacore.github.io/charts && helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace --version 2.21.0   # needs approval
kubectl apply -f templates/scaledobject-vllm.yaml        # after setting names, namespace, serverAddress
kubectl get scaledobject -n <ns>                         # READY True, ACTIVE True when there is load
kubectl get hpa -n <ns>                                  # keda-hpa-<name> shows the metric and target
```

## Rules

- **Ask before changing the system.** Helm releases, CRDs, ScaledObjects, annotations and scale changes need approval and an
  undo path: `kubectl delete scaledobject` leaves replicas where they are unless
  `advanced.restoreToOriginalReplicaCount: true`.
- **Secrets never touch output.** Prometheus tokens and queue URLs go in Secrets, referenced by `TriggerAuthentication`
  (`secretTargetRef`); create Secrets from `0600` files.
- **One scaler per workload.** Never put a second HPA, or an autoscaling operator such as Ray Serve's, on the same target.
- **Do not hardcode prices or GPU counts in advice.** Thresholds come from a load test on the real model and GPU.
- **Verify upstream.** Fields and defaults come from the 2.21 docs, checked on the writing date.

## Facts that surprise people (KEDA 2.21.0)

- A ScaledObject creates an HPA named `keda-hpa-<name>`. KEDA owns 0<->1 (activation); the HPA owns 1<->N.
- Defaults: `pollingInterval` 30 s, `cooldownPeriod` 300 s (applies only to scaling to 0), `minReplicaCount` 0,
  `maxReplicaCount` 100, `initialCooldownPeriod` 0, trigger `metricType` `AverageValue`.
- Prometheus trigger `ignoreNullValues` defaults to `true`: an empty result means 0, so a vanished series scales
  down quietly instead of erroring. Set `"false"` to surface a lost scrape target.
- With `AverageValue` the metric is divided by current replicas, so `threshold` is per-replica: replicas =
  ceil(sum / threshold). Query a `sum(...)`, not an `avg(...)`.
- Activation is strict "greater than": `activationThreshold: 0` activates at 1 or more. If `minReplicaCount >= 1` the
  activation value is ignored.
- If `minReplicaCount > 0` and none of `idleReplicaCount`, `useCachedMetrics` or `scalingModifiers` is set, KEDA stops
  polling and the HPA drives everything.
- 2.21 enforces explicit audiences for bound service account tokens (CVE-2026-77524): read
  `references/authentication.md` before upgrading from 2.20 if you use `boundServiceAccountToken` or Vault Kubernetes auth.
- KEDA 2.21 is tested with Kubernetes 1.34-1.36. The HTTP add-on is beta (v0.16.0, `InterceptorRoute`).

## Workflows

### Autoscale a vLLM Deployment on queue depth

- [ ] Confirm Prometheus scrapes the pods: query `vllm:num_requests_waiting` in Prometheus; note labels.
- [ ] Install KEDA if missing (`references/install.md`).
- [ ] Adapt `templates/scaledobject-vllm.yaml` (label selector, threshold, min/max, HPA behavior).
- [ ] Load test; watch `kubectl get hpa -w` and the pending/Ready replica timeline; tune
      (`references/scaledobject-tuning.md`).

### Add a safety net and a scale-down policy

- [ ] `fallback` with `behavior: currentReplicasIfHigher`, a stabilization window of 10+ minutes for scale-down.
- [ ] Alert on `keda_scaler_detail_errors_total` and on the HPA at `maxReplicas` (`references/scaledobject-tuning.md`).

### Debug a stuck ScaledObject

- [ ] `kubectl describe scaledobject`, KEDA operator logs, then `references/troubleshooting.md`.

## Reference index

- `references/install.md`: Helm, pinned versions, metrics on, CRDs, uninstall, compatibility.
- `references/llm-triggers.md`: vLLM, DCGM, queue and metrics-api triggers with queries and thresholds.
- `references/scaledobject-tuning.md`: spec fields that matter, HPA behavior, fallback, pause, caching, modifiers.
- `references/scale-to-zero.md`: activation, cold start, what survives zero pods, HTTP add-on.
- `references/authentication.md`: `TriggerAuthentication`, secrets, bearer/basic/TLS, 2.21 token audiences.
- `references/updating.md`: KEDA upgrades and breaking changes 2.20 -> 2.21.
- `references/troubleshooting.md`: symptom to cause to fix.
- `references/combos/vllm-pods.md`, `references/combos/gpu-operator-dcgm.md`, `references/combos/gaie-epp.md`,
  `references/combos/ray-serve.md`: stack-specific wiring.
- `templates/`: `scaledobject-vllm.yaml`, `scaledobject-queue-worker.yaml`, `triggerauth-prometheus.yaml`, `values-keda.yaml`.

## Companion skills

- `vllm-kserve-keda`: KServe InferenceService with KEDA. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm-kserve-keda`.
- `vllm`: engine flags and metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `nvidia-gpu-operator`: GPU nodes and DCGM. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-gpu-operator`.
- `dcgm-exporter`: GPU metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill dcgm-exporter`.
- `gateway-api-inference-extension`: model-aware routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill gateway-api-inference-extension`.
- `ray-serve`: Ray's own autoscaling. Install: `npx skills add ScaleDockHQ/llms-skills --skill ray-serve`.
- `prometheus-grafana-llm`: scraping and dashboards. Install: `npx skills add ScaleDockHQ/llms-skills --skill prometheus-grafana-llm`.
