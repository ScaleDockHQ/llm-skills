# Install Chroma

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

Latest GitHub release at the check date: 1.5.9 (2026-05-05). Docker Hub `chromadb/chroma` has a `1.5.9` tag; the `latest` tag there was last pushed on 2026-05-05 as well, but pin the version. Images also exist on `ghcr.io/chroma-core/chroma`. Tags with `.devN` are nightly builds; do not use them.

Upstream quick start (data in `/data`, port 8000):

```bash
docker run -v ./chroma-data:/data -p 8000:8000 chromadb/chroma
```

That publishes on all interfaces with no auth. Use the compose template instead:

```bash
install -d -m 700 ~/chroma && cd ~/chroma
cp <skill>/templates/{docker-compose.yml,Caddyfile} .
# Generate a proxy token without echoing it
umask 077; printf 'CHROMA_PROXY_TOKEN=%s\n' "$(openssl rand -hex 32)" > chroma.env
docker compose --env-file chroma.env up -d
curl -fsS http://127.0.0.1:8001/api/v2/heartbeat -H "Authorization: Bearer $(grep ^CHROMA_PROXY_TOKEN chroma.env | cut -d= -f2)" | jq .
```

Chroma itself listens on 8000 inside the Docker network only; Caddy listens on loopback 8001 and checks the bearer token.

## Config file

Configuration is YAML mounted at `/config.yaml`, or env vars (`CHROMA_PERSIST_PATH`, `CHROMA_PORT`, `CHROMA_LISTEN_ADDRESS`, `CHROMA_ALLOW_RESET`, `CHROMA_MAX_PAYLOAD_SIZE_BYTES` default 40 MiB, `CHROMA_CORS_ALLOW_ORIGINS`). The full sample is `rust/frontend/sample_configs/single_node_full.yaml` in the repo.

## Without Docker

`pip install chromadb` then `chroma run --path ./chroma-data`. For a client-only install, use the `chromadb-client` package.

## Health

The upstream compose healthcheck is `curl -f http://localhost:8000/api/v2/heartbeat`.
