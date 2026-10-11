# LibreChat: install

> Verified against LibreChat v0.8.8 (docs: local/docker, configuration/docker_override, configuration/dotenv; repo docker-compose.yml and .env.example on main), 2026-10-11

One supported path for a self-hosted trial or small team: Docker Compose from the upstream repository. Upstream moved from `danny-avila/LibreChat` to `LibreChat-AI/LibreChat`; both URLs resolve, docs now clone the latter.

## Prerequisites

- Git and Docker with the Compose plugin. Docker Desktop is fine for local use; on a Linux server use Docker Engine.
- Apple Silicon: the default `mongo:8.0.20` image needs AVX and crashes under emulation. Override it with `mongo:4.4.18` (see `assets/docker-compose.override.yml`).
- Free ports: 3080 (the web app). The stock compose also starts MongoDB, Meilisearch, a vector DB and the RAG API, and (in current main) an admin panel on `ADMIN_PANEL_PORT` (default 3000); none of those should be published beyond the host.

## Install

```bash
git clone https://github.com/LibreChat-AI/LibreChat.git
cd LibreChat
git checkout v0.8.8            # pin a release instead of tracking main
cp .env.example .env
chmod 600 .env
cp ../path/to/skill/assets/librechat.yaml ./librechat.yaml          # from this skill
cp ../path/to/skill/assets/docker-compose.override.yml ./docker-compose.override.yml
docker compose up -d
```

Open `http://localhost:3080`, click Register. In an unscoped single-tenant deployment the first account becomes the admin. There are no default credentials.

Check the image references in the compose file you checked out. The `main` branch references `registry.librechat.ai/librechat-ai/librechat-dev:latest`; for a release checkout verify the tag in that tag's `docker-compose.yml` and prefer an explicit version tag over `latest` or `-dev` in your override. Record the digest: `docker image inspect --format '{{index .RepoDigests 0}}' <image>`.

## `.env` essentials

`CREDS_KEY`, `CREDS_IV`, `JWT_SECRET` and `JWT_REFRESH_SECRET`: if blank, LibreChat generates random values on first start and keeps them in a temporary credentials file (owner-only). Upstream calls that a bootstrap convenience: for production set permanent values (upstream offers a Credentials Generator on librechat.ai), store them in a secret manager and give every replica the same ones. Changing an established key does not re-encrypt existing records.

```bash
# local equivalent of the generator; write straight into .env, never paste into chat or logs
openssl rand -hex 32       # JWT_SECRET, JWT_REFRESH_SECRET, CREDS_KEY (one run per variable)
openssl rand -hex 16       # CREDS_IV
```

| Variable                                         | Why it matters                                                                                                                                                                                                                                                                      |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DOMAIN_CLIENT`, `DOMAIN_SERVER`                 | Must match the public URL (default `http://localhost:3080`) or login and redirects break behind a proxy.                                                                                                                                                                            |
| `ALLOW_REGISTRATION`                             | `true` by default. Set `false` once your admin exists, before exposing the UI.                                                                                                                                                                                                      |
| `TRUST_PROXY`                                    | Set (default `1` in the sample) when running behind one reverse proxy so client IPs and cookies are right.                                                                                                                                                                          |
| `CONFIG_PATH`                                    | Optional alternative path for `librechat.yaml`; the usual route is a bind mount to `/app/librechat.yaml`.                                                                                                                                                                           |
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`            | `user_provided` in the sample makes users enter their own key for the built-in endpoints. Built-in `OPENAI_REVERSE_PROXY` and `ANTHROPIC_REVERSE_PROXY` exist, but custom endpoints in `librechat.yaml` are the documented way to reach self-hosted servers and keep them separate. |
| `ENDPOINTS`                                      | Optional ordering or restriction of the built-in endpoint list (`openAI,assistants,azureOpenAI,google,anthropic`); custom endpoints are listed from `librechat.yaml`.                                                                                                               |
| `PROXY`, `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` | Outbound proxy for server-side calls; keep your gateway host in `NO_PROXY` if it is internal.                                                                                                                                                                                       |

## Mounting `librechat.yaml`

The upstream way is a `docker-compose.override.yml` that adds the bind mount (a file in the repo root, picked up automatically by `docker compose`). Each service name may appear only once in the override. If you start the stack with a non-default file such as `deploy-compose.yml`, pass both: `docker compose -f deploy-compose.yml -f docker-compose.override.yml up -d`.

After any change to `librechat.yaml`: `docker compose down && docker compose up -d` (the upstream docs' restart instruction). Config errors are logged at startup; read them with `docker logs LibreChat`.

## Networking to your models

- Server on the Docker host: `http://host.docker.internal:<port>`. Upstream's compose adds `extra_hosts: host.docker.internal:host-gateway`.
- Server in another Compose project: attach the `api` service to that project's network (see the commented lines in the override template) and use its service name.
- Server on another machine: its LAN or Tailscale address. Never expose an unauthenticated Ollama or llama.cpp port to the network just so a container can reach it; bind it to the interface the container uses and firewall the port.

## Updating

Upstream's documented cycle (from `local/docker`): stop, pull the new checkout and images, start. Make it safe:

```bash
docker compose down
cp .env .env.bak && cp librechat.yaml librechat.yaml.bak && chmod 600 .env.bak
# back up MongoDB data too: look at the volumes/bind mounts of the mongodb service in docker-compose.yml
docker compose config | grep -A3 -i 'mongodb:' | head -20
git fetch --tags && git checkout <new-tag>
docker compose pull
docker compose up -d
```

Then read the release notes: config changes arrive as `Config v1.3.x` entries and bump the `version:` line you may need in `librechat.yaml`. Re-run `scripts/check-endpoint.sh` and send one chat and one tool-call message.

Upstream also supports Kubernetes (Helm chart) and bare Node installs; this skill covers Compose only.
