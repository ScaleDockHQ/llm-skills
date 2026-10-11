# Governance: auth, virtual keys, budgets

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/quickstart/gateway/setting-up-auth>, <https://docs.getbifrost.ai/features/governance/virtual-keys>, `/features/governance/budget-and-limits`, `/features/governance/routing`.

## Dashboard and admin auth

Workspace > Config > Security > Password protect the dashboard. Enabling auth for the first admin needs a **setup token** that the operator configures ahead of time (`setup_token` in `config.json` or `BIFROST_SETUP_TOKEN`; required from 2.0.0-prerelease3). Without a configured token creating the first admin is rejected. The token is never persisted or logged. Options: disable auth on inference calls (dashboard and admin stay protected, MCP execution still authenticated), and whitelist routes (prefix match with a trailing `*`). Enterprise SSO via OIDC counts as configured auth.

## Virtual keys

The primary governance object. Clients present them as `x-bf-vk: sk-bf-...`, or `Authorization: Bearer sk-bf-...`, `x-api-key` (Anthropic style), `x-goog-api-key` (Gemini style), or `api-key` (Azure style). Keys without the `sk-bf-` prefix work only via `x-bf-vk`.

To require one on every inference request set `client.enforce_auth_on_inference: true` (UI: Enforce Virtual Keys on Inference). A key is **deny-by-default for providers**: only providers in `provider_configs` are usable, and an empty list blocks everything. Use the UI's Allow all providers toggle for permissive keys.

```bash
curl -sS http://localhost:8080/api/governance/virtual-keys -H 'Content-Type: application/json' -d '{
  "name": "engineering",
  "provider_configs": [
    { "provider": "openai", "weight": 0.5, "allowed_models": ["<model>"], "key_ids": ["*"] },
    { "provider": "anthropic", "weight": 0.5, "allowed_models": ["<model>"], "key_ids": ["*"] }
  ],
  "budgets": [{ "max_limit": 100.00, "reset_duration": "1M" }]
}'
curl -sS http://localhost:8080/api/governance/virtual-keys | jq '.'
```

The key value is returned at creation; handle it like any secret (do not paste it into logs or chat). CRUD lives at `/api/governance/virtual-keys[/{id}]` (GET, POST, PUT, DELETE) and `/api/governance/teams`.

## Hierarchy, budgets and rate limits

Customer, Team, Virtual Key, Provider Config form a hierarchy; each level can have its own budget, and keys and provider configs also carry rate limits. Budget `reset_duration` suffixes: `d`, `w`, `M`, `Q`, `Y`. Rate limit durations: `m`, `h`, `d`. By default budgets roll from `last_reset`; `calendar_aligned: true` resets at UTC calendar boundaries for day-or-longer windows. Model limits and required headers are separate features (`features/governance/model-limits`, `required-headers`).

Important: state (budgets, usage) is held in memory per node. The docs state that several OSS nodes on one PostgreSQL are unsupported; Enterprise synchronises state. Plan one OSS instance, or Enterprise for HA.

Routing rules (`providers/routing-rules`) use CEL expressions that run before governance provider selection and can override it; governance routing itself uses static provider weights.
