# Anthropic API: LiteLLM and OpenAI-compatible clients

> Verified against LiteLLM Anthropic provider docs, Claude Platform docs: OpenAI SDK compatibility, API overview, 2026-10-11

## LiteLLM proxy entry (native Messages API)

The `anthropic/` prefix calls the native Messages API, so caching and thinking stay available. Read the key from the environment.

```yaml
model_list:
  - model_name: claude-main # alias your clients call
    litellm_params:
      model: anthropic/<pinned-model-id> # from GET /v1/models
      api_key: os.environ/ANTHROPIC_API_KEY
      max_budget: 50 # USD per budget_duration for this deployment
      budget_duration: 30d
```

```bash
export ANTHROPIC_API_KEY="$(cat ~/.config/llm/anthropic.key)"   # 0600 file, never printed
litellm --config config.yaml
```

- LiteLLM also documents workload identity federation for Anthropic (token file or internal issuer). A static `ANTHROPIC_API_KEY` outranks federation everywhere in the provider, so unset it when migrating. Admin-only for deployments using federation. Confirm in both products' docs.
- Use a dedicated service-account key, in a workspace used only by the gateway. If the key spans workspaces, set the `anthropic-workspace-id` header through LiteLLM's header settings (check LiteLLM docs for the parameter name).
- Fallbacks, budgets and routing: `llm-gateway` and `litellm` skills.
- Coding agents that speak the Messages API can talk to the gateway's `/v1/messages` route (see `llm-gateway`).

## Anthropic SDK

```python
import anthropic
client = anthropic.Anthropic()   # ANTHROPIC_API_KEY; add default_headers={"anthropic-workspace-id": "wrkspc_..."} if needed
```

Both the SDKs and `ant` also read `ANTHROPIC_AUTH_TOKEN` (bearer token) and `ANTHROPIC_API_KEY` wins when both are set.

## OpenAI SDK against Claude (testing only)

Base URL `https://api.anthropic.com/v1/`, key = Claude key, model = Claude model ID. Documented limits (ignored `strict`, `response_format`, no prompt caching, hoisted system messages) are in `references/api-and-sdks.md`. For production OpenAI-format access, put LiteLLM in front and keep native calls behind it.

## Health

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01"
```

No public health endpoint to poll; use the status page and gateway checks. See `llm-clients` and `llm-observability`.

## Where to read more

- https://docs.litellm.ai/docs/providers/anthropic
- https://platform.claude.com/docs/en/api/openai-sdk
