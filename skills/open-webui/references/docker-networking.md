# Open WebUI: Docker networking to host, LAN and container endpoints

> Verified against Open WebUI v0.12.0 (docs: troubleshooting/connection-error, tab-docker/ManualDocker, DockerCompose), 2026-10-11

Open WebUI's backend makes the model requests, not your browser (except Direct Connections). So every endpoint URL must work from inside the container.

## Rules of thumb

| Where the endpoint runs                     | Use in the connection URL                                                                                                   |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Docker host (Docker Desktop, macOS/Windows) | `http://host.docker.internal:PORT/v1`                                                                                       |
| Docker host on Linux                        | Same, after `--add-host=host.docker.internal:host-gateway` (`extra_hosts: [host.docker.internal:host-gateway]` in Compose)  |
| Another container on the same network       | `http://<service-or-container-name>:PORT/v1` (shared Compose project or user-defined network)                               |
| Another machine on the LAN or tailnet       | `http://<ip-or-name>:PORT/v1`                                                                                               |
| Podman on macOS                             | `http://host.containers.internal:PORT` (Podman 5+ uses pasta; older needs `--network slirp4netns:allow_host_loopback=true`) |

`localhost` and `127.0.0.1` inside the container are the container itself and fail with `Connect call failed ('127.0.0.1', ...)`.

## The engine must listen beyond loopback

The host-side service must accept connections from the Docker bridge, not only `127.0.0.1`:

- vLLM and llama.cpp: `--host 0.0.0.0` (or the bridge IP) plus `--api-key` when anything else can reach the port.
- Ollama: `OLLAMA_HOST=0.0.0.0` in the service environment (systemd unit, launchctl, container env), then restart. Unauthenticated; restrict with a firewall.
- LM Studio: allow network access in its server settings (see the `lm-studio` skill).
- A host firewall (ufw, firewalld) may block the Docker bridge subnet; allow it to the engine port only.

Binding to `0.0.0.0` on a machine with a public interface exposes the engine; prefer binding to the bridge address, a VPN or tailnet address, or an authenticating proxy.

## Alternative: host networking

```bash
docker run -d --network=host -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 -e WEBUI_SECRET_KEY="$(cat ~/.config/open-webui/secret)" \
  --name open-webui --restart always ghcr.io/open-webui/open-webui:v0.12.0
```

With host networking `-p` is ignored and the UI is on port 8080 of the host. It works on Linux; Docker Desktop's behavior differs.

## Compose with an engine in the same file

```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:v0.12.0
    environment:
      - OPENAI_API_BASE_URLS=http://litellm:4000/v1
    depends_on: [litellm]
  litellm:
    image: <your pinned litellm image>
```

Use the service name in URLs. `depends_on` only orders start, so a slow engine still makes the first model fetch fail; the list refreshes on the next load or after saving Connections.

## Same URL, different result

An admin (global) connection is resolved by the backend, so it needs the internal URL. A user Direct Connection is resolved by the browser. If the same URL works as a direct connection but returns 502 as an admin connection, the backend cannot resolve or reach it; use the internal name or address. The same applies to tool servers and Open Terminal.

## Name lookups

Open WebUI uses the operating system resolver by default again (older builds used c-ares and could intermittently fail to resolve container names, shown as "Model not found"). Upgrade if you see that; `AIOHTTP_CLIENT_ASYNC_DNS_RESOLVER=true` re-enables c-ares and may stop `.local` names resolving.

## Test from inside the container

```bash
docker exec open-webui sh -c 'curl -fsS -m 5 -H "Authorization: Bearer $KEY" "$0"' http://host.docker.internal:8000/v1/models | head -c 300
docker exec open-webui getent hosts host.docker.internal
```

(`$KEY` must exist inside the container's shell; otherwise test from the host with the same URL substituted.)

## Official links

- Connection errors (Docker, Ollama, Podman, DNS): https://docs.openwebui.com/troubleshooting/connection-error
- Manual Docker install: https://docs.openwebui.com/getting-started/quick-start/tab-docker/ManualDocker
