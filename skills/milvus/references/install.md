# Install Milvus

> Verified against Milvus v3.0.2 (repo scripts/standalone_embed.sh, deployments/docker/standalone, milvus-docs v3.0.x install and prerequisite pages), 2026-10-11

Latest release at the check date: v3.0.2 (2026-09-20). Docker Hub `milvusdb/milvus` also carries `3.0-<date>-<sha>`, `2.6-<date>-<sha>` and `master-...` development tags; use a release tag such as `v3.0.2`.

## Requirements (upstream prerequisites)

CPU: Intel 2nd gen Core or newer, or Apple Silicon; standalone 4 cores or more (cluster 8+). Instruction sets SSE4.2, AVX, AVX2, AVX-512 (vector search and index build need them). RAM: standalone 8 GB minimum, 16 GB recommended; cluster 32 GB minimum. etcd needs a fast local disk (NVMe, over 500 IOPS and under 10 ms p99 fsync per upstream; test with `fio`).

## Option 1: Milvus Lite

```bash
python3 -m venv ~/milvus-lite && . ~/milvus-lite/bin/activate
pip install "pymilvus[milvus-lite]"
python - <<'PY'
from pymilvus import MilvusClient
c = MilvusClient("./milvus_demo.db")   # local file, same API as the server
print(c.list_collections())
PY
```

Supported: Ubuntu 20.04+ (x86_64, arm64), macOS 11+ (Apple Silicon, x86_64). Lite supports many but not all parameters and features (upstream lists limits, for example `rename_collection` is unsupported); use it for prototypes.

## Option 2: single container (`standalone_embed.sh`)

```bash
install -d -m 700 ~/milvus && cd ~/milvus
curl -sfL https://raw.githubusercontent.com/milvus-io/milvus/master/scripts/standalone_embed.sh -o standalone_embed.sh
less standalone_embed.sh            # read before running; it uses sudo docker
bash standalone_embed.sh start
```

Per upstream: container `milvus-standalone` on 19530, embedded etcd on 2379, config via `user.yaml` in the current folder, data in `./volumes/milvus`, WebUI at `http://127.0.0.1:9091/webui/`. The script publishes 19530, 9091 and 2379 on all interfaces, so firewall them or edit the `-p` flags to `127.0.0.1:...` before starting. Put authentication settings in `user.yaml` first (`templates/user.yaml`). Docker Compose is recommended instead if you want Milvus Backup.

## Option 3: Docker Compose (etcd, MinIO, Milvus)

Use `templates/docker-compose.yml`, a hardened version of upstream's `deployments/docker/standalone/docker-compose.yml`: image `milvusdb/milvus:v3.0.2`, `quay.io/coreos/etcd:v3.5.25`, `milvusdb/minio:RELEASE.2024-12-18T13-15-44Z` (tags from upstream at the check date; re-read upstream before reuse), loopback-only ports, MinIO keys from an env file.

```bash
cd ~/milvus
umask 077
k=$(openssl rand -hex 8); s=$(openssl rand -hex 16)
printf 'MINIO_ACCESS_KEY=%s\nMINIO_SECRET_KEY=%s\nMINIO_ACCESS_KEY_ID=%s\nMINIO_SECRET_ACCESS_KEY=%s\n' "$k" "$s" "$k" "$s" > milvus.env; unset k s
# Add user.yaml (templates/user.yaml), then:
docker compose --env-file milvus.env up -d
curl -fsS http://127.0.0.1:9091/healthz
```

The same secret pair is written for MinIO and for Milvus so they match; nothing is echoed.

## Option 4: Kubernetes

Helm and Milvus Operator are the supported paths; read `install-overview` upstream. This skill does not cover them in depth.
