# Aphrodite Engine parallelism and multi-node

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

GPUs per replica = tensor parallel x pipeline parallel; data parallelism adds replicas. World size =
TP x PP x DP. Start with one GPU and add parallelism only after measuring a limit.

| Situation                             | Layout                                                                                    |
| ------------------------------------- | ----------------------------------------------------------------------------------------- |
| Model fits one GPU                    | TP=1 (add DP replicas or separate servers for throughput)                                 |
| One NVLink node needs all GPUs        | `--tensor-parallel-size 8`; keep TP inside the fast domain (`nvidia-smi topo -m`)         |
| Needs several nodes                   | TP within a node, PP across nodes (`--tensor-parallel-size 8 --pipeline-parallel-size 2`) |
| Throughput bound, model fits per node | TP within node, `--data-parallel-size N`                                                  |
| MoE                                   | TP plus `--enable-expert-parallel`; `--enable-eplb` only after measuring imbalance        |
| Heads not divisible by TP             | Try PP for the leftover factor                                                            |

## Multi-node without Ray (documented path)

Every node runs the same `aphrodite serve` command, same Sonar commit, same model files and environment, with a
different `--node-rank`; rank 0 runs the API server and the others add `--headless`. `--nnodes` must divide the
world size and each node must expose the same GPU count.

```bash
export HEAD_IP=10.0.0.10 NCCL_SOCKET_IFNAME=eth0 GLOO_SOCKET_IFNAME=eth0
ulimit -n 1048576
# node 0
aphrodite serve MODEL --tensor-parallel-size 8 --pipeline-parallel-size 4 \
  --nnodes 4 --node-rank 0 --master-addr "$HEAD_IP" --master-port 29501 --max-model-len auto
# nodes 1..3: same command with --node-rank N --headless
```

Multi-node launches pick the `mp` executor automatically; the validator accepts `mp`, `uni` or an external
launcher with `--nnodes>1`, and the distributed guide says not to set `ray` for this launch method. The
deployment recipes page still shows `--distributed-executor-backend ray` for two nodes: treat that as stale
and verify on your version. A Ray cluster, if used, is one trust domain (below).

Checks on each node: `python -c 'import torch; print(torch.cuda.device_count())'`, `ip route get "$HEAD_IP"`,
the master port reachable, unique ranks 0..nnodes-1. Hang during init: `NCCL_DEBUG=INFO`, compare commands,
firewall and interface selection. `NCCL_IB_DISABLE=1` and `NCCL_P2P_DISABLE=1` only when those transports are
absent or broken. One failed rank stops its replica: pull the whole replica from traffic and restart all ranks.

`APHRODITE_PP_LAYER_PARTITION=18,20,20,20` overrides the stage split (sum = layer count, same on all nodes).

## Data parallel and external load balancing

`--data-parallel-size N` creates replicas inside one launch; data-parallel supervisor deployments also expose
`/ready` and `/readyz`. An external load balancer mode assigns a DP rank per server process (see the
generated reference for address, port, rank and local-size flags). Prefix cache is per replica: route by prefix
only if you accept uneven load.

## Prefill/decode disaggregation

Via NIXL and other KV connectors; the Rust frontend and render API (`/v1/chat/completions/render`,
`/inference/v1/generate`) support split encode/prefill/decode. Upstream says the code and examples in your
installed commit define the supported configuration. Technique guidance: `disaggregated-serving` skill. Install:
`npx skills add ScaleDockHQ/llms-skills --skill disaggregated-serving`.

## Ray security

A Ray cluster is one trust domain: anyone who can submit tasks runs code on every node. `RayExecutorV2` copies
the driver's environment (including tokens such as `HF_TOKEN` and cloud keys) to workers except denied names. Put
names to exclude in `$APHRODITE_CONFIG_ROOT/ray_non_carry_over_env_vars.json` (default
`~/.config/aphrodite/`), minimize the driver environment, use Ray TLS, never expose the Ray client port or
dashboard, and consider `hidepid=2` on `/proc`.
