# LiteLLM proxy setup

> Verified against LiteLLM v1.105.0 (docs: proxy/docker_quick_start, proxy/deploy, proxy/prod, proxy/configs, proxy/health), 2026-10-11

## How it plugs into this stack

- Install with `assets/docker-compose.yaml`, `assets/litellm-config.yaml` and `.env` from `assets/litellm.env.example` (`chmod 600`). Image pinned to a release tag, ports bound to `127.0.0.1`, Postgres unpublished, `STORE_MODEL_IN_DB=False` so `config.yaml` is the source of truth.
- Port 4000. Health without auth: `/health/liveliness`, `/health/readiness` (expect `"db": "connected"`). Authenticated `/health` calls every model and costs tokens.
- Config entry point: `litellm-config.yaml` mounted at `/app/config.yaml`; secrets via `os.environ/NAME`.
- `LITELLM_MASTER_KEY` starts with `sk-` and stays admin-only; `LITELLM_SALT_KEY` is set once and never changed after credentials are stored.
- Pitfalls: `127.0.0.1` inside the container is the container (use `host.docker.internal`); config edits need `docker compose restart litellm`; budgets need the database.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llms-skills --skill litellm)
