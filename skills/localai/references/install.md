# Install LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

Upstream recommends containers. All paths below listen on port 8080.

## Containers

Image names exist on Docker Hub (`docker.io/localai/localai`) and Quay (`quay.io/go-skynet/local-ai`). Tags are `latest-<variant>`, `master-<variant>` (development) and `<version>-<variant>`. Pin a version in production.

| Hardware       | Tag suffix                                       | Run flags                                                     |
| -------------- | ------------------------------------------------ | ------------------------------------------------------------- |
| CPU            | (none), for example `latest`                     | none                                                          |
| NVIDIA CUDA 13 | `-gpu-nvidia-cuda-13`                            | `--gpus all` (Podman: `--device nvidia.com/gpu=all`)          |
| NVIDIA CUDA 12 | `-gpu-nvidia-cuda-12`                            | same                                                          |
| AMD ROCm       | `-gpu-hipblas`                                   | `--device=/dev/kfd --device=/dev/dri --group-add=video`       |
| Intel          | `-gpu-intel`                                     | `/dev/dri` passthrough (Podman: `--device gpu.intel.com/all`) |
| Vulkan         | `-gpu-vulkan`                                    | `/dev/dri` passthrough                                        |
| Jetson (L4T)   | `-nvidia-l4t-arm64`, `-nvidia-l4t-arm64-cuda-13` | `--runtime nvidia --gpus all`                                 |

```bash
docker run -d --name local-ai -p 127.0.0.1:8080:8080 --gpus all \
  -v localai-models:/models -v localai-backends:/backends \
  -v localai-config:/configuration -v localai-data:/data \
  localai/localai:latest-gpu-nvidia-cuda-12
```

Podman may not resolve short names; use `docker.io/localai/localai:...`.

Volumes: `/models`, `/backends`, `/configuration` (`api_keys.json`, `external_backends.json`, `runtime_settings.json`) and `/data` (agent state, jobs, collections). Anything else is lost when the container is recreated. The container paths must be exactly these four.

NVIDIA with CDI (toolkit 1.14+) is the upstream recommendation when `--gpus all` fails; include the `utility` capability so free-VRAM reporting works. Verify GPU access first:

```bash
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

Compose: `templates/docker-compose.yml`.

## Linux binary

Release assets (v4.11.0): `local-ai-v4.11.0-linux-amd64`, `local-ai-v4.11.0-linux-arm64`, `LocalAI-v4.11.0-checksums.txt`, `local-ai-launcher-linux.tar.xz`.

```bash
V=v4.11.0
curl -fLO "https://github.com/mudler/LocalAI/releases/download/$V/local-ai-$V-linux-amd64"
curl -fLO "https://github.com/mudler/LocalAI/releases/download/$V/LocalAI-$V-checksums.txt"
sha256sum -c --ignore-missing "LocalAI-$V-checksums.txt"
chmod +x "local-ai-$V-linux-amd64" && sudo install "local-ai-$V-linux-amd64" /usr/local/bin/local-ai
local-ai run qwen3-4b     # downloads from the gallery and serves
```

The binary starts empty: backends and models are fetched on demand. Run as a dedicated user with `LOCALAI_MODELS_PATH` and `LOCALAI_BACKENDS_PATH` on a large disk. A service unit is in `templates/local-ai.service`.

## macOS

Release asset `LocalAI.dmg` is a menu-bar launcher that downloads and manages the server, offers update checks and opens the web UI. On Apple silicon `local-ai-v4.11.0-darwin-arm64` is the bare binary.

## Kubernetes

Upstream gives example manifests (`LocalAI-examples`, `kubernetes/deployment.yaml` and `deployment-nvidia.yaml`) and a Helm chart:

```bash
helm repo add go-skynet https://go-skynet.github.io/helm-charts/
helm repo update
helm show values go-skynet/local-ai > values.yaml     # edit image tag, PVCs, resources
helm install local-ai go-skynet/local-ai -f values.yaml
```

Use PVCs for the four paths and a Secret for the API key.

## From source

`getting-started/build` upstream. After upgrading Go, rebuild the affected backend as well; rebuilding only `local-ai` does not update installed backend executables.

## Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/readyz
curl -s http://127.0.0.1:8080/version
local-ai backends list | head
```
