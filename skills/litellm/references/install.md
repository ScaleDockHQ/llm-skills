# LiteLLM: install

> Verified against LiteLLM v1.105.0 (docs: simple_proxy, proxy/docker_quick_start, proxy/deploy, proxy/prod, proxy/docker_image_security, proxy/release_cycle; PyPI litellm 1.105.0; ghcr.io manifests v1.105.0), 2026-10-11

Pick one path. Docker Compose with Postgres is the default for a single host; pip is for a quick local proxy; Helm is for Kubernetes.

## Images and packages

- Images: `ghcr.io/berriai/litellm` (use this one for deployments with Postgres: it bundles the Prisma toolchain), mirrored at `docker.litellm.ai/berriai/litellm`. Variants under `ghcr.io/berriai/` include `litellm-non_root`. Images are cosign-signed since v1.83.0 (see `proxy/docker_image_security`).
- Tags: since 1.84.0 stable releases are plain semver, published bare (`1.105.0`) and `v`-prefixed (`v1.105.0`) on Docker; PyPI uses the bare form only. Both `v1.105.0` and `1.105.0` resolved on ghcr.io on 2026-10-11. Upstream examples still show `main-stable` and `latest`; pin a release tag for anything shared.
- PyPI: `litellm`, version 1.105.0, Python `>=3.10,<3.15`. The proxy needs the `proxy` extra.
- Find the newest stable tag: `gh api repos/BerriAI/litellm/releases/latest --jq .tag_name` (or `curl -fsS https://api.github.com/repos/BerriAI/litellm/releases/latest | jq -r .tag_name`).

## Secrets (all paths)

```bash
umask 077
touch .env
printf 'LITELLM_MASTER_KEY=sk-%s\nLITELLM_SALT_KEY=sk-%s\nPOSTGRES_PASSWORD=%s\n' \
  "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" "$(openssl rand -hex 24)" >> .env
# add provider keys by editing .env in an editor, never with echo in shell history
```

- `LITELLM_MASTER_KEY` must start with `sk-`. The proxy refuses to start without it. It is also the Admin UI password (user `admin`).
- `LITELLM_SALT_KEY` encrypts provider credentials stored in the database. Set once; never change it after models or credentials are stored in the DB (no in-place rotation).
- `DATABASE_URL` (`postgresql://user:pass@host:5432/db`) enables virtual keys, teams, budgets and spend logs.

## Docker Compose with Postgres (recommended single host)

Start from `assets/docker-compose.yaml`, `assets/litellm-config.yaml`, `assets/litellm.env.example`. Differences from upstream's quickstart compose, on purpose: pinned image tag, ports bound to `127.0.0.1`, no published Postgres port, `STORE_MODEL_IN_DB=False` (config.yaml is the source of truth), no default DB password.

```bash
cp assets/docker-compose.yaml docker-compose.yaml
cp assets/litellm-config.yaml litellm-config.yaml
# create .env as above (chmod 600), then:
docker compose up -d
LITELLM_MASTER_KEY="$(grep '^LITELLM_MASTER_KEY=' .env | cut -d= -f2-)"; export LITELLM_MASTER_KEY
curl -fsS http://127.0.0.1:4000/health/liveliness; echo
curl -fsS http://127.0.0.1:4000/health/readiness | jq '{status, db}'
```

## Docker without a database (OpenAI-compatible API only)

```bash
docker run \
  -v "$(pwd)/litellm_config.yaml:/app/config.yaml" \
  --env-file .env \
  -p 127.0.0.1:4000:4000 \
  ghcr.io/berriai/litellm:v1.105.0 \
  --config /app/config.yaml
```

Without a database there are no virtual keys (`No connected db.`), no Admin UI model management and **no budget enforcement**, including `litellm_settings.max_budget`. Bound spend at the provider instead.

## pip / uv

```bash
uv tool install 'litellm[proxy]'          # or: python -m pip install 'litellm[proxy]'
litellm --config /path/to/config.yaml     # listens on port 4000
litellm --model gpt-4o                    # quick single-model proxy, needs the provider key in the environment
```

- Useful CLI flags: `--port`, `--host`, `--num_workers`, `--max_requests_before_restart`, `--debug`, `--detailed_debug`.
- With the CLI, Prometheus needs `prometheus_client` installed (preinstalled in the Docker image).
- Database use outside Docker needs the Prisma toolchain; prefer the Docker image when you want Postgres.

## Helm (Kubernetes)

Two charts exist in the repo: `helm/litellm-helm` (monolithic, one image serves LLM traffic, management API and UI) and `helm/litellm` (microservices: gateway on 4000, backend on 4001, ui on 3000).

```bash
kubectl create secret generic litellm-masterkey --from-literal=masterkey="sk-$(openssl rand -hex 24)"
kubectl create secret generic litellm-db --from-literal=username=litellm --from-literal=password='<database-password>'
kubectl create secret generic litellm-env --from-literal=LITELLM_SALT_KEY="sk-$(openssl rand -hex 24)"
helm install litellm oci://ghcr.io/berriai/litellm-helm -f values.yaml
helm show values oci://ghcr.io/berriai/litellm-helm   # every knob
```

Upstream `values.yaml` shape: `replicaCount`, `image.repository: ghcr.io/berriai/litellm`, `image.tag` (pin it), `masterkeySecretName/Key`, `db.useExisting` plus `db.endpoint/database/secret`, `environmentSecrets`, `proxy_config` (the config.yaml as YAML, with `router_settings.redis_host` etc.), plus `autoscaling.*`/`keda.*`, `pdb.*`, `serviceMonitor.*`, `migrationJob.hooks.*`.

Production shape per upstream: 2+ stateless replicas, managed Postgres, Redis once you run more than one instance, a migrations job per upgrade with `DISABLE_SCHEMA_UPDATE=true` on serving pods, secrets from a cloud secret manager. On Kubernetes run one Uvicorn worker per pod (`--num_workers 1`) and scale pods instead.

Unverified: the chart in the repo's `helm/litellm-helm/Chart.yaml` showed `version: 1.1.3` and `appVersion: v1.85.1` while upstream docs say published chart versions carry LiteLLM release numbers. Run `helm show chart oci://ghcr.io/berriai/litellm-helm` and set `image.tag` explicitly rather than trusting the default.

## Terraform

Official AWS and GCP modules exist; Azure has none (AKS plus Helm is the supported path). See `proxy/deploy`.

## Verify an install

```bash
curl -fsS http://127.0.0.1:4000/health/readiness | jq '{status, db, litellm_version}'
curl -fsS http://127.0.0.1:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq -r '.data[].id'
curl -fsS http://127.0.0.1:4000/v1/chat/completions -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H 'content-type: application/json' -d '{"model":"<alias>","messages":[{"role":"user","content":"Say ok"}]}' | jq '.choices[0].message.content'
```

## Exposure

Bind to `127.0.0.1` until a TLS reverse proxy or private network exists. Reverse proxies must not buffer SSE and need long read timeouts. Set `general_settings.health_check_details: false` when many users can reach the proxy.

## Official links

- Overview: https://docs.litellm.ai/docs/simple_proxy
- Docker quickstart: https://docs.litellm.ai/docs/proxy/docker_quick_start
- Production deployment (Helm, Terraform): https://docs.litellm.ai/docs/proxy/deploy
- Production checklist: https://docs.litellm.ai/docs/proxy/prod
- Image security: https://docs.litellm.ai/docs/proxy/docker_image_security
- Upstream quickstart compose: https://github.com/BerriAI/litellm/blob/main/docker-compose.yml
