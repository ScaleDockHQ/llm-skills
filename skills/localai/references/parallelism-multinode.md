# Multi-GPU and multi-node LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

Pick the smallest mechanism that fits. Most single hosts need only the first row.

| Need                                | Mechanism                                                           |
| ----------------------------------- | ------------------------------------------------------------------- |
| Several GPUs in one host            | `llama-cpp` options `devices` and `split_mode`                      |
| Spread one model over hosts         | llama.cpp RPC workers (`local-ai worker llama-cpp-rpc`)             |
| Ad-hoc cluster, no central services | P2P: `--p2p`, optionally `--federated` (experimental)               |
| Production scale-out                | Distributed mode: PostgreSQL + NATS + stateless frontends + workers |
| Apple silicon cluster               | MLX distributed (`features/mlx-distributed` upstream)               |

## Multi-GPU in one host

Per model, in the YAML `options` for `llama-cpp`:

```yaml
options:
  - devices:CUDA0,CUDA1 # names from llama-server --list-devices; unlisted devices are excluded
  - split_mode:layer # none | layer (default) | row | tensor (experimental)
  - fit_params:true # default true; shrinks context or layers to fit memory
  - fit_target:1024 # MiB margin per device
```

Use `CUDA_VISIBLE_DEVICES` on the container to pin a whole LocalAI instance. For the Python engines use their own parallel settings (`engine_args` for vLLM and SGLang; see `vllm` and `sglang` skills).

## llama.cpp RPC workers (model sharding)

LocalAI Worker mode is llama.cpp only.

```bash
# on each worker host (memory limit optional)
local-ai worker llama-cpp-rpc --llama-cpp-args="-H <listen_address> -p <port> -m <memory>"
# on the server
LLAMACPP_GRPC_SERVERS="host1:50052,host2:50052" local-ai run
```

The same list can be set per model with the option `grpc_servers:host1:port,host2:port`. RPC traffic is unauthenticated and unencrypted; keep it on a private network.

## P2P and federation (experimental)

```bash
local-ai run --p2p                  # prints or exposes a shared token (UI: Operate -> Swarm -> P2P)
TOKEN=<token> local-ai worker p2p-llama-cpp-rpc --llama-cpp-args="-m <memory>"   # shard one model
local-ai run --p2p --federated      # whole requests routed to one node
TOKEN=<token> local-ai federated    # load balancer in front of the swarm
```

Anyone with the token can join the swarm; treat it as a secret. Upstream labels this tech-preview.

## Distributed mode (production)

Stateless frontends share state in PostgreSQL and coordinate over NATS. Workers are generic: they self-register and the SmartRouter installs the needed backend on demand, using idle-first placement and LRU eviction of idle models.

Prerequisites: PostgreSQL (pgvector recommended for RAG), a NATS server, and a network where all can reach each other. Auth must be on.

Frontend:

```bash
LOCALAI_DISTRIBUTED=true LOCALAI_AUTH=true \
LOCALAI_AUTH_DATABASE_URL=postgres://user:pass@db:5432/localai \   # secret: from a 0600 env file
LOCALAI_NATS_URL=nats://nats:4222 LOCALAI_REGISTRATION_TOKEN=<token> \
local-ai run
```

Worker:

```bash
local-ai worker --register-to http://frontend:8080 --registration-token <token> --nats-url nats://nats:4222
```

Key settings (frontend unless noted):

- `LOCALAI_AUTO_APPROVE_NODES=true` skips admin approval of new nodes; otherwise approve in the UI.
- `LOCALAI_DISTRIBUTED_SHARED_MODELS=true` only when every node mounts the same models dir at the same path; the default stages files over HTTP or S3.
- `LOCALAI_DISTRIBUTED_REQUIRE_AUTH=true` requires NATS JWT credentials and a registration token. NATS is anonymous by default, so any client reaching port 4222 can publish control subjects; use JWT auth (`LOCALAI_NATS_ACCOUNT_SEED`) and TLS (`LOCALAI_NATS_TLS_CA`, `_CERT`, `_KEY`) in production.
- `LOCALAI_NATS_BACKEND_INSTALL_TIMEOUT` (15m) for slow image pulls; `LOCALAI_MODEL_LOAD_WAIT` (60s) is how long a request waits for a cold load before a 503 with `Retry-After`.
- Worker: `--vram-budget` (for example `80%` or `12GB`) caps placement, `--advertise-addr` is what the frontend dials, and `--grpc-max-port` bounds backend ports.
- Health: workers expose `/healthz` (liveness) and `/readyz` (registered, NATS live, backends alive).
- Roll out upgrades frontends first, then workers.
- Do not share a database with the vector store.

Docker Compose example: `docker-compose.distributed.yaml` in the upstream repo. vLLM multi-node data parallel and ds4 layer-split are covered in the upstream distributed-mode page.

Failure shapes: 503 `no available nodes` or `no healthy nodes match selector` means every node is full or a `node_selector` excludes all of them.
