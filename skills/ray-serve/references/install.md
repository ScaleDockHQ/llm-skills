# Install: Ray, ray-llm images, KubeRay

> Verified against Ray 2.59.0 and KubeRay v1.7.1 (docs `serve/llm/quick-start`, `serve/llm/troubleshooting`, KubeRay Helm chart), 2026-10-11

## Local or VM (pip)

```bash
python3 -m venv ~/venvs/ray && . ~/venvs/ray/bin/activate
pip install "ray[llm]==2.59.0"      # pulls vLLM matching this Ray release (verify with pip show vllm)
ray --version; pip show vllm | sed -n 1,2p
```

- GPU: most models need at least one; set `accelerator_type` to what the cluster has.
- Gated models: put `HF_TOKEN` in the deployment `runtime_env` (read it from the environment) or a Kubernetes Secret.
- Faster Hugging Face downloads: `pip install hf_transfer` and set `HF_HUB_ENABLE_HF_TRANSFER=1` in `runtime_env.env_vars`.
- Start a cluster by hand: `ray start --head --dashboard-host=127.0.0.1`, then on workers
  `ray start --address=<head-ip>:6379`. `serve run` and `serve deploy` start or use the cluster. Do not bind
  the dashboard to a public interface.

## Images

Docker Hub `rayproject/ray-llm`. Tags seen for this release: `2.59.0-py312-cu130` and
`2.59.0-py312-cu130-aarch64` (plus `-extra-` variants and hash-suffixed builds). The KubeRay sample at v1.7.1
still pins `rayproject/ray-llm:2.52.0-py311-cu128`: it is an example, not a recommendation. NIXL is preinstalled in
these images; with pip installs run `uv pip install nixl` for prefill/decode.

```bash
curl -s "https://hub.docker.com/v2/repositories/rayproject/ray-llm/tags?page_size=25&name=2.59" | jq -r '.results[].name'
```

## Ray to vLLM compatibility

Each Ray release is tested with one vLLM version. Docs table (as read): 2.58.0 -> 0.26.0, 2.57.0 -> 0.25.1,
2.56.0 -> 0.22.0, 2.55.0 -> 0.18.0, 2.54.0 -> 0.15.0, 2.53.0 -> 0.12.0, nightly -> 0.27.0. There was no 2.59.0
row, so read the version inside your image. Replacing vLLM with your own build: the docs have a "custom vLLM"
and a "vLLM compatibility" user guide; unsupported combinations break.

## KubeRay operator

```bash
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ && helm repo update
helm search repo kuberay/kuberay-operator --versions | head -5     # read-only
# After approval:
helm install kuberay-operator kuberay/kuberay-operator --version 1.7.1 -n kuberay-system --create-namespace
kubectl -n kuberay-system get pods; kubectl get crd | grep ray.io
```

The chart version equals the KubeRay release (1.7.1). Match `rayVersion` in the cluster spec to the image.
Uninstall: `helm uninstall kuberay-operator -n kuberay-system` (CRDs stay; delete them only if no Ray resources remain).

## Sources

https://docs.ray.io/en/latest/serve/llm/quick-start.html, https://github.com/ray-project/kuberay
