---
name: litellm
description: LiteLLM proxy, a self-hosted OpenAI- and Anthropic-compatible gateway to 100+ providers with virtual keys, budgets and fallbacks. Use to install (docker, pip, helm), write config.yaml (model_list, model_info, drop_params), issue keys and budgets, route and fall back, bridge /v1/messages and /v1/responses, add Langfuse or Prometheus, update or roll back, and fix No connected db, UnsupportedParamsError, 404 api_base. Not for choosing a gateway (llm-gateway).
license: MIT
compatibility: Commands assume bash, curl, jq and Docker Compose (pip and Helm paths also covered). Installs, exposure, key creation and upgrades need the user's explicit approval. Needs Postgres for keys and budgets.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LiteLLM

A running LiteLLM proxy (`litellm`, image `ghcr.io/berriai/litellm`, repo BerriAI/litellm) that gives clients one authenticated endpoint with stable model aliases, scoped virtual keys with budgets, retries and fallbacks, and Anthropic Messages and OpenAI Responses bridging, plus the know-how to update and troubleshoot it.

**Scope:** this one product: install, configure, operate, update, troubleshoot. Choosing between gateways (LiteLLM, OpenRouter, Portkey, Envoy, Kong, Cloudflare) belongs to the `llm-gateway` skill. Serving the models belongs to the engine skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'litellm|postgres' || true
command -v litellm && litellm --version 2>/dev/null | head -1
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E ':(4000|4001|8080)\b' || true
find ~ -maxdepth 4 \( -name 'litellm*.y*ml' -o -name 'config.yaml' -path '*litellm*' \) 2>/dev/null | head
env | cut -d= -f1 | grep -Ei 'LITELLM|DATABASE_URL' || true                       # names only
docker inspect <litellm-container> --format '{{.Config.Image}}' 2>/dev/null          # tag in use
curl -fsS http://127.0.0.1:4000/health/readiness | jq '{status, db, litellm_version}'
curl -fsS http://127.0.0.1:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq -r '.data[].id'
gh api repos/BerriAI/litellm/releases/latest --jq .tag_name                          # newest stable
```

Ask only what discovery cannot show: providers and backends, consumers (people, teams, CI), budget limits, whether the proxy is reachable beyond localhost, Docker vs pip vs Kubernetes.

## Decision flow

1. **Nothing installed:** Docker Compose with Postgres for one host (`assets/`), Helm for Kubernetes, `pip`/`uv` for a throwaway local proxy. -> `references/install.md`
2. **Installed, no database:** no virtual keys, no budgets, no Admin UI model storage. Add Postgres before promising limits.
3. **Add a backend or model:** alias in `model_name`, provider prefix in `model`, `model_info` filled in. -> `references/models-and-providers.md`
4. **Client speaks `/v1/messages` or `/v1/responses` and the backend is chat-only:** bridge at the gateway. -> `references/api-bridging.md`
5. **Several consumers:** teams and virtual keys. -> `references/keys-budgets.md`
6. **Backend fails or is slow:** replicas, retries, fallbacks. -> `references/routing-fallbacks.md`
7. **Need traces or metrics:** callbacks. -> `references/observability.md`
8. **Behavior config cannot express:** custom hook, last resort. -> `references/callbacks-and-hooks.md`
9. **New release or regression:** -> `references/updating.md`
10. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, restarts, exposure, key creation and upgrades need approval and an undo path (recorded image digest, DB dump).
- **Clients see aliases.** `coder`, `chat-fast`; never provider model IDs.
- **Pin the image.** Release tag (better: tag plus digest), never `latest`, `main-stable` or `main-latest` in anything shared. Stable tags are plain semver since 1.84.0, bare or `v`-prefixed.
- **Master key is admin-only.** Every person, app and CI job gets a virtual key with model scope and budget; write generated keys to `0600` files, never to the terminal.
- **Never change `LITELLM_SALT_KEY`** after credentials are stored in the DB. Rotate only the master key, by changing the env var and restarting when a salt key is set.
- **Every model has `model_info`.** Context, output limit, capabilities; explicit zero cost for local models.
- **Config before code.** `drop_params`, `additional_drop_params`, aliases, fallbacks and built-in callbacks before any Python hook.
- **Secrets never touch output.** `os.environ/NAME` in YAML, env files `chmod 600`, `jq` filters on every JSON dump (`/key/info` echoes keys).
- **Verify upstream.** Versions, flags and defaults come from docs.litellm.ai and the GitHub releases at use time; the config schema of the running version is at `/#/config.yaml`.

## Workflows

### Install and first request

- [ ] Choose the path and generate `.env` without printing keys -> `references/install.md`.
- [ ] Copy `assets/docker-compose.yaml`, `assets/litellm-config.yaml`; pin the tag; bind to `127.0.0.1`.
- [ ] `docker compose up -d`; check `/health/liveliness`, `/health/readiness` (`"db": "connected"`) and `/v1/models`.
- [ ] One chat call and one tool call per alias.

### Add a model

- [ ] Confirm the backend answers directly (`/v1/models`, one chat call).
- [ ] Add the `model_list` entry and `model_info` -> `references/models-and-providers.md`; restart; test through the gateway.

### Keys and budgets

- [ ] Confirm the DB is connected; create a team, then scoped keys with `max_budget`, `budget_duration`, `rpm_limit`, `tpm_limit` -> `references/keys-budgets.md`.

### Bridge clients

- [ ] Messages (Claude Code): base URL is the root; test `/v1/messages` -> `references/api-bridging.md`, `references/combos/claude-code.md`.
- [ ] Responses (Codex, Agents SDK): force `use_chat_completions_api: true` on chat-only backends.
- [ ] Stream plus tool call through each bridged path.

### Update or roll back

- [ ] Read release notes between tags; record digest; dump Postgres -> `references/updating.md`.
- [ ] Bump the pin, pull, restart, re-run smoke tests; roll back to the recorded digest on regression.

### Observe

- [ ] Add `callbacks` (`prometheus`, `langfuse_otel`) and set provider env vars -> `references/observability.md`, `references/combos/langfuse.md`.

## Reference index

| File                                 | Read when                                                      |
| ------------------------------------ | -------------------------------------------------------------- |
| `references/install.md`              | Docker, Compose, pip/uv, Helm, secrets, exposure, image tags   |
| `references/configuration.md`        | `config.yaml` sections, endpoints, health, tuning              |
| `references/models-and-providers.md` | `model_list`, prefixes, `model_info`, aliases, param dropping  |
| `references/keys-budgets.md`         | Teams, virtual keys, budgets, rate limits, master key rotation |
| `references/routing-fallbacks.md`    | Strategies, retries, timeouts, fallbacks, cooldowns, Redis     |
| `references/api-bridging.md`         | `/v1/messages` and `/v1/responses` over chat backends          |
| `references/callbacks-and-hooks.md`  | Built-in callbacks, custom Python hooks                        |
| `references/observability.md`        | Langfuse, OTel, Prometheus, logs, privacy                      |
| `references/updating.md`             | Release cycle, pinning, upgrade, rollback, migrations, backups |
| `references/troubleshooting.md`      | Symptom to cause to fix                                        |
| `references/combos/llama-swap.md`    | LiteLLM in front of llama-swap                                 |
| `references/combos/langfuse.md`      | Traces to Langfuse                                             |
| `references/combos/claude-code.md`   | Claude Code through the gateway                                |

Templates: `assets/litellm-config.yaml`, `assets/docker-compose.yaml`, `assets/litellm.env.example`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-gateway`: whether to use a gateway and which one; stack-level workflow around LiteLLM.
- `llama-swap`: the swapper usually behind LiteLLM on a local or GPU host.
- `self-hosted-llms`: engines and the full stack that LiteLLM fronts.
- `llm-clients`: pointing agents, IDEs and SDKs at the gateway.
- `llm-observability`: dashboards, collectors and alerting fed by callbacks.
- `cloud-llms`: provider accounts, pricing and quotas.
