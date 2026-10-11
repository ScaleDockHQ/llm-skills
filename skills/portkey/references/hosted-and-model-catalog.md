# Portkey hosted platform and Model Catalog

> Verified against docs.portkey.ai (introduction/make-your-first-request, product/model-catalog, product/ai-gateway/virtual-keys, configs, product-feature-comparison, product/open-source) and Portkey AI Gateway v1.15.2 README, 2026-10-11

Use this when the user wants key management, budgets, saved configs, logs and prompt management without building them. The open-source gateway does not provide those.

## Open source versus hosted

The vendor's own comparison marks these as not in the open-source gateway: logs, traces, feedback, alerts, config management, LLM key management (virtual keys and budgets), simple and semantic caching, prompt management, partner and deterministic guardrails as a managed feature, RBAC, team management, audit logs and admin APIs. The open-source gateway includes the Universal API, fallbacks, load balancing, conditional routing, retries and request timeouts. Note the repo README also shows guardrail configs and a plugin system in the source (`plugins/`), so a basic guardrail may work in open source; test it, and treat the managed catalog of guardrails as hosted. Plan names, request limits and prices change; read https://portkey.ai/pricing and the feature comparison page rather than copying numbers.

## Hosted quickstart

1. Create an account at https://app.portkey.ai and create an API key (Settings) with the permissions you need. Store it in a 0600 file or environment variable.
2. Base URL `https://api.portkey.ai/v1`; auth header `x-portkey-api-key: $PORTKEY_API_KEY`.
3. Add a provider in the Model Catalog (provider credentials stored by Portkey, with its own budget, rate limits and model allow-list). It gets a slug, for example `openai-prod`.
4. Call models as `@provider-slug/model-name`, for example `@openai-prod/gpt-4o`.

```bash
curl -fsS https://api.portkey.ai/v1/chat/completions \
  -H "x-portkey-api-key: $PORTKEY_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"@<provider-slug>/<model>","messages":[{"role":"user","content":"ping"}]}' | jq '.choices[0].message.content'
```

## Model Catalog

Replaces Virtual Keys (the docs state Virtual Keys migrated to Model Catalog). Providers are created per workspace or shared across workspaces through Integrations (org admin). Budget limits, rate limits and model allow-lists apply at provider level. Existing `x-portkey-virtual-key` flows are covered by a migration guide at docs.portkey.ai/docs/support/upgrade-to-model-catalog. Models in configs use the same `@slug/model` form: `{"override_params": {"model": "@openai-prod/gpt-4o"}}` or `{"provider": "@openai-prod"}`.

## Configs, default configs and API keys

Saved configs get IDs like `pc-...`, referenced by `x-portkey-config: pc-...` or the SDK `config` argument; a request-specific config replaces the default. You can attach a default config to an API key so clients that cannot send headers (Open WebUI, LibreChat) still get routing and fallbacks, and so admins can enforce policy.

## Enterprise and private deployments

Enterprise adds private cloud deployments on AWS, Azure, GCP, OpenShift and Kubernetes, SSO and SCIM, and audit logs. The vendor's architecture docs are at portkey.ai/docs/self-hosting. Decisions about these belong to a sales and security review, not this skill.

## Data

Hosted Portkey sits in the path of every prompt and completion and stores logs by plan. Review its privacy and retention settings before routing sensitive data, or use the self-hosted gateway to keep traffic on your network.
