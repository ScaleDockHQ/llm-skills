# Kubernetes with KubeRay

> Verified against KubeRay v1.7.1 and Ray 2.59.0 (docs `serve/production-guide/kubernetes`, `fault-tolerance`, KubeRay CRD types and sample `ray-service.llm-serve.yaml`), 2026-10-11

## Objects

- **RayService** (`ray.io/v1`): `spec.serveConfigV2` (the Serve config as a YAML string) plus `spec.rayClusterConfig`
  (a RayCluster spec). The operator creates the cluster, deploys the app through the Serve REST API and creates
  `<name>-serve-svc` (port 8000) for traffic.
- **RayCluster**: head group plus worker groups (`workerGroupSpecs[]`: `groupName`, `replicas`, `minReplicas`,
  `maxReplicas`, `numOfHosts`, `rayStartParams`, pod `template`).
- RayService spec extras: `excludeHeadPodFromServeSvc`, `suspend`, `rayClusterDeletionDelaySeconds` (default 60),
  `serveService`, `upgradeStrategy`.

## Install, apply, check

```bash
kubectl get crd | grep ray.io; kubectl -n kuberay-system get pods         # operator up
kubectl create secret generic hf-token --from-file=hf_token=./hf-token.txt   # file mode 0600
kubectl apply -f rayservice-llm.yaml                                      # after approval
kubectl get rayservice,raycluster,pods
kubectl describe rayservice ray-serve-llm | sed -n '/Status:/,$p'
kubectl port-forward svc/ray-serve-llm-serve-svc 8000:8000
kubectl port-forward svc/ray-serve-llm-head-svc 8265:8265                 # dashboard, loopback only
```

`kubectl describe` shows application and deployment statuses (`HEALTHY`, `UPDATING`, ...) and the event
`The Serve applicaton is now running and healthy.` (spelling as in upstream).

## LLM-specific settings (from the upstream sample)

- Head: `rayStartParams: {num-cpus: "0", num-gpus: "0"}` so no replica lands there; expose ports 8000 serve,
  8080 metrics, 6379 gcs, 8265 dashboard, 10001 client.
- GPU worker: `nvidia.com/gpu` limit equal to request, enough for TP x PP of one replica, large CPU and memory,
  `HUGGING_FACE_HUB_TOKEN` from a Secret via `secretKeyRef`.
- Image `rayproject/ray-llm:<ray>-py312-cu130` and `rayVersion` set to the same Ray version.
- Add a memory-backed `/dev/shm` volume if you hit shared-memory errors; also node selectors/tolerations for GPU nodes.
- Weights: init container or mirrored bucket; a ReadWriteMany volume shared by workers avoids repeated downloads.
- Node-level scaling: `enableInTreeAutoscaling: true` (and optional `autoscalerOptions`) with worker group
  `minReplicas`/`maxReplicas`. Serve replica autoscaling needs it to get new GPU nodes.

## Updates

- Only `serveConfigV2` changed: in-place lightweight update (scale, autoscaling params, `user_config`) on the same cluster.
- RayCluster spec changed (image, resources): `upgradeStrategy.type`: `NewCluster` (default behavior: build a new cluster, switch the
  Service when ready, delete the old after `rayClusterDeletionDelaySeconds`), `None` (no new cluster), or
  `NewClusterWithIncrementalUpgrade` (Gateway API traffic shifting with `maxSurgePercent`, `stepSizePercent`,
  `intervalSeconds`, `gatewayClassName`; behind the `RayServiceIncrementalUpgrade` feature gate). Zero-downtime
  `NewCluster` needs GPU capacity for two clusters at once, which is expensive for LLMs: plan spare GPUs.

## Head fault tolerance (GCS)

By default the head is a single point of failure (the RayService controller restarts the cluster). To keep serving
while the head recovers, enable GCS fault tolerance. KubeRay v1.7.1 `RayClusterSpec.gcsFaultToleranceOptions`
supports a Redis backend (`redisAddress`, `redisUsername`/`redisPassword` as credentials, `externalStorageNamespace`)
and an embedded RocksDB backend (`storage`, with a bring-your-own PVC via `claimName`). The older documented path uses
the annotations `ray.io/ft-enabled: "true"` and `ray.io/external-storage-namespace` plus `RAY_REDIS_ADDRESS` on the head.
Use a highly available Redis; the one-node Redis in the docs is for development only. Read the KubeRay GCS FT docs for
your version before enabling: the backend is immutable on an existing cluster.

## Scheduling and quotas

GPU Pods need the NVIDIA device plugin (skill `nvidia-gpu-operator`). For gang or queue admission use Kueue or a
batch scheduler supported by KubeRay; not covered here.

## Sources

https://docs.ray.io/en/latest/serve/production-guide/kubernetes.html, https://github.com/ray-project/kuberay
