# AnythingLLM: install

> Verified against AnythingLLM v1.17.0 (docs: installation-docker/local-docker, installation-docker/localhost, ollama-connection-troubleshooting; repo docker/HOW_TO_USE_DOCKER.md and server/.env.example), 2026-10-11

Two editions: **Desktop** (macOS, Windows, Linux installers, single user, settings stored by the app) and **Docker** (self-hosted, multi-user capable, settings in a mounted `.env`). This skill focuses on Docker because that is the one that talks to server-side models and gateways.

## Docker run (upstream's documented command)

```bash
export STORAGE_LOCATION=$HOME/anythingllm
mkdir -p "$STORAGE_LOCATION" && touch "$STORAGE_LOCATION/.env" && chmod 600 "$STORAGE_LOCATION/.env"
docker pull mintplexlabs/anythingllm:<pinned-tag>      # check tags on Docker Hub; upstream docs show :latest
docker run -d -p 3001:3001 \
  --cap-add SYS_ADMIN \
  --name anythingllm \
  -v "${STORAGE_LOCATION}:/app/server/storage" \
  -v "${STORAGE_LOCATION}/.env:/app/server/.env" \
  -e STORAGE_DIR="/app/server/storage" \
  mintplexlabs/anythingllm:<pinned-tag>
```

Open `http://localhost:3001`. Without the `-v` storage mount all data is lost when the container is removed. `--cap-add SYS_ADMIN` is part of the upstream command; it is a broad capability, so review whether you accept it (upstream's command includes it, the docs here do not say which feature needs it).

Linux note: the default bridge cannot resolve `host.docker.internal`; either add `--add-host=host.docker.internal:host-gateway` or use `172.17.0.1`.

## Compose equivalent

```yaml
services:
  anythingllm:
    image: mintplexlabs/anythingllm:<pinned-tag>
    container_name: anythingllm
    ports: ["127.0.0.1:3001:3001"] # loopback until auth and TLS are in place
    cap_add: [SYS_ADMIN]
    environment:
      STORAGE_DIR: /app/server/storage
    volumes:
      - ./storage:/app/server/storage
      - ./storage/.env:/app/server/.env
    extra_hosts: ["host.docker.internal:host-gateway"]
    restart: unless-stopped
```

Upstream also ships `docker/docker-compose.yml` and `docker/.env.example` in the repo (build-from-source path, not recommended for casual use).

## Permissions and storage

The container runs as UID/GID 1000. If `STORAGE_LOCATION` lives under a root-owned folder (`/mnt`, `/data`, `/srv`, `/opt`) the container dies with `unable to open database file`. Fix with `sudo chown -R 1000:1000 "$STORAGE_LOCATION"`, then remove and rerun the container. Do not use `chmod -R 777`: it exposes the database, documents and the `.env` with your keys to every local user.

`Illegal instruction (core dumped)` at startup or on first chat means the CPU lacks AVX2, which the default vector database (LanceDB) needs. This shows on old hardware and on Proxmox/QEMU guests whose virtual CPU hides AVX2: pass the host CPU type through, or use another vector database.

## Instance auth

By default there is no password. For anything reachable by others, set `AUTH_TOKEN` (the instance password) and `JWT_SECRET` in the mounted `.env`, or enable multi-user mode in the UI (Settings, Security). Put TLS in front. Do not publish port 3001 directly to the internet.

Environment values you put in `.env` are read at start: after editing it, recreate or restart the container (`docker restart anythingllm`). Settings changed in the UI are written back to that same file.

## Embedding and vector database

Changing the chat model does not change the embedder. Workspaces embed documents with the configured embedder (the built-in one by default); switching embedder later requires re-embedding documents. Keep that decision separate from the LLM provider.

## Updating

```bash
docker stop anythingllm
tar -C "$STORAGE_LOCATION/.." -czf "anythingllm-backup-$(date +%F).tgz" "$(basename "$STORAGE_LOCATION")"   # includes .env, keep 0600
docker pull mintplexlabs/anythingllm:<new-tag>
docker rm anythingllm
# rerun the same docker run command with the new tag (same mounts)
docker logs -f anythingllm
```

Read the release notes (docs changelogs list v1.17.0 and earlier). Desktop: update from the app or re-download the installer; Desktop data lives in the app's own storage folder (see docs "Where is my data stored?").

## Verify

```bash
curl -fsS -m 5 http://localhost:3001/api/ping
docker logs anythingllm 2>&1 | tail -20
```
