# Host setup on DGX OS

> Verified against NVIDIA Container Toolkit 1.20.1, DGX Spark User Guide (Software, Container Runtime for Docker), Docker Engine on Ubuntu docs, 2026-10-11

DGX OS is Ubuntu based and ships the NVIDIA driver, CUDA, Docker and the NVIDIA Container Runtime. Verify; do not reinstall.

```bash
nvidia-smi
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

## Docker group

`docker ps` failing with permission denied means the user is not in the `docker` group: `sudo usermod -aG docker $USER && newgrp docker`. Docker group membership is root-equivalent; keep it to the service user. After any `systemctl daemon-reload` on a host using the systemd cgroup driver, containers can lose GPU access (NVIDIA toolkit known issue): check engines still serve and restart the affected model.

## Toolkit (only if missing or on a non-DGX host)

The apt repository route (same commands on arm64 and x86), pinned to the verified version:

```bash
sudo apt-get update && sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg2
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
export V=1.20.1-1
sudo apt-get install -y nvidia-container-toolkit=$V nvidia-container-toolkit-base=$V libnvidia-container-tools=$V libnvidia-container1=$V
sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker
```

## Service user

One dedicated user (for example `llm`) with the same name and UID on every node, so ownership, paths and SSH match: `id llm || sudo useradd -m -u <uid> -s /bin/bash llm; sudo usermod -aG docker llm; ssh node-b 'id llm'`.

## Disk layout

- Weights on the fastest local NVMe with space: `lsblk -o NAME,SIZE,MODEL,MOUNTPOINT`, `df -h`.
- The Hugging Face cache defaults to `~/.cache/huggingface/hub`; move it with `HF_HOME` in the service user's environment and mount the same host path into containers. Use the same path on both nodes.
- Keep space for one extra model and one rollback image.

## Root-owned files from containers

Containers run as root by default, so files they write on bind mounts become root-owned and break later downloads and cleanup. Run with `--user "$(id -u):$(id -g)"` where the image supports it, or inspect and chown afterwards (`sudo find <path> -user root | head` first).

## Image architecture

Images must be arm64 or multi-arch and built for CUDA 13 and `sm_121`; an amd64-only image fails with `exec format error`. Prefer NGC images and tags that state GB10 or CUDA 13 support (`combos/engines-on-spark.md`).

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/nvidia-container-runtime-for-docker.html>
- <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>
