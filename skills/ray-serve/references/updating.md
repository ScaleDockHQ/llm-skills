# Updating Ray Serve LLM and KubeRay

> Verified against Ray 2.59.0 and KubeRay v1.7.1 (GitHub releases, docs `serve/production-guide/kubernetes`), 2026-10-11

## Find the target versions

```bash
gh api repos/ray-project/ray/releases/latest --jq .tag_name
gh api repos/ray-project/kuberay/releases/latest --jq .tag_name
curl -s "https://hub.docker.com/v2/repositories/rayproject/ray-llm/tags?page_size=25&name=<ver>" | jq -r '.results[].name'
```

Read the Ray release notes (Serve and LLM sections) and the KubeRay release notes. The vLLM version changes with
each Ray release, so read vLLM's breaking changes too (skill `vllm`, `references/updating.md`).

## Procedure

1. Record the current image tag, `rayVersion`, operator chart version and `serve config` output.
2. Test the new image on a non-production cluster: same config, a real load test, compare TTFT and throughput.
3. Upgrade the **operator first** (`helm upgrade kuberay-operator kuberay/kuberay-operator --version <v> -n kuberay-system`),
   read the release notes for CRD changes and follow their CRD upgrade steps (Helm does not upgrade the CRDs
   of an existing release by default).
4. Change image and `rayVersion` in the RayService. This is a cluster-level update: a new cluster is created and
   traffic switches when it is ready; budget GPUs for both (`references/kubernetes-kuberay.md`).
5. Watch `kubectl describe rayservice` until the pending cluster is active; run smoke tests; the old cluster is
   removed after `rayClusterDeletionDelaySeconds`.
6. Rollback: revert the image and `rayVersion` in the manifest and re-apply; keep the old image in the registry.

## Config-only changes

Edit `serveConfigV2` (replica counts, autoscaling, `max_ongoing_requests`): applied in place. Changing `LLMConfig`
engine arguments restarts replicas.
