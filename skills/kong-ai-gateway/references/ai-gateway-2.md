# AI Gateway 2.x: Konnect entities with kongctl

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

AI Gateway 2.x is a separate Konnect control plane type with its own entity model, plus a `kong/kong-ai-gateway` data plane. The control plane provisions the underlying primitives; you no longer build Services, Routes and plugins by hand. It requires Konnect (the docs mark these pages `works_on: konnect`). Entities are regional (`us`, `eu`, `au`, `me`, `in`, `sg`): the active kongctl profile's `konnect.region` must match where the AI Gateway lives.

## Entities

| 2.x entity                     | Replaces in 3.x                             | Notes                                                                                         |
| ------------------------------ | ------------------------------------------- | --------------------------------------------------------------------------------------------- |
| AI Gateway                     | the control plane                           | `ai_gateways:` in kongctl; its `id` is `AI_GATEWAY_ID`                                        |
| AI Model Provider              | `targets[].model.provider` plus inline auth | credentials declared once, referenced by `name`                                               |
| AI Model                       | `ai-proxy-advanced` on a Service or Route   | `formats`, `capabilities`, `config.route`, `targets`, `config.balancer`, `access`, `policies` |
| AI MCP Server                  | `ai-mcp-proxy`                              | types map to the plugin modes; adds `upstream-server`                                         |
| AI Agent                       | `ai-a2a-proxy`                              | A2A support with analytics                                                                    |
| AI Auth Strategy               | auth plugins                                | `key-auth` or `openid-connect` (a model takes one of each)                                    |
| AI Consumer, AI Consumer Group | Consumers                                   | types such as `api-key`, `oauth`; hold ACL membership and policies                            |
| AI Policy                      | plugins                                     | `type` plus `config`, global or entity-scoped                                                 |

## kongctl

```bash
kongctl version                                   # docs ask for v1.20.2 or newer
kongctl plan  -f assets/ai-gateway-2.kongctl.yaml # preview
kongctl apply -f assets/ai-gateway-2.kongctl.yaml --pat "$KONNECT_TOKEN"
kongctl sync  -f file.yaml                        # also deletes resources absent from the file; ask first
```

Secrets: `!secret {source: !env VAR}` reads from the environment; `!lookup {id: !env AI_GATEWAY_ID}` resolves an existing gateway. Export the variables from a `0600` file and do not echo them. `decK` does not manage 2.x entities.

## Provider and model

- Provider: `type: openai`, `config.auth.type: basic`, `headers` with `Authorization` and a `!secret` value. Other provider types and fields: the AI providers page.
- Model: `type: model`, `formats: [{type: openai}]`, `capabilities: [generate]` (adds `/chat/completions` under `config.route.paths`), `config.route.model` with `body_param: model` and the client-facing `values`, and `targets` of `{name: <upstream model>, provider: <provider name>, config: {type: openai}}`.
- Targets can carry `temperature`, `max_tokens`, `input_cost`, `output_cost`, plus `cache_read_cost`, `cache_write_cost`, `context_window_factor` and `service_tier_factor` for providers that bill that way. Costs are yours to supply; do not copy prices from this skill.
- Several targets: set `config.balancer` (see `references/balancing-and-limits.md`).

## Inbound auth and ACLs

`access.auth_strategies` on a model lists AI Auth Strategies (one `key-auth` and one `openid-connect`). `access.acls.allow` limits to named AI Consumer Groups. Example strategy: `type: key-auth` with `config.key_names: [X-API-Key]`, `key_in_header: true`, `hide_credentials: true`. Consumers: `type: api-key` or `oauth` (with `custom_id` from the OIDC subject). Without an auth strategy a model is open to anyone who can reach the data plane.

## Policies

A policy is `{type, config, enabled, global}`. No parent reference with `global: true` applies to all AI traffic on the data plane; non-AI traffic is not affected. Entity-scoped: list it in the `policies` array of a model, agent, MCP server or consumer. One policy applies at exactly one scope; create it once and reference it in several entities to share it. Managed in the Konnect UI, the API (`/v1/ai-gateways/{aiGatewayId}/policies`) or kongctl (`ai_gateway_policies:`). Policy types mirror the plugin names (AI Rate Limiting Advanced, AI PII Sanitizer, AI Prompt Guard, logging, OpenTelemetry). Some policies call external services (the PII sanitizer needs a reachable anonymizer service; requests fail without it).

## Data plane

Local quickstart (`get.konghq.com/ai`), Helm (`kong/kong-ai-gateway`), Operator CRDs and plain Docker (`kong/kong-ai-gateway:2.2.0`) are in `references/install.md`. The data plane needs outbound access to Konnect (control and telemetry endpoints) and the providers.

## Discover

```bash
kongctl get ai-gateways 2>/dev/null || kongctl --help | head -30      # command names change between kongctl versions; read --help
kongctl config view 2>/dev/null | grep -i region
curl -s "https://${KONNECT_REGION:-us}.api.konghq.com/v1/ai-gateways" -H "Authorization: Bearer $KONNECT_TOKEN" | jq -r '.data[] | [.id,.name] | @tsv'
curl -s "https://${KONNECT_REGION:-us}.api.konghq.com/v1/ai-gateways/$AI_GATEWAY_ID/policies" -H "Authorization: Bearer $KONNECT_TOKEN" | jq -r '.data[] | [.name,.type,.global,.enabled] | @tsv'
```

The REST paths come from the policy docs and the Konnect AI Gateway API reference (`/api/konnect/ai-gateway/`); confirm the response shape there.
