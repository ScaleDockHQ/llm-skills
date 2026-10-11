# Updating KServe

> Verified against KServe v0.21.0 (website upgrade guide, release notes v0.21.0, RELEASES.md), 2026-10-11

## Policy

KServe supports the latest minor releases; RELEASES.md says N-2 and older are unsupported, and patch releases carry
only security fixes. Read the release notes between your version and the target:

```bash
gh release list -R kserve/kserve -L 8
gh release view v0.21.0 -R kserve/kserve
kubectl get deploy -n kserve -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

## What changed that bites upgrades

- **v0.17.0 chart restructure.** CRD charts are separate (`kserve-crd`, `kserve-llmisvc-crd`,
  `kserve-localmodel-crd`), resource charts were renamed (`kserve` -> `kserve-resources`), and
  `kserve-runtime-configs` owns ClusterServingRuntimes and LLMInferenceServiceConfigs. A plain `helm upgrade`
  does not work from before v0.17; follow the migration steps in the upgrade guide (annotation changes on existing
  CRDs and runtimes first, so Helm does not delete them). Helm 3.8+ required.
- **LLMInferenceService API.** v0.21.0 samples moved from `v1alpha1` to `v1alpha2` (storage version). Re-apply
  manifests with `v1alpha2`.
- **v0.21.0 changes** (release notes): CRD management restructured for independent installation; direct KEDA scaling
  for `LLMInferenceService`; canary traffic splitting for RawDeployment HTTPRoutes; WVA discovery via annotations
  instead of the VariantAutoscaling CRD path; tokenizer sidecar replaced by a vLLM render deployment; scheduler
  flags migrated to the metrics-data-source plugin; DRA `resourceClaims` for ServingRuntime.

## Upgrade steps

1. Snapshot: `kubectl get inferenceservice,llminferenceservice,llminferenceserviceconfig,clusterservingruntime -A -o yaml > kserve-backup.yaml`
   (contains no secrets by itself, but review before sharing).
2. Read the release notes and the upgrade guide for every step between versions. Upgrade one minor at a time.
3. Upgrade CRDs before controllers (separate CRD charts or `kubectl apply --server-side -f kserve-crds.yaml` from the release).
4. Upgrade controllers; wait for `kserve-controller-manager` and `llmisvc-controller-manager`.
5. Check `ClusterServingRuntime` and `LLMInferenceServiceConfig` presets updated; custom copies do not auto-update.
6. Watch a canary workload roll (controller upgrades can restart InferenceService predictors that use changed images).
7. Verify: `READY=True` everywhere and one completion through the gateway.

## Rollback

Helm: `helm rollback <release> -n kserve`. Kustomize: re-apply the previous tag. CRDs do not downgrade cleanly when new
fields were used; restore from the backup if needed.

## Sources

- <https://kserve.github.io/website/docs/install/upgrade-guide>
- <https://github.com/kserve/kserve/releases/tag/v0.21.0>
- <https://github.com/kserve/kserve/blob/v0.21.0/RELEASES.md>
