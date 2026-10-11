# Updating llm-d

> Verified against llm-d v0.10.0 (GitHub release notes v0.10.0 and v0.9.0 index, guides/env.sh), 2026-10-11

llm-d ships on a release train; guides are "living docs" tied to a branch (`release-0.10`). Router charts and images
version separately from the `llm-d/llm-d` repo version (v0.10.0 used router and EPP `v0.11.0`).

```bash
gh release list -R llm-d/llm-d -L 6
gh release view v0.10.0 -R llm-d/llm-d --json body --jq .body | less
helm list -n $NAMESPACE
helm get values $GUIDE_NAME -n $NAMESPACE > current-values.yaml
```

## v0.10.0 notes that affect upgrades

- Themes: operational hardening and production readiness for the flagship paths.
- Images: builds from `main` and releases go to `ghcr.io` signed with cosign; PR images go to `quay.io`. The router
  and sidecar images were excluded from the refactor.
- Deprecated: `ghcr.io/llm-d/llm-d-cuda` and `llm-d-aws` (use `docker.io/vllm/vllm-openai` and the AWS Deep Learning
  Containers vLLM image); the `llmd-fs-connector` (now in vLLM's `OffloadingConnector`).
- Migrated: `llm-d-kv-cache` moved into `llm-d/llm-d-router`; `llm-d-workload-variant-autoscaler` renamed
  `llm-d-autoscaling`; WVA guides deprecated.
- Compatible peers are pinned in `guides/env.sh` (Gateway API, Inference Extension, router).

## Upgrade steps

1. Read the release notes between your version and the target; upgrade one release at a time.
2. Check out the new release branch; diff `guides/env.sh` and your values against the new guide.
3. Install any new CRD versions first (Inference Extension manifests, router CRDs for flow control), then
   `helm upgrade` the router chart with the guide's values files and a pinned `--version`.
4. Roll the model servers with a kustomize apply; keep one replica of headroom or use blue-green (gateway mode).
5. Verify: pods Ready, a completion through the router, EPP metrics healthy, prefix hit rate not collapsed.

## Rollback

`helm rollback $GUIDE_NAME <revision> -n $NAMESPACE` for the router; re-apply the previous branch overlays for model
servers. CRD upgrades are not reverted by Helm; restore from saved manifests.

## Sources

- <https://github.com/llm-d/llm-d/releases/tag/v0.10.0>
- <https://github.com/llm-d/llm-d/blob/release-0.10/guides/env.sh>
