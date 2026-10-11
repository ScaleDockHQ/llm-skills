---
name: mac-cluster-exo-mlx
description: Cluster several Apple Silicon Macs into one inference host with exo or MLX distributed (mlx.launch, JACCL RDMA, ring) over Thunderbolt 5. Use for Mac Studio or MacBook Pro clusters, models larger than one Mac's memory, rdma_ctl enable, mlx.distributed_config, exo dashboard on :52415, tensor vs pipeline parallel, exo or MLX cluster not discovering nodes. Not for one Mac (use apple-silicon, mlx).
license: MIT
compatibility: Two or more Apple Silicon Macs on macOS 14+ (RDMA needs macOS 26.2+ and Thunderbolt 5 on all nodes, identical OS versions), ssh, curl and jq. Recovery-mode RDMA enablement, network changes, installs and exposing the API need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Mac cluster with exo and MLX

Combine two or more Macs so a model that does not fit one machine runs across them, either with exo (automatic discovery, dashboard and API) or with MLX distributed (`mlx.launch` plus `mlx_lm.server`), over Thunderbolt 5 with RDMA when available.

**Scope:** this opinionated combination. Per-Mac setup belongs to `apple-silicon`; MLX serving, conversion and quantization belong to `mlx`; exo as a product will belong to the `exo` skill (not yet published; install later: `npx skills add ScaleDockHQ/llms-skills --skill exo` once it exists); remote access belongs to `tailscale`; gateways belong to `llm-gateway` and `litellm`.

Work through the steps in order. Load a reference only when a step names it. Facts were read from exo-explore/exo (README, docs/api.md, pyproject) and MLX docs on 2026-10-11.

## Discover first

Read-only on every node; nothing here prints secrets.

```bash
sw_vers -productVersion; sysctl -n machdep.cpu.brand_string hw.memsize      # OS and chip must match across nodes for RDMA
rdma_ctl status; ibv_devices                                                # "enabled" and rdma_enN devices when RDMA is on
networksetup -listallhardwareports | grep -A2 -i thunderbolt                # Thunderbolt ports and device names
ifconfig | grep -E '^(en|bridge)[0-9]+:' ; pmset -g batt | head -1           # interfaces; AC power
command -v exo mlx.launch mlx.distributed_config mlx_lm.server; ls /Applications | grep -i exo
curl -s http://localhost:52415/state | jq '.nodes | length' 2>/dev/null     # exo running? node count
```

## Decision flow

1. One Mac is enough for the model? Stay single-node (`apple-silicon`, `mlx`); clustering costs speed unless RDMA tensor parallelism pays off. Size the model against the sum of node memory minus headroom. `references/recipe.md`.
2. Topology: RDMA needs Thunderbolt 5 on every node and a cable between every pair (full mesh); otherwise exo and MLX use the ring over TCP (Thunderbolt IP or Ethernet). `references/networking-and-rdma.md`.
3. Want discovery, a dashboard and OpenAI, Claude Messages, Responses and Ollama-compatible APIs out of the box: exo. `references/exo.md`.
4. Want scripted, explicit control with `mlx_lm.server` (tensor or pipeline parallel): MLX distributed. `references/mlx-distributed.md`.
5. Put a gateway or Tailscale in front before anyone else uses it; keep the API off public networks. `references/recipe.md`.
6. Anything failing: `references/troubleshooting.md`. Updating nodes: `references/updating.md`.

## Rules

- **Ask before changing the system.** `rdma_ctl enable` (Recovery mode, reboot), network service changes, installs, launch agents and exposing a port need approval and an undo path (`rdma_ctl disable`).
- **Match OS versions exactly across nodes** when using RDMA; discovery can fail between versions, even beta numbers (exo README).
- **RDMA needs a full mesh.** Every node cabled to every other node, with Thunderbolt 5 cables; on a Mac Studio do not use the Thunderbolt 5 port next to the Ethernet port (exo README).
- **Do not run the exo API or MLX server on a public interface** without a token or gateway in front; treat the cluster as one trust domain.
- **Memory is the sum, not the limit.** Budget weights + KV + headroom per node; wired-limit rules from `apple-silicon` apply to each node.
- **Custom models can run code.** Keep `trust_remote_code` off unless you trust the model (exo requires it be enabled explicitly).
- **Verify upstream.** exo and MLX move fast; re-read their READMEs and release notes before changing versions.

## Build the stack

- [ ] Each node healthy: `apple-silicon` Discover, same macOS version, AC power -> `references/recipe.md`
- [ ] Cabling and network: mesh, ports, bridge disabled -> `references/networking-and-rdma.md`
- [ ] RDMA enabled in Recovery on each node (optional, macOS 26.2+) -> `references/networking-and-rdma.md`
- [ ] exo path: install, start on every node, open the dashboard -> `references/exo.md`
- [ ] MLX path: `mlx.distributed_config`, hostfile, `mlx.launch ... mlx_lm.server` -> `references/mlx-distributed.md`
- [ ] Verify: all nodes appear in the dashboard or `/state`, a short chat completion succeeds, `memory_pressure` is green on each node, and tokens per second beat the single-node baseline or the model simply fits.

## Reference index

- `references/recipe.md`: end-to-end plan, sizing, choosing exo or MLX, exposure.
- `references/networking-and-rdma.md`: Thunderbolt 5 mesh, `rdma_ctl`, ring versus JACCL, matching OS versions.
- `references/exo.md`: install options, start, environment variables, API, namespaces, uninstall.
- `references/mlx-distributed.md`: `mlx.distributed_config`, hostfiles, `mlx.launch`, distributed `mlx_lm.server`.
- `references/troubleshooting.md`: symptom to fix.
- `references/updating.md`: upgrading exo, MLX and macOS on nodes.

## Companion skills

- `mlx`: MLX serving, convert, quantize, LoRA on one Mac. Install: `npx skills add ScaleDockHQ/llms-skills --skill mlx`.
- `apple-silicon`: per-Mac memory, wired limit, power and thermals. Install: `npx skills add ScaleDockHQ/llms-skills --skill apple-silicon`.
- `tailscale`: private remote access to the cluster head. Install: `npx skills add ScaleDockHQ/llms-skills --skill tailscale`.
- `llm-gateway`: tokens, routing and one endpoint in front. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `litellm`: proxy that can front the exo or MLX endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `exo`: not yet published; install later with `npx skills add ScaleDockHQ/llms-skills --skill exo` once it is listed.
