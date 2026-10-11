# LobeHub: Docker networking, SSRF guard, Client Request Mode

> Verified against LobeHub v2.2.19 (docs: self-hosting/server-database/docker, environment-variables/basic, usage/providers/ollama), 2026-10-11

## Reaching endpoints from the container

The LobeHub server makes the model calls, so URLs must resolve from the `lobehub` container:

| Endpoint runs                         | Use                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------- |
| Docker host (macOS, Windows)          | `http://host.docker.internal:PORT`                                                    |
| Docker host (Linux)                   | Same, with `extra_hosts: ["host.docker.internal:host-gateway"]` on the `lobe` service |
| Container in the same Compose project | `http://<service>:PORT`                                                               |
| LAN or tailnet machine                | `http://<ip-or-name>:PORT`                                                            |

`localhost` and `127.0.0.1` are the container. The engine must listen beyond loopback (vLLM and llama.cpp `--host 0.0.0.0`, Ollama `OLLAMA_HOST=0.0.0.0`) with auth and a firewall; a service on `0.0.0.0` is reachable by anything that can reach the host.

The official docs show `host.docker.internal` for a host Postgres on Mac and Windows.

## SSRF guard

LobeHub blocks server-side requests to private IPs in some flows, for example converting image and video URLs to base64 for vision models and certain tool fetches.

```bash
SSRF_ALLOW_PRIVATE_IP_ADDRESS=0
SSRF_ALLOW_IP_ADDRESS_LIST=192.168.1.100,10.0.0.50   # only effective while the first is 0
```

Setting `SSRF_ALLOW_PRIVATE_IP_ADDRESS=1` disables the protection for all private addresses; avoid it on anything reachable by other users. If a vision request fails with a blocked-address error while text chat works, allowlist the specific IP.

## Client Request Mode

The provider pages for vLLM, Ollama and LM Studio tell you to enable **Client Request Mode** when the server runs on your own device: requests then go from the browser straight to the endpoint instead of through the LobeHub server. Consequences:

- The endpoint must be reachable from the browser, and for cross-origin calls it must allow your LobeHub origin (Ollama: `OLLAMA_ORIGINS`; see the Ollama provider page).
- The key is in the browser, not protected by server-side storage.
- It is how a laptop-local endpoint works with a remote LobeHub. Those docs predate the v2 server-only change; confirm the toggle's presence and behavior in your version before relying on it. (unverified for v2.2.19)

Prefer server-side calls with a gateway for shared deployments.

## Reverse proxy

Forward `Host` and `X-Forwarded-Proto`, allow WebSocket upgrade on the app and the agent gateway (`8787`), and do not buffer streaming responses. Docs include nginx, Caddy and Traefik examples in the Docker Compose page.

## Official links

- Environment variables (SSRF): https://lobehub.com/docs/self-hosting/environment-variables/basic
- Docker: https://lobehub.com/docs/self-hosting/server-database/docker
- Ollama provider: https://lobehub.com/docs/usage/providers/ollama
