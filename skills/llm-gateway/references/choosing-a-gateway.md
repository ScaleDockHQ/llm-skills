# Choosing a gateway

> Verified against LiteLLM v1.105.0, Portkey gateway v1.15.2, Agent Router (formerly Envoy AI Gateway) v1.2.0, Kong AI Gateway docs, Cloudflare AI Gateway docs, OpenRouter docs, Vercel AI Gateway docs, Bifrost v2.2.6, Helicone docs, 2026-10-11

## What a gateway is and when to choose one

A gateway sits between clients and model backends. It gives you one base URL, one auth scheme, stable model names, per-consumer keys and budgets, retries and fallbacks, and usage logs. It also translates between API shapes (OpenAI chat completions, OpenAI Responses, Anthropic Messages), which is often the real reason to deploy one.

Skip the gateway when one client talks to one backend that already speaks the client's API. Add one as soon as you have two backends, shared credentials, spend limits, or a client/backend API mismatch.

## Options at a glance

| Gateway                                  | Hosting                                                                | Strengths                                                                                                                                              | Weak spots                                                                                                                                                                 | Choose when                                                                               |
| ---------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| LiteLLM proxy                            | Self-hosted (Docker, Helm, Terraform)                                  | 100+ providers, OpenAI + Anthropic + Responses endpoints with bridging, virtual keys, teams, budgets, spend tracking in Postgres, Admin UI, Prometheus | Weekly release cadence means frequent upgrades; Python runtime; many features, some enterprise-gated                                                                       | Default for self-hosted stacks mixing local engines and cloud APIs                        |
| OpenRouter                               | Hosted SaaS                                                            | Huge model catalog behind one key, OpenAI-compatible `/api/v1`, Anthropic-compatible base for Claude Code, Responses API, provider routing             | Cannot reach your private backends; per-token margin; data leaves your network                                                                                             | No ops wanted and all models are public cloud models; also a good upstream behind LiteLLM |
| Portkey gateway                          | Self-hosted OSS (`npx @portkey-ai/gateway`, Docker) or hosted          | Lightweight, configs for retries, fallbacks, load balancing, many built-in guardrails, local console on port 8787                                      | Keys, budgets and analytics mostly in the hosted product                                                                                                                   | You want guardrails and routing configs in a small Node service                           |
| Agent Router (formerly Envoy AI Gateway) | Kubernetes (Envoy Gateway CRDs), or `aigw run` standalone on port 1975 | Envoy data plane, CRD-based routing (`AIGatewayRoute`, `AIServiceBackend`), token rate limits, two-tier pattern for self-hosted inference, MCP routing | Kubernetes and Envoy expertise required; heavier to start                                                                                                                  | Platform team already runs Envoy Gateway on Kubernetes                                    |
| Kong AI Gateway                          | Kong Gateway data plane, managed via Konnect                           | AI Model and AI Model Provider entities (2.x), prompt guard, semantic plugins, enterprise governance                                                   | Many AI features need Konnect or an enterprise license; v1 AI Proxy plugins being replaced                                                                                 | Organization already standardised on Kong                                                 |
| Cloudflare AI Gateway                    | Hosted at the edge                                                     | Caching, rate limiting, logging and analytics for cloud providers, provider-native and unified endpoints                                               | Cannot reach private backends without tunnels; unified OpenAI-compat `/compat/chat/completions` endpoint marked deprecated for single-model chat in favour of the REST API | Cloud-only traffic, existing Cloudflare account, want observability with near-zero setup  |
| Vercel AI Gateway                        | Hosted                                                                 | One OpenAI-, Anthropic- and AI SDK-compatible endpoint, provider routing and fallbacks, BYOK, budgets, zero data retention                             | Cannot reach private backends; best fit for Vercel and AI SDK stacks                                                                                                       | Cloud-only traffic on Vercel, want budgets and routing with no infrastructure             |
| Bifrost                                  | Self-hosted (Docker, `npx @maximhq/bifrost`)                           | Go binary with web UI, virtual keys, budgets, fallbacks, semantic cache, MCP                                                                           | Governance state split between config file and database; OSS is single-node                                                                                                | You want a fast self-hosted alternative to LiteLLM with a UI                              |
| Helicone                                 | Hosted or self-hosted                                                  | Observability with logging, cost tracking and a model-string gateway                                                                                   | In maintenance mode since March 2026; do not start new projects on it                                                                                                      | You already run it; see the skill for migration                                           |

## How each plugs into the stack

- **LiteLLM**: port 4000; `/v1/chat/completions`, `/v1/responses`, `/v1/messages`, `/v1/embeddings`, `/v1/models`; health at `/health/liveliness` and `/health/readiness`; Bearer auth with master or virtual keys. See `litellm-setup.md`. Depth: install the `litellm` skill (`npx skills add ScaleDockHQ/llms-skills --skill litellm`).
- **OpenRouter**: base `https://openrouter.ai/api/v1` for OpenAI clients; Claude Code uses `ANTHROPIC_BASE_URL=https://openrouter.ai/api` with `ANTHROPIC_AUTH_TOKEN` and an explicitly empty `ANTHROPIC_API_KEY` (per OpenRouter's Claude Code guide).
- **Portkey**: OpenAI-compatible at `http://localhost:8787/v1`; provider chosen per request via headers or a saved config.
- **Agent Router**: OpenAI-compatible at `http://localhost:1975/v1` in standalone mode; on Kubernetes, through the Envoy Gateway listener you define. Resource names and the `aigw` CLI kept their Envoy AI Gateway names.
- **Kong**: routes and AI Model entities you define on the Kong data plane.
- **Cloudflare**: `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/...` per provider, or `/compat` for the unified OpenAI shape.

## Per-gateway skills

Each gateway below has its own skill with install, configuration, operations and troubleshooting. Install with the command shown.

- litellm: `npx skills add ScaleDockHQ/llms-skills --skill litellm`
- openrouter: `npx skills add ScaleDockHQ/llms-skills --skill openrouter`
- portkey: `npx skills add ScaleDockHQ/llms-skills --skill portkey`
- envoy-ai-gateway: `npx skills add ScaleDockHQ/llms-skills --skill envoy-ai-gateway`
- kong-ai-gateway: `npx skills add ScaleDockHQ/llms-skills --skill kong-ai-gateway`
- cloudflare-ai-gateway: `npx skills add ScaleDockHQ/llms-skills --skill cloudflare-ai-gateway`
- vercel-ai-gateway: `npx skills add ScaleDockHQ/llms-skills --skill vercel-ai-gateway`
- bifrost: `npx skills add ScaleDockHQ/llms-skills --skill bifrost`
- helicone: `npx skills add ScaleDockHQ/llms-skills --skill helicone`

## Patterns that work

- **LiteLLM in front of everything**: local engine (or llama-swap) plus cloud providers plus OpenRouter as one more upstream. Clients see one URL and stable aliases.
- **Hosted only**: OpenRouter or Cloudflare directly, no self-hosting, when every model is public cloud.
- **Two tiers**: a platform gateway (Envoy, Kong) for org-wide auth and quotas, LiteLLM or the engine router behind it for model-level routing. Only worth it at org scale.

## Known pitfalls

- A hosted gateway cannot see `127.0.0.1` or LAN backends; you need a tunnel and auth in front of the backend.
- Gateways that do not forward Anthropic `anthropic-beta` headers or that buffer SSE break Claude Code features and streaming.
- Translating Anthropic Messages to an OpenAI-only backend loses features (prompt caching semantics, some thinking fields). Test the features you rely on.
- Two sources of truth for models (config file and database or UI) drift. Pick one.

## Official links

- LiteLLM proxy docs: https://docs.litellm.ai/docs/simple_proxy
- LiteLLM releases: https://github.com/BerriAI/litellm/releases
- OpenRouter quickstart: https://openrouter.ai/docs/quickstart
- OpenRouter with Claude Code: https://openrouter.ai/docs/cookbook/coding-agents/claude-code-integration
- Portkey gateway: https://github.com/Portkey-AI/gateway
- Agent Router (formerly Envoy AI Gateway): https://github.com/theagentrouter/agent-router and https://theagentrouter.ai/docs
- Kong AI Gateway: https://developer.konghq.com/ai-gateway/
- Cloudflare AI Gateway: https://developers.cloudflare.com/ai-gateway/
