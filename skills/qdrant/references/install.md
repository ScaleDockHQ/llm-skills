# Install Qdrant

> Verified against Qdrant v1.19.2 (docs installation, Docker Hub qdrant/qdrant tags), 2026-10-11

Latest release at the check date: v1.19.2 (2026-10-05). Docker Hub tags include `latest`, `v1`, `v1.19`, `v1.19.2` and unprivileged variants (`v1.19.2-unprivileged`, `latest-unprivileged`). Pin `v1.19.2` or a digest, not `latest`.

```bash
install -d -m 700 ~/qdrant && cd ~/qdrant
umask 077; printf 'QDRANT__SERVICE__API_KEY=%s\nQDRANT__SERVICE__READ_ONLY_API_KEY=%s\nQDRANT__TELEMETRY_DISABLED=true\n' \
  "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > qdrant.env

docker run -d --name qdrant --env-file qdrant.env \
  -p 127.0.0.1:6333:6333 -p 127.0.0.1:6334:6334 \
  -v "$PWD/storage:/qdrant/storage" -v "$PWD/snapshots:/qdrant/snapshots" \
  qdrant/qdrant:v1.19.2
```

- Data lives in `/qdrant/storage`; mount it, or the data is lost when the container is removed. Use a local disk or fast SSD; network filesystems are unsupported for storage in upstream's guidance, so verify before relying on one.
- Ports: 6333 REST, 6334 gRPC, 6335 cluster p2p (cluster mode only; do not publish).
- A custom config file mounts at `/qdrant/config/production.yaml`, or any path with `./qdrant --config-path config/custom_config.yaml` (`references/config.md`).
- The `-unprivileged` image runs as a non-root user; the mounted directories must be writable by that UID.
- Env overrides use `QDRANT__<SECTION>__<KEY>`, for example `QDRANT__SERVICE__API_KEY`.

Compose: `templates/docker-compose.yml`. Test:

```bash
set -a; . ~/qdrant/qdrant.env; set +a
curl -fsS -H "api-key: $QDRANT__SERVICE__API_KEY" http://127.0.0.1:6333/ | jq .
```

## Other install paths

Upstream documents a native binary (GitHub releases), Qdrant Cloud, Kubernetes with the Helm chart and a local in-process mode in client libraries. Prefer Docker beside an LLM stack; read the upstream installation page for the others.
