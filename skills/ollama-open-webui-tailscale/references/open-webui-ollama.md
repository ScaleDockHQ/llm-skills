# Open WebUI with Ollama

> Verified against Open WebUI v0.12.0 (docs: getting-started/quick-start, troubleshooting/connection-error, reference/env-configuration; backend/start.sh at main) and Ollama v0.40.3 (FAQ, local bind default), 2026-10-11

Open WebUI is a Python backend with a web front end, shipped as a container image. Its backend, not your browser, calls Ollama, so `localhost` in its settings means the container (or the host, with host networking).

## Image tags

| Tag                    | Meaning                                                                           |
| ---------------------- | --------------------------------------------------------------------------------- |
| `:main`, `:latest`     | Same rolling image, newest `main` build. `:latest` is not the newest release      |
| `:vX.Y.Z`, `:X.Y.Z`    | One pinned stable release; also `-cuda`, `-ollama`, `-slim` variants              |
| `:slim` (`:main-slim`) | About 196 MB download instead of 1.62 GB; no bundled local speech or embeddings   |
| `:ollama`              | Bundles Ollama in the container; not used in this stack (Ollama runs on the host) |
| `:dev`                 | Nightly pre-release                                                               |

Registry: `ghcr.io/open-webui/open-webui`. Docker Hub mirrors a subset as `openwebui/open-webui`. Pin the version tag from the releases page (`https://github.com/open-webui/open-webui/releases`); v0.12.0 was the latest release on 2026-10-11. The standard image bundles local Whisper and embeddings. Slim leaves them out and needs external services for voice and RAG, so pick slim only for plain chat.

## Linux: host networking, loopback only

Docs recommend `--network=host` when the container cannot reach Ollama on the host. With host networking the port flags are ignored, the app listens on `PORT` (default 8080), and `HOST` (default `0.0.0.0` in `backend/start.sh`) controls the bind address. The SSO docs name `HOST=127.0.0.1` as the way to listen on loopback only.

```bash
( umask 077; mkdir -p ~/.config/open-webui; [ -s ~/.config/open-webui/env ] || \
  printf 'WEBUI_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > ~/.config/open-webui/env )

docker run -d --name open-webui --restart always --network=host \
  -v open-webui:/app/backend/data \
  --env-file ~/.config/open-webui/env \
  -e HOST=127.0.0.1 -e PORT=8080 \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  ghcr.io/open-webui/open-webui:v<X.Y.Z>
```

Replace `v<X.Y.Z>` with a real release tag. The `open-webui` volume holds chats, users and settings: never run without it.

`OLLAMA_BASE_URL` defaults to `http://localhost:11434`. Per the docs, a Docker image with no value set looks at `http://host.docker.internal:11434` first, which does not exist under host networking, so set it explicitly. The setting is persistent config: after first start the Admin Panel values (Settings > Connections) win over the environment unless `ENABLE_PERSISTENT_CONFIG=false`.

Check:

```bash
curl -fsS http://127.0.0.1:8080/health          # app is up (start.sh polls this path)
ss -ltn | grep -E ':(8080|11434)\b'             # both on 127.0.0.1
docker logs --since 5m open-webui | tail -20
```

In the UI (Admin Panel > Settings > Connections) the Ollama entry shows a verified connection and the model list fills from Ollama.

## Bridge networking, macOS and Windows

Without host networking, the container needs a route to Ollama:

- Compose and `docker run` use `--add-host=host.docker.internal:host-gateway`; set `OLLAMA_BASE_URL=http://host.docker.internal:11434`.
- A loopback-bound Ollama on Linux is not reachable from the Docker bridge. The Open WebUI troubleshooting page says to set `OLLAMA_HOST=0.0.0.0`, which makes Ollama listen on every interface with no authentication. Do that only behind a host firewall that allows the Docker bridge subnet and nothing else; prefer host networking on Linux.
- Ollama's Host-header check is skipped when it is bound to a non-loopback address (`ollama` skill, `lan-and-tunnels.md`).
- Docker Desktop on macOS and Windows: whether `host.docker.internal` reaches an Ollama bound to loopback was not verified for this skill. Test with `docker exec open-webui curl -fsS http://host.docker.internal:11434/api/version` (the image has curl; if not, use the UI connection check) and fall back to the pip install path (`open-webui serve --host 127.0.0.1`, documented in the quick start) if it fails.
- Podman: `OLLAMA_BASE_URL=http://host.containers.internal:11434`.

## Settings that matter here

| Variable                   | Default                  | Why                                                          |
| -------------------------- | ------------------------ | ------------------------------------------------------------ |
| `WEBUI_SECRET_KEY`         | none                     | Fixed value keeps sessions across container recreation       |
| `ENABLE_SIGNUP`            | `True`                   | Set `False` once the admin exists                            |
| `WEBUI_AUTH`               | `True`                   | Never set `False` on a shared host                           |
| `OLLAMA_BASE_URL`          | `http://localhost:11434` | Where the backend finds Ollama                               |
| `ENABLE_OPENAI_API`        | `True`                   | Needed if you add LiteLLM as an OpenAI-compatible connection |
| `WEBUI_URL`                | unset                    | Set to the Serve URL before using OAuth/SSO                  |
| `CORS_ALLOW_ORIGIN`        | `*`                      | Semicolon-separated origins; tighten to the Serve URL        |
| `ENABLE_WEBSOCKET_SUPPORT` | `True`                   | WebSockets are required by the app; proxies must pass them   |

Add LiteLLM later as an OpenAI connection (`http://127.0.0.1:4000/v1` plus a virtual key entered in the Admin Panel, not in shell history), and optionally disable the direct Ollama connection so users only see gateway models.
