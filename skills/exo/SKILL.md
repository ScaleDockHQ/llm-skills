---
name: exo
description: exo, an open-source cluster runtime that pools Macs and other devices to run models too big for one machine, with MLX, RDMA over Thunderbolt 5 and OpenAI, Claude, Responses and Ollama APIs on :52415. Use to install the app or source build, enable RDMA, create instances (pipeline or tensor), call the API, bench, update, and fix devices that do not discover each other or RDMA that stays off.
license: MIT
compatibility: Commands assume bash, curl and jq. Tier 1 is Apple Silicon macOS (RDMA needs macOS 26.2+ and Thunderbolt 5); Linux runs on CPU only. Installs, Recovery-mode RDMA enablement, network profile changes and exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# exo

A running exo cluster (`exo`, repo exo-explore/exo, Apache-2.0): several devices that discover each other, split one large model across them (pipeline or tensor parallel over MLX) and expose one API and dashboard per node at `http://localhost:52415`.

**Scope:** this one product: install, enable RDMA, place instances, call the API, tune, update, troubleshoot. Choosing between runtimes belongs to `local-llms`; multi-GPU datacenter clusters belong to `multi-node-inference`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secrets.

```bash
command -v exo; uv run exo --help 2>/dev/null | head -5      # from a source checkout
ls /Applications | grep -i '^exo'; brew list --cask 2>/dev/null | grep -x exo
sw_vers -productVersion; system_profiler SPHardwareDataType | grep -E 'Chip|Memory|Model Name'
lsof -nP -iTCP:52415 -sTCP:LISTEN; lsof -nP -iTCP:52414 -sTCP:LISTEN
env | cut -d= -f1 | grep -E '^EXO_' || true                  # names only
curl -fsS http://localhost:52415/node_id
curl -fsS http://localhost:52415/state | jq 'keys'           # topology, nodes, instances
curl -fsS 'http://localhost:52415/models?status=downloaded' | jq -r '.. | .id? // empty' | head
ioreg -rc IOThunderboltPort 2>/dev/null | head -5            # Thunderbolt ports present
gh api repos/exo-explore/exo/releases/latest --jq .tag_name
```

Ask only what discovery cannot show: which devices, how they are cabled (Thunderbolt 5, Ethernet, Wi-Fi), the target model and quantization, macOS versions per device, whether the LAN is trusted.

## Decision flow

1. **Nothing installed, Macs on macOS 26.2+:** macOS app (`brew install --cask exo`). -> `references/install.md`
2. **Older macOS, Linux, or you want to change code:** source build with `uv`. Linux is CPU only. -> `references/install.md`
3. **Two or more Thunderbolt 5 Macs and speed matters:** enable RDMA, cable every device to every other. -> `references/parallelism-multinode.md`
4. **Devices do not see each other:** namespace, version, firewall, ports. -> `references/troubleshooting.md`
5. **Run a model:** preview placements, create an instance, await it, then call `/v1/chat/completions`. -> `references/api.md`
6. **Model not in the list:** add it from Hugging Face. -> `references/models-and-storage.md`
7. **Point clients or a gateway at it:** -> `references/integrations.md`
8. **Slow or out of memory:** -> `references/performance-tuning.md`
9. **New release:** -> `references/updating.md`

## Rules

- **Ask before changing the system.** The app installs a network profile and LaunchDaemon; RDMA is enabled from Recovery with `rdma_ctl enable`; both need approval and an undo path (menu bar -> Advanced -> Uninstall).
- **No API auth is documented.** Anyone who reaches port 52415 can create and delete instances. Keep it on a trusted LAN or put an authenticating proxy in front (see `caddy`, `tailscale`).
- **Match versions.** The discovery namespace defaults to the exo version, so nodes on different versions do not connect. RDMA also needs identical macOS versions, beta numbers included.
- **Wait for instances.** `POST /instance` is asynchronous; call `/instance/await` before inference.
- **Do not enable `trust_remote_code`** for custom models you have not read.
- **One cluster per namespace.** Set `EXO_LIBP2P_NAMESPACE` or `--namespace` to isolate test and production clusters.
- **Secrets never touch output.** Hugging Face tokens stay in `0600` files or the environment.
- **Verify upstream.** Flags, ports and defaults come from the README, `docs/api.md`, `PLATFORMS.md` and `uv run exo --help` of the installed version.

## Workflows

### Install and first model

- [ ] Choose app or source -> `references/install.md`; same version on every device.
- [ ] Open `http://localhost:52415`; confirm every node in `/state`.
- [ ] `GET /instance/previews?model_id=...`, pick a placement without `error`, `POST /instance`, `GET /instance/await`.
- [ ] One streamed chat call; delete the instance when done.

### Enable RDMA

- [ ] Verify TB5 hardware, TB5 cables, full mesh, matching macOS versions -> `references/parallelism-multinode.md`.
- [ ] Recovery mode, `rdma_ctl enable`, reboot every device; from source run `tmp/set_rdma_network_config.sh`.
- [ ] Preview again; an `MlxJaccl` placement should appear; bench against `MlxRing`.

### Update

- [ ] Read releases; update every node to the same version together -> `references/updating.md`.

### Troubleshoot

- [ ] Match the symptom -> `references/troubleshooting.md`.

## Reference index

| File                                  | Read when                                                 |
| ------------------------------------- | --------------------------------------------------------- |
| `references/install.md`               | macOS app, Homebrew, source on macOS and Linux, uninstall |
| `references/serve-config.md`          | CLI flags, ports, environment variables, file locations   |
| `references/parallelism-multinode.md` | Discovery, pipeline vs tensor, Ring vs JACCL, RDMA setup  |
| `references/api.md`                   | Instance lifecycle, inference endpoints, compat APIs      |
| `references/models-and-storage.md`    | Model list, custom HF models, model directories, offline  |
| `references/integrations.md`          | OpenAI clients, Claude Messages, Ollama clients, LiteLLM  |
| `references/performance-tuning.md`    | `exo_bench.py`, placements, memory, fast synch, tracing   |
| `references/updating.md`              | Releases, versions, rolling all nodes, namespace          |
| `references/troubleshooting.md`       | Symptom to cause to fix                                   |

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `mlx`: the single-machine MLX stack exo builds on.
- `local-llms`: choosing a local runtime.
- `nccl-rdma-networking`: RDMA and NCCL on NVIDIA clusters (a different stack).
- `llm-gateway`, `litellm`: put an authenticated gateway in front.
- `tailscale`: reach the cluster remotely.
