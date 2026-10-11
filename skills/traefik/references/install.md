# Traefik: install

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: docs "Getting Started" (Docker), reference "Install Configuration" and "Docker provider".

## Docker Compose (recommended)

Use `templates/docker-compose.yml` and `templates/traefik.yml`. Upstream's quick start uses `traefik:v3.7` with `--providers.docker=true`, port 80 and, for development only, `--api.insecure=true` on 8080. For anything shared:

- Pin `traefik:v3.7.14` (record the digest: `docker image inspect traefik:v3.7.14 --format '{{join .RepoDigests "\n"}}'`).
- Publish 80 and 443; publish 8080 only as `127.0.0.1:8080:8080` if you use `api.insecure` locally.
- Mount config `:ro`; mount a volume for `acme.json` (`chmod 600`).
- Docker provider: mount `/var/run/docker.sock:ro` only if you need label discovery; upstream warns the socket gives root-level access. Alternatives it names: expose the socket over TCP or SSH with client-certificate authentication, or filter with the Tecnativa Docker Socket Proxy. Always set `exposedByDefault: false`.

Config can come from CLI flags, a file (`traefik.yml` or `.toml`), or environment variables; do not mix more than one source, since upstream applies only one.

## Binary

Download a release asset from GitHub releases; run `traefik --configFile=/etc/traefik/traefik.yml`. Use a systemd unit with `AmbientCapabilities=CAP_NET_BIND_SERVICE` to bind 80 and 443 without root.

## Kubernetes

Use the official Helm chart (`traefik/traefik-helm-chart`) and the `kubernetesCRD`, `kubernetesIngress` or `kubernetesGateway` providers; see the provider pages under reference/install-configuration/providers/kubernetes. Not expanded here.

## Verify

```bash
docker compose ps; docker compose logs --tail 50 traefik
curl -fsS http://127.0.0.1:8080/api/http/routers | jq -r '.[]|.name'     # if the API is reachable
curl -sS -o /dev/null -w '%{http_code}\n' -H 'Host: llm.example.com' http://127.0.0.1/
```
