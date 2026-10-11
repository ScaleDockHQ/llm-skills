# Portkey gateway: install

> Verified against Portkey AI Gateway v1.15.2 (repo README and docs/installation-deployments.md, Docker Hub portkeyai/gateway, npm @portkey-ai/gateway), 2026-10-11

Pick one path. The open-source gateway is a Hono app on Node.js (default port 8787) that is also deployable to Cloudflare Workers and other runtimes.

## Versions and artifacts (read at use time)

- Latest GitHub release and npm `latest`: 1.15.2 (published 2026-01-12). Docker Hub tags track releases (`1.15.2`, `latest`); the `latest` image was last pushed the same day.
- The default branch has newer commits than that release (for example May 2026 changes that require an `admin_token` for the local UI), and a `2.0.0` branch exists as a pre-release. Releases and images do not include them. Pin a release tag.
- Find the newest: `gh api repos/Portkey-AI/gateway/releases/latest --jq .tag_name`, `curl -fsS "https://registry.npmjs.org/@portkey-ai%2fgateway" | jq -r '."dist-tags".latest'`, `curl -fsS "https://hub.docker.com/v2/repositories/portkeyai/gateway/tags?page_size=5" | jq -r '.results[].name'`.

## Try it (npx or bunx)

```bash
npx @portkey-ai/gateway      # or: bunx @portkey-ai/gateway
```

The gateway listens on `http://localhost:8787/v1` and, outside production mode, serves a console at `http://localhost:8787/public/`. Stop with Ctrl-C. Nothing persists on disk. Needs Node.js (the image uses Node 20).

## Docker (recommended for a host)

```bash
docker run --rm -p 127.0.0.1:8787:8787 portkeyai/gateway:1.15.2
```

Prefer `assets/docker-compose.yaml` (pinned tag, loopback bind, read-only root). Upstream's own compose file is `image: portkeyai/gateway:latest` on `8787:8787` with no loopback bind; do not copy that for shared hosts. Record the digest: `docker inspect --format '{{index .RepoDigests 0}}' portkeyai/gateway:1.15.2`.

The image starts `npm run start:node` (that is `node build/start-server.js`) and exposes 8787.

## Node.js from source

```bash
git clone https://github.com/Portkey-AI/gateway && cd gateway
git checkout v1.15.2
npm i && npm run build
node build/start-server.js          # flags: --port=8787, --headless
```

`--headless` skips the console UI. Building from `main` instead of a tag picks up unreleased behavior, including the required `admin_token` in `conf.json` for the UI.

## Kubernetes

Upstream ships `deployment.yaml` in the repo (a Namespace `portkeyai` and a Deployment of `portkeyai/gateway`, one replica, port 8787, no resources or probes, unpinned image). Copy it, pin the image, add `resources`, a `readinessProbe` on `GET /` (returns `AI Gateway says hey!`), a ClusterIP Service and an authenticating Ingress or Gateway in front.

## Other targets

Cloudflare Workers (`npm run deploy` with Wrangler), AWS EC2 via the CloudFormation template (opens port 8787 to `0.0.0.0/0` by default, tighten it), Replit, Zeabur, Supabase Functions, Fastly and F5 App Stack are in `docs/installation-deployments.md`. Read the section before using it; several defaults are open.

## Verify

```bash
curl -fsS http://127.0.0.1:8787/                      # AI Gateway says hey!
curl -fsS http://127.0.0.1:8787/v1/chat/completions \
  -H "x-portkey-provider: openai" -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"ping"}],"max_tokens":8}' | jq '.choices[0].message.content'
```

## Undo

Compose: `docker compose down`. npx: Ctrl-C. Nothing else is installed on the host.
