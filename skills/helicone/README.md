# Helicone

Helps an agent use Helicone, the open-source LLM observability platform and OpenAI-compatible AI gateway: send traffic through `ai-gateway.helicone.ai`, choose credits or BYOK, add sessions, properties and user ids, use caching, rate limits and provider routing, self-host with Docker, wire LiteLLM, and migrate away. Helicone has been in maintenance mode since Mintlify acquired it in March 2026, and the skill says so up front.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill helicone
```

## Rules

- **State the maintenance status** before recommending a new adoption.
- **Never print keys or put them in URLs.**
- **Ask before credits, caching or body logging.**
- **Change self-hosted default secrets** before exposure.
- **Plan an exit** for long-lived systems.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): keys, credits vs BYOK.
- [`references/gateway-and-routing.md`](references/gateway-and-routing.md): model strings and failover.
- [`references/features.md`](references/features.md): sessions, cache, rate limits, headers.
- [`references/self-hosting.md`](references/self-hosting.md): Docker and security.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM and SDKs.
- [`references/migration.md`](references/migration.md): leaving Helicone.
- [`references/teardown.md`](references/teardown.md): delete and revoke.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `litellm`, `bifrost`, `llm-gateway`: gateways.
- `langfuse`, `llm-observability`: tracing.

## License

MIT
