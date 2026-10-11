# Updating, compatibility and rollback

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 compatibility page, release notes and RELEASES.md, 2026-10-11

## Compatibility matrix

| Agent Router                                                                                                                                                                                 | Envoy Gateway                 | Kubernetes | Gateway API | Inference Extension | Status      |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ---------- | ----------- | ------------------- | ----------- |
| main                                                                                                                                                                                         | v1.9.2+ (Envoy Proxy v1.39.x) | v1.32+     | v1.6.1      | v1.6.2              | Development |
| v1.2.x                                                                                                                                                                                       | v1.9.2+ (Envoy Proxy v1.39.x) | v1.32+     | v1.6.1      | v1.6.2              | Supported   |
| v1.1.x                                                                                                                                                                                       | v1.8.1+ (Envoy Proxy v1.38.x) | v1.32+     | v1.5.x      | v1.6.0              | Supported   |
| v1.0.x                                                                                                                                                                                       | v1.8.1+ (Envoy Proxy v1.38.x) | v1.32+     | v1.5.x      | v1.0.2              | Supported   |
| "Compatible" means these combinations were tested together. Re-read the matrix at the docs page before any upgrade; it changes with each release. Support policy: `RELEASES.md` in the repo. |

## What changed in v1.2.0 (2026-10-07)

- Project renamed Agent Router. Nothing you deploy is renamed: API group, CRDs, charts, images and `aigw` stay.
- Requires Envoy Gateway v1.9.2+ and Gateway API v1.6.1. Upgrade those first.
- Breaking: the chart no longer defaults the MCP session encryption seed to `default-insecure-seed`; it generates a random one in a Secret and reuses it across upgrades. Read the release notes before upgrading an MCP deployment that has live sessions.
- Breaking: MCP OAuth tokens must carry an `iss` equal to `securityPolicy.oauth.issuer` (trailing slash included), else 401.
- Breaking: CEL rules referencing `auth.jwt` need `securityPolicy.oauth` on the MCPRoute.
- Additions worth knowing: `AWSOpenAI` and `TypeSafe` schemas, `headerValueFilters`, `excludeFromModelsEndpoint`, `gen_ai.backend` metric attribute, `GatewayConfig.extProc.metadataForwardingNamespaces`, MCP `prefixMode`, `promptSelector`, `injectionPolicy`, `mergeType`, Inference Extension v1.6 support, readiness after cache sync.
- Deprecation: read `cache_write_tokens`, not `cache_creation_input_tokens`, in translated responses.

Read the full notes each time: `gh release view <tag> -R theagentrouter/agent-router --json body --jq .body`.

## Upgrade procedure

```bash
# 0. Record state (undo path)
helm list -A | grep -E 'aieg|gateway-helm'
helm get values aieg -n envoy-ai-gateway-system > /tmp/aieg-values.yaml     # no secrets expected; review before sharing
kubectl get aigatewayroute,aiservicebackend,backendsecuritypolicy,mcproute,quotapolicy,gatewayconfig -A -o yaml > /tmp/aigw-resources-backup.yaml  # may reference Secret names, not values

# 1. Envoy Gateway to a version the matrix allows (keep the project values files and addons)
helm upgrade eg oci://docker.io/envoyproxy/gateway-helm --version <v> -n envoy-gateway-system \
  -f <base-values> [-f <addons>...]
kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# 2. CRDs, then application
helm upgrade aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm --version <NEW> -n envoy-ai-gateway-system
helm upgrade aieg     oci://docker.io/envoyproxy/ai-gateway-helm      --version <NEW> -n envoy-ai-gateway-system
kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available

# 3. Smoke test: models list, one chat call per backend, one streamed call, one MCP initialize
```

Use `--reuse-values` only after checking new chart values; new keys may otherwise be missing. Pin chart versions; do not use `v0.0.0-latest`.

### v1alpha1 to v1beta1

`AIGatewayRoute`, `AIServiceBackend`, `BackendSecurityPolicy`, `GatewayConfig` and `MCPRoute` serve both versions; existing v1alpha1 objects keep working. Storage migration is manual: re-apply the objects with `apiVersion: aigateway.envoyproxy.io/v1beta1`, or use the Kubernetes storage version migration tooling. `QuotaPolicy` stays v1alpha1. New manifests should use v1beta1.

## Rollback

```bash
helm history aieg -n envoy-ai-gateway-system
helm rollback aieg <rev> -n envoy-ai-gateway-system
helm rollback aieg-crd <rev> -n envoy-ai-gateway-system   # only if CRDs changed incompatibly; CRD removal deletes resources
```

Roll back the Envoy Gateway release only within what the matrix supports for the Agent Router version still installed.

## Standalone `aigw`

Binaries come from the release page; Docker uses `envoyproxy/ai-gateway-cli:<tag>` (v1.2.0 exists; `latest` and `v1.3.0-dev.*` track main). `aigw version` prints the build. Config files follow the CRD API, so re-check them against `examples/aigw/` after upgrades.

## Version checks (read-only)

```bash
gh api repos/theagentrouter/agent-router/releases/latest --jq '.tag_name+" "+.published_at'
helm show chart oci://docker.io/envoyproxy/ai-gateway-helm --version v1.2.0 | grep -E '^(version|appVersion)'
kubectl get deploy -n envoy-ai-gateway-system ai-gateway-controller -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```
