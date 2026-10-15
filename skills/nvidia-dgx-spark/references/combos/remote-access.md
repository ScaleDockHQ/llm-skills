# Remote access to a DGX Spark

> Verified against DGX Spark User Guide (NVIDIA Sync, DGX Dashboard) and dgx-spark-playbooks (tailscale, connect-to-your-spark), 2026-10-11

| Need                                                | Option                                                                                                                                                                |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Terminal and apps from a laptop on the same network | NVIDIA Sync (Windows, macOS, Ubuntu): device discovery, hostname or IP, imported SSH aliases; manages SSH, port forwarding and tunnels; launches IDEs and custom apps |
| Access away from home                               | NVIDIA Sync's Tailscale connections, or the Tailscale playbook (private tailnet with stable IP and hostname, SSH from anywhere, no port forwarding)                   |
| DGX Dashboard                                       | `ssh -L 11000:localhost:11000 <user>@<ip or spark-xxxx.local>`, then `http://localhost:11000`; NVIDIA Sync opens it for you                                           |
| A model API for other machines                      | Do not publish engine ports: put a gateway on loopback behind Tailscale Serve or Cloudflare Tunnel (`self-hosted-llms`, `tailscale`, `cloudflare-tunnel`)             |

Rules: SSH key authentication, keep the dashboard and engine ports on loopback, no `0.0.0.0` binds without a token, and prefer the same private network for both cluster nodes (inter-node traffic uses the QSFP link, not the management network).

Install: `npx skills add ScaleDockHQ/llm-skills --skill tailscale`.

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/nvidia-sync.html>
- <https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/tailscale>
