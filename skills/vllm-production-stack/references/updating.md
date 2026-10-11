# Updating

> Verified against production-stack chart vllm-stack 0.1.13 and router (tutorials, helm templates, src/vllm_router), 2026-10-11

```bash
helm repo update
helm search repo vllm/vllm-stack --versions | head
helm get values vllm -o yaml > current.yaml        # may contain tokens; keep 0600, never commit
helm diff upgrade vllm vllm/vllm-stack --version <new> -f current.yaml   # helm-diff plugin, optional
helm upgrade vllm vllm/vllm-stack --version <new> -f current.yaml
kubectl rollout status deploy/vllm-deployment-router
helm history vllm; helm rollback vllm <rev>
```

- Read the release notes at <https://github.com/vllm-project/production-stack/releases> first. The chart tag is
  `vllm-stack-<x.y.z>`; set router and engine image tags explicitly.
- Engine image bumps recreate pods and reload the model; use `strategy: {type: Recreate}` on a single-GPU node or
  surge capacity elsewhere.
- Re-test routing logic and LMCache after bumping engine images; LMCache and vLLM versions are coupled.
- `values.schema.json` can reject keys that the newer router supports; upgrade chart and router together.

## Sources

- <https://github.com/vllm-project/production-stack/releases>
