# Cloudflare AI Gateway

Helps an agent set up and operate Cloudflare's hosted AI Gateway: create and authenticate a gateway, send traffic through the REST API or provider-native URLs, pay with BYOK keys or Unified Billing credits, cap cost with spend and rate limits, add caching, retries and dynamic routing, read logs, connect Claude Code and LiteLLM, and tear it down.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill cloudflare-ai-gateway
```

## Rules

- **Ask before cost or data decisions.** Credits, auto top-up, caching, payload logging, stored keys.
- **Never print tokens or keys.** Use environment variables or `0600` files.
- **Authenticate every gateway.** Tokens are account-scoped, so isolate tenants by account.
- **Watch the credential path.** No request key and no stored key means Unified Billing.
- **Treat spend limits as soft.** Enforcement is eventually consistent.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): tokens, gateways, BYOK, Unified Billing.
- [`references/endpoints-and-usage.md`](references/endpoints-and-usage.md): REST, provider-native, compat, binding, headers.
- [`references/controls.md`](references/controls.md): caching, limits, retries, dynamic routing.
- [`references/observability.md`](references/observability.md): logs, metadata, privacy.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): OpenAI SDK, Claude Code, LiteLLM.
- [`references/teardown.md`](references/teardown.md): delete and revoke.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `llm-gateway`, `litellm`: other gateway designs.
- `cloudflare-tunnel`: expose your own model servers.
- `llm-observability`, `cloud-llms`: tracing and provider choice.

## License

MIT
