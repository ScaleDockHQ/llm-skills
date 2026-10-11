---
name: llm-gateway
description: Put one OpenAI- and Anthropic-compatible endpoint in front of many local and cloud LLM providers. Use when choosing an LLM gateway (LiteLLM proxy, OpenRouter, Portkey, Envoy AI Gateway / Agent Router, Kong AI Gateway, Cloudflare AI Gateway), installing the LiteLLM proxy with Docker and Postgres, writing config.yaml (model_list, litellm_params, model_info, model_group_alias, drop_params), adding a provider or model, issuing virtual keys with budgets and rate limits, configuring routing, retries, fallbacks and cooldowns, bridging Anthropic /v1/messages and OpenAI /v1/responses clients onto chat-completions backends (use_chat_completions_api), pinning and upgrading the gateway image, or troubleshooting 400 unsupported-param errors, broken /v1/models metadata, missing context windows, keep-alive or streaming failures behind a gateway.
license: MIT
compatibility: Commands assume bash, curl, jq and Docker Compose. Examples target the LiteLLM proxy; other gateways are covered at decision level. Works with any OpenAI-compatible backend (llama.cpp, llama-swap, vLLM, SGLang, Ollama) and hosted APIs.
metadata:
  author: ScaleDockHQ
  version: "1.0.1"
---

# LLM Gateway

One stable, authenticated endpoint that speaks the OpenAI and Anthropic wire formats, routing to any mix of local engines and cloud APIs. This skill owns everything general about gateways: choice, install, model registry, keys and budgets, routing, API bridging, upgrades and troubleshooting.

Out of scope, handled by companion skills: serving the models themselves (`self-hosted-llms`, `local-llms`), picking a cloud vendor (`cloud-llms`), per-client config (`llm-clients`), tracing and dashboards (`llm-observability`).

## Discover first

Run these read-only checks before asking anything. They never print secret values.

```bash
# Running gateways and engines
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'litellm|portkey|envoy|kong|llama|vllm|sglang|ollama|postgres' || true
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E ':(4000|8080|8000|11434|8787|1975)\b' || true

# Existing gateway config files (names only)
find ~ -maxdepth 4 \( -name 'litellm*.y*ml' -o -name 'config.yaml' -path '*litellm*' -o -name 'docker-compose*.y*ml' \) 2>/dev/null | head -20

# Model registry and router settings without secrets
ruby -ryaml -e 'c=YAML.load_file(ARGV[0]); (c["model_list"]||[]).each{|m| p=m["litellm_params"]||{}; puts [m["model_name"], p["model"], p["api_base"]].join("\t")}; puts "router_settings: #{(c["router_settings"]||{}).keys}"; puts "litellm_settings: #{(c["litellm_settings"]||{}).keys}"' <path-to-config.yaml>

# Env var NAMES only (host and container)
env | cut -d= -f1 | grep -Ei 'LITELLM|OPENAI|ANTHROPIC|OPENROUTER|DATABASE_URL' || true
docker inspect <litellm-container> --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1

# Image tag and digest actually running
docker inspect <litellm-container> --format '{{.Config.Image}}'
docker image inspect "$(docker inspect <litellm-container> --format '{{.Image}}')" --format '{{join .RepoDigests "\n"}}'

# Health (no auth) and model list (key read from env, never echoed)
curl -fsS http://127.0.0.1:4000/health/liveliness; echo
curl -fsS http://127.0.0.1:4000/health/readiness | jq '{status, db}'
curl -fsS http://127.0.0.1:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq -r '.data[].id'
```

Ask the user only for what discovery can't reveal: which providers they have accounts with, who the consumers are (people, teams, CI), budget limits, and whether the gateway must be reachable beyond localhost.

## Decision flow

1. **Need a gateway at all?** One client and one backend: no, connect directly (`llm-clients`). Two or more backends, shared keys, budgets, or clients that speak a different API than the backend: yes.
2. **Which gateway?** Self-hosted, config-as-code, broadest provider and API coverage: LiteLLM proxy. Hosted pay-per-token catalog with zero ops: OpenRouter. Kubernetes-native platform team: Envoy AI Gateway (Agent Router). Existing Kong or Cloudflare estate: their AI gateway products. Guardrail-heavy JS stack: Portkey. -> `references/choosing-a-gateway.md`
3. **Which API do the clients speak?** OpenAI chat completions, OpenAI Responses, Anthropic Messages. The gateway must expose all of them; the backends usually speak only chat completions. -> `references/api-bridging.md`
4. **Where does state live?** Config file only (GitOps, no keys or budgets) or config plus Postgres (virtual keys, teams, spend). Pick one source of truth for models.

## Rules

- **Clients see stable names.** Expose aliases such as `coder` or `chat-fast`; never make clients depend on provider model IDs. Swap the backend, keep the name.
- **Pin the gateway image.** Use an explicit release tag (better: tag plus digest). Never `latest` or floating `main-*` tags in anything shared.
- **One master key, many virtual keys.** The master key is admin-only and lives in a secret store. Every person, app and CI job gets its own virtual key with model scope and budget.
- **Config-only before code.** Reach for `model_info`, `drop_params`, `additional_drop_params`, aliases, fallbacks and built-in callbacks before writing a Python hook.
- **Every model has model_info.** Declare context window, output limit and capabilities (tools, vision, reasoning) for every self-hosted or aliased model.
- **Secrets never touch output.** Reference keys as `os.environ/NAME` in config and env files outside git; never `cat` env files, never echo keys, filter JSON with `jq` before printing.
- **Measure before and after.** Record latency, error rate and a real tool-call test before any routing, version or param change, and compare after.

## Workflows

### Choose a gateway

- [ ] Run discovery; list backends, clients and the APIs each client speaks.
- [ ] Score the options on hosting model, API coverage, keys and budgets, and ops cost -> `references/choosing-a-gateway.md`.
- [ ] Record the choice and why in the user's repo (README or ADR), not in this skill.

### Set up LiteLLM

- [ ] Copy `assets/docker-compose.yaml` and `assets/litellm-config.yaml`; create `.env` from `assets/litellm.env.example` with `chmod 600`.
- [ ] Generate master and salt keys into `.env` without printing them -> `references/litellm-setup.md`.
- [ ] Pin the image tag; bind to `127.0.0.1` until auth and TLS are in place.
- [ ] `docker compose up -d`, then check `/health/liveliness`, `/health/readiness` and `/v1/models`.
- [ ] Send one chat request and one tool-call request per alias.

### Add a provider or model

- [ ] Confirm the backend answers directly (`/v1/models`, one chat call) before touching the gateway.
- [ ] Add a `model_list` entry: alias in `model_name`, provider-prefixed `model`, `api_base`, `api_key: os.environ/...` -> `references/models-and-providers.md`.
- [ ] Fill `model_info` (context, output, capabilities) and set `drop_params` or `additional_drop_params` where the backend rejects params.
- [ ] For chat-only backends that Responses clients will call, set `use_chat_completions_api: true` -> `references/api-bridging.md`.
- [ ] Reload, list models, run the chat and tool-call smoke tests through the gateway.

### Keys and budgets

- [ ] Ensure Postgres is connected (`/health/readiness` shows `"db": "connected"`); budgets are not enforced without a database.
- [ ] Create teams, then virtual keys scoped to aliases with `max_budget`, `budget_duration`, `rpm_limit`, `tpm_limit` -> `references/keys-budgets.md`.
- [ ] Store each key in the consumer's secret store; capture only the key alias in notes.

### Routing and fallbacks

- [ ] Group deployments under one `model_name`; choose `routing_strategy` -> `references/routing-fallbacks.md`.
- [ ] Add `fallbacks`, `context_window_fallbacks`, `num_retries`, `timeout`, `allowed_fails`, `cooldown_time`.
- [ ] Kill one backend on purpose and verify the fallback path and cooldown.

### Bridge Anthropic and Responses clients

- [ ] Anthropic clients (Claude Code, Anthropic SDK): point at the gateway root, test `/v1/messages` with `anthropic-version` header -> `references/api-bridging.md`.
- [ ] Responses clients (Codex, OpenAI Agents SDK, AI SDK default): verify `/v1/responses` per alias; force the chat bridge for backends without `/v1/responses`.
- [ ] Test streaming and a tool call through each bridged path.

### Upgrade

- [ ] Read release notes between current and target tag; note DB migrations -> `references/operations.md`.
- [ ] Back up Postgres; record the current image digest for rollback.
- [ ] Bump the pinned tag, `docker compose pull && docker compose up -d`, watch logs and health.
- [ ] Re-run smoke tests; roll back to the recorded digest on regression.

### Troubleshoot

- [ ] Reproduce with `curl` against the backend directly, then through the gateway.
- [ ] Match the symptom -> `references/troubleshooting.md`; check logs with `--detailed_debug` only temporarily.
- [ ] For behavior that config cannot express, consider a hook -> `references/hooks-and-callbacks.md`.

## References

| File                                 | Read when                                                                  |
| ------------------------------------ | -------------------------------------------------------------------------- |
| `references/choosing-a-gateway.md`   | Comparing LiteLLM, OpenRouter, Portkey, Envoy AI Gateway, Kong, Cloudflare |
| `references/litellm-setup.md`        | Installing LiteLLM with Docker and Postgres, keys, health endpoints        |
| `references/models-and-providers.md` | Writing `model_list`, `model_info`, aliases, param dropping, passthrough   |
| `references/keys-budgets.md`         | Virtual keys, teams, budgets, rate limits, rotation                        |
| `references/routing-fallbacks.md`    | Load balancing, retries, timeouts, fallbacks, cooldowns                    |
| `references/api-bridging.md`         | `/v1/messages` and `/v1/responses` clients over chat-completions backends  |
| `references/hooks-and-callbacks.md`  | Logging callbacks, Prometheus, last-resort Python hooks                    |
| `references/operations.md`           | Pinning, upgrades, rollback, migrations, logs, backups                     |
| `references/troubleshooting.md`      | Symptom to cause to fix                                                    |

Templates: `assets/litellm-config.yaml`, `assets/docker-compose.yaml`, `assets/litellm.env.example`.

## Companion skills

Install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `choosing-llm-hosting`: where models should run before you put a gateway in front.
- `self-hosted-llms`: engines and llama-swap behind the gateway; keeps only stack-specific LiteLLM config.
- `local-llms`: laptop and desktop backends.
- `cloud-llms`: provider accounts, pricing and quotas.
- `llm-clients`: pointing agents, IDEs, chat UIs and SDKs at the gateway.
- `llm-observability`: tracing, spend dashboards and alerting fed by gateway callbacks.
- `llm-evals`: measuring quality before and after a routing change.
