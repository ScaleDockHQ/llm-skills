# Updating

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

```bash
gh release list -R vllm-project/aibrix --limit 5     # or the Releases page
NEW=v0.X.Y
BASE=https://github.com/vllm-project/aibrix/releases/download/$NEW
kubectl apply -f $BASE/aibrix-dependency-$NEW.yaml --server-side
kubectl apply -f $BASE/aibrix-core-crds-$NEW.yaml --server-side     # CRDs first
kubectl apply -f $BASE/aibrix-core-$NEW.yaml
kubectl rollout status deploy -n aibrix-system
```

- Read the release notes and blog post for the target release; v0.x releases arrive every few months and change
  CRDs and annotations.
- Back up custom resources first: `kubectl get podautoscaler,modeladapter,stormservice -A -o yaml > aibrix-backup.yaml`
  (no secrets inside; review before storing).
- Helm: pull the new checkout, `kubectl apply -f dist/chart/crds/`, `helm upgrade aibrix dist/chart -f dist/chart/stable.yaml -n aibrix-system`.
- Re-test one model end to end (completion through the gateway) and the HTTPRoutes after the upgrade.

## Sources

- <https://github.com/vllm-project/aibrix/releases>
