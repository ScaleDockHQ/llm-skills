# Updating and migrating

> Verified against Gateway API Inference Extension v1.6.2 and llm-d router v0.11.0 (chart README migration table, release notes), 2026-10-11

## Versions

```bash
gh api repos/kubernetes-sigs/gateway-api-inference-extension/releases/latest --jq .tag_name
gh api repos/llm-d/llm-d-router/releases/latest --jq .tag_name
helm show chart oci://ghcr.io/llm-d/charts/llm-d-router-gateway --version v0
```

## Order

1. Read both release notes. The llm-d-router `RELEASE-NOTES.md` lists breaking config changes (renamed plugins, removed
   flags, changed flow-control defaults).
2. CRDs first (cluster-wide, additive): apply the new GAIE manifest. Check the notes before skipping minors.
3. Gateway implementation to a version that supports your CRD version.
4. `helm upgrade` the router chart with an explicit EPP image tag. The Recreate strategy drops the EPP briefly:
   with `FailOpen` the gateway keeps routing without smart picking; with `FailClose` requests fail meanwhile.
5. Verify EPP Ready (leader), pool status and one request; compare TTFT before and after.
6. Rollback: `helm rollback <release>` and the previous image tag; CRDs stay.

## Migrating from the old gateway-api-inference-extension charts

The `inferencepool` and `standalone` charts of GAIE were replaced by `llm-d-router-gateway` and `llm-d-router-standalone`
(chart value restructure). The new charts fail the install on legacy top-level keys:

| Legacy key              | New key                                                                                |
| ----------------------- | -------------------------------------------------------------------------------------- |
| `inferenceExtension.*`  | `router.epp.*`, `router.monitoring.*`, `router.tracing.*`, `router.latencyPredictor.*` |
| `inferencePool.*`       | `router.modelServers.*`, `router.inferencePool.*`                                      |
| `inferenceObjectives`   | `router.inferenceObjectives`                                                           |
| `experimentalHttpRoute` | `httpRoute` (gateway chart)                                                            |

Other moves: the EPP image is `ghcr.io/llm-d/llm-d-router-endpoint-picker` (was `llm-d-inference-scheduler`); the `-dev`
chart variants are no longer published (use the normal charts with `--version v0`); `InferenceModel` was replaced by
`InferenceObjective` and `InferenceModelRewrite`. The upstream GAIE repo states the EPP packages there will be archived.
