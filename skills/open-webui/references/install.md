# Open WebUI: install and first boot

> Verified against Open WebUI v0.12.0 (docs: getting-started/quick-start, tab-docker, updating), 2026-10-11

## Image tags

Image: `ghcr.io/open-webui/open-webui` (also mirrored as `openwebui/open-webui` on Docker Hub, a subset of tags).

| Tag                    | Meaning                                                                                                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `:main`, `:latest`     | Same rolling image, newest build of the `main` branch. `:latest` is not "newest stable".                                                                               |
| `:vX.Y.Z`, `:X.Y.Z`    | Pinned stable release. Use for team and production.                                                                                                                    |
| `:X.Y`                 | Newest patch of a minor line.                                                                                                                                          |
| `:dev`                 | Nightly pre-release. Use only on a second instance with its own volume.                                                                                                |
| `:slim` / `:main-slim` | About 196 MB instead of 1.62 GB; no bundled local embedding, speech or document stack. Fine for chat to your own endpoints; RAG and voice then need external services. |
| `:cuda`, `:cuda126`    | GPU for Open WebUI's own local models (embeddings, reranking, Whisper); needs `--gpus all`.                                                                            |
| `:ollama`              | Bundles Ollama in the container.                                                                                                                                       |

Chat to an external endpoint does not need `:cuda`; GPU inference lives in your engine.

## docker run

```bash
# secret in a 0600 file, generated once: umask 077; openssl rand -hex 32 > ~/.config/open-webui/secret
docker run -d -p 127.0.0.1:3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  -e WEBUI_SECRET_KEY="$(cat ~/.config/open-webui/secret)" \
  --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:v0.12.0
```

- `-v open-webui:/app/backend/data` holds the database, uploads and settings. Never run without it.
- A fixed `WEBUI_SECRET_KEY` keeps sessions valid across container recreation.
- Container port is `8080`; map any host port to it (`3000:8080` in the docs).
- The first account created becomes admin. Create it immediately, or set auth options before exposing the port.
- Single-user mode (`WEBUI_AUTH=False`) cannot be switched back to multi-account later.

Compose: use `assets/docker-compose.yml` (`docker compose up -d`). Compose names the container `<project>-open-webui-1` unless `container_name` is set.

## pip and uv

Python installs exist (pip, uv, conda, venv). Use Docker for anything shared; with Python you own dependency and Python-version compatibility (check the docs page for the supported Python range before installing) and updates are `pip install -U open-webui` style, outside this skill's pinned-image workflow.

## First boot checks

```bash
docker logs --tail 50 open-webui
curl -fsS -m 5 http://localhost:3000/api/version | jq .
docker exec open-webui sh -c 'curl -fsS -m 5 -o /dev/null -w "%{http_code}\n" http://host.docker.internal:4000/v1/models'  # 200 or 401 means reachable
```

## Exposure

Bind to `127.0.0.1` and put TLS in front (`caddy`, `tailscale`, `cloudflare-tunnel` skills). Behind a proxy set `WEBUI_URL`, `CORS_ALLOW_ORIGIN` and cookie flags, and allow WebSocket upgrade (`troubleshooting.md`). Open WebUI v0.5.0 and later requires WebSocket support.

## Official links

- Quick start (Docker): https://docs.openwebui.com/getting-started/quick-start
- Updating: https://docs.openwebui.com/getting-started/updating
- Releases: https://github.com/open-webui/open-webui/releases
