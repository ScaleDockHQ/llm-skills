# DCGM Exporter: install

> Verified against dcgm-exporter 4.8.4 (DCGM 4.6.1), NVIDIA DCGM docs "Install DCGM Exporter" last updated 2026-09-10, 2026-10-11

One exporter per GPU node. Choose by lifecycle owner: package (systemd), container, Helm, or GPU Operator.

## Requirements

- NVIDIA GPU, driver and a DCGM combination in NVIDIA's support matrix; Linux only.
- Containers: NVIDIA Container Toolkit. Prometheus must reach port 9400.
- Run the DCGM version paired with the exporter release. Image tags encode `<dcgm-version>-<exporter-version>-<variant>` (for example `4.6.1-4.8.4-distroless`); `dcgm-exporter --version` prints the pair. Mismatches may work but are unsupported.
- With a separate host engine, the exporter's DCGM client library must be at least the host engine version.

## Container (recommended for a single host)

```bash
docker run -d --name dcgm-exporter --restart unless-stopped \
  --gpus all --cap-add SYS_ADMIN \
  -p 127.0.0.1:9400:9400 \
  --mount type=bind,src=$PWD/llm-counters.csv,dst=/etc/dcgm-exporter/llm-counters.csv,readonly \
  nvcr.io/nvidia/k8s/dcgm-exporter:4.6.1-4.8.4-distroless \
  --collectors /etc/dcgm-exporter/llm-counters.csv
curl -fsS http://127.0.0.1:9400/metrics | grep -c '^DCGM_'
```

`--cap-add SYS_ADMIN` enables `DCGM_FI_PROF_*`; without it the profiling fields are absent. Review the privilege before adopting it on a shared host. Use `assets/docker-compose.yaml` for the Compose form. For Prometheus on another host publish on the private address instead of loopback, never `0.0.0.0` without `--web-config-file`.

## Package and systemd

```bash
sudo apt-get install datacenter-gpu-manager-exporter        # or: sudo dnf install ...
sudo systemctl enable --now nvidia-dcgm nvidia-dcgm-exporter
systemctl cat nvidia-dcgm-exporter.service                  # effective unit incl. overrides
```

The package installs `/usr/bin/dcgm-exporter`, `/etc/dcgm-exporter/default-counters.csv` and the unit. Never edit the unit under `/lib`; use a drop-in (`sudo systemctl edit nvidia-dcgm-exporter.service`, see `assets/nvidia-dcgm-exporter-collectors.conf`). The empty `ExecStart=` clears the vendor command. After a package upgrade, compare your replaced `ExecStart` with the new vendor command; the drop-in does not inherit changes. Requires the CUDA network repository and DCGM installed first.

## Separate DCGM host engine

Omit `-r` for the embedded engine. To use `nv-hostengine` elsewhere: `-r host:port`, `tcp://host:port`, `unix:///path`, `vsock://cid:port`, `[::1]:5555` (URI forms need DCGM 4.5+). Mount sockets into containers. Trade-off: one shared engine for several tools versus one more service to run.

## Helm and GPU Operator

```bash
helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts && helm repo update
helm install dcgm-exporter gpu-helm-charts/dcgm-exporter -n gpu-monitoring --create-namespace \
  --set serviceMonitor.enabled=false        # drop this line if the Prometheus Operator CRDs exist
kubectl rollout status daemonset/dcgm-exporter -n gpu-monitoring
```

Helm `customMetrics` replaces the shipped CSV rather than extending it. With the NVIDIA GPU Operator the exporter is Operator-owned: configure fields in its metrics ConfigMap and never edit its DaemonSet (`kubectl get pods -A -l app=nvidia-dcgm-exporter`).

## Undo

`docker rm -f dcgm-exporter`; `sudo systemctl disable --now nvidia-dcgm-exporter`; `helm uninstall dcgm-exporter -n gpu-monitoring`.

## Official links

- Install: https://docs.nvidia.com/datacenter/dcgm/latest/installation/install-dcgm-exporter.html
- Repository: https://github.com/NVIDIA/dcgm-exporter
- Helm chart docs: https://github.com/NVIDIA/dcgm-exporter/blob/main/deployment/README.md
