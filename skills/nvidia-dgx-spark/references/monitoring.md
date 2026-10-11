# Monitoring a DGX Spark

> Verified against DGX Spark User Guide (DGX Dashboard, known issues) and sparkDash v2.32.0, 2026-10-11

- **Memory:** `free -h`, `grep -E 'MemAvailable|SwapFree' /proc/meminfo`. `nvidia-smi` prints `Memory-Usage: Not Supported` (expected) but lists per-process GPU memory: `nvidia-smi --query-compute-apps=pid,used_memory --format=csv`.
- **DGX Dashboard:** built in; shows operating metrics, applies updates, renames the device, opens JupyterLab. Locally: Show Apps, DGX Dashboard. Remotely: NVIDIA Sync, or `ssh -L 11000:localhost:11000 <user>@<ip or spark-xxxx.local>` then `http://localhost:11000`. JupyterLab ports per user are in `/opt/nvidia/dgx-dashboard-service/jupyterlab_ports.yaml`. The November 2025 release made its memory readout follow CUDA unified-memory guidance.
- **Network:** `ibdev2netdev`, `ip -s link show <iface>`.
- **Fleet view:** [sparkDash](https://github.com/MiaAI-Lab/sparkDash) is a privileged Docker container (latest release v2.32.0, 2026-10-10) reading sysfs, `/proc` and `nvidia-smi`, polling other units over SSH, and probing engine ports. Keep `BIND_HOST=127.0.0.1`, set `SPARKDASH_TOKEN` from a `0600` file and `SPARKDASH_ALLOW_OPEN_REMOTE=0`, pin a release tag, reach it through an SSH tunnel or `tailscale serve`. Setup details and pitfalls (probe ports, SSH keys inside the container, power controls) live in the `self-hosted-llms` skill until a sparkdash skill exists.
- **Metrics pipeline:** Prometheus, Grafana, DCGM exporter and LiteLLM spend belong to `llm-observability`. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/dgx-dashboard.html>
- <https://github.com/MiaAI-Lab/sparkDash>
