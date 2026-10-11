# Recipe: two or more Macs as one LLM host

> Verified against exo v1.0.71 (README, docs/api.md), mlx 0.32.3 distributed docs, mlx-lm 0.32.0 server, 2026-10-11

## 1. Decide it is worth it

- Clustering is for models that do not fit one Mac, or for tensor-parallel speedups when RDMA is available. exo's README claims speedups from tensor parallelism of up to 1.8x on 2 devices and 3.2x on 4 devices; treat that as vendor-reported and measure.
- Over plain TCP (ring over Ethernet or Thunderbolt IP) expect the interconnect to cost speed; the gain is capacity.
- A single Mac with a lot of unified memory is usually simpler: `apple-silicon` and `mlx`.

## 2. Size it

```text
sum over nodes of (unified memory - headroom for macOS, apps and the wired limit)
  >= weights + KV cache (context x concurrent sequences) + per-node runtime overhead
```

Use the per-node budget and wired-limit rules from the `apple-silicon` skill on every node. Pipeline parallelism splits layers across nodes (low bandwidth need); tensor parallelism splits each layer (needs RDMA-class latency).

## 3. Prepare each node

```bash
sw_vers -productVersion            # identical on every node for RDMA
pmset -g batt | head -1            # AC power; keep nodes awake (apple-silicon operating.md)
sysctl iogpu.wired_limit_mb        # per-node GPU wired limit; do not raise without need
ssh <peer> true                    # key-based ssh between nodes (needed by mlx.launch)
```

## 4. Network

Follow `networking-and-rdma.md`: cabling (full mesh for RDMA), disable Thunderbolt Bridge for RDMA ports, optionally enable RDMA from Recovery.

## 5. Pick the runtime

| Need                                                      | Use                                                |
| --------------------------------------------------------- | -------------------------------------------------- |
| Zero-config discovery, dashboard, several API dialects    | exo (`exo.md`)                                     |
| Scripted launch, explicit hostfile, plain `mlx_lm.server` | MLX distributed (`mlx-distributed.md`)             |
| Both on the same nodes                                    | Not at once: both want the same memory and network |

## 6. Expose it safely

- exo serves its API and dashboard at `http://localhost:52415` on each device; check what actually listens with `lsof -nP -iTCP:52415 -sTCP:LISTEN` and keep it on the private cluster network.
- Put `litellm` or `llm-gateway` in front for tokens and routing, and Tailscale (`tailscale`) for remote access. Do not forward the port to the internet.
- exo API calls are plain HTTP without an authentication scheme in the documentation read; do not assume a token protects them.

## 7. Verify

```bash
curl -s http://localhost:52415/state | jq '.nodes | length'                    # exo: number of nodes seen
curl -s http://localhost:52415/models?status=downloaded | jq .                 # exo: downloaded models (shape per docs/api.md)
for h in node1 node2; do ssh $h 'memory_pressure | tail -1'; done              # pressure green on every node
```

Then run one fixed prompt and record prefill and decode tokens per second against the single-node baseline (or note that it simply fits now).
