# Integrations and migration

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/integrations/what-is-an-integration>, `/integrations/openai-sdk/overview`, `/integrations/anthropic-sdk/overview`, `/integrations/litellm-sdk`, `/cli-agents/claude-code`, `/migration-guides/litellm`.

## Drop-in endpoints

| Client                      | Base URL on a local gateway                                 |
| --------------------------- | ----------------------------------------------------------- |
| OpenAI SDK                  | `http://localhost:8080/openai` (or `/v1` on the native API) |
| Anthropic SDK, Claude Code  | `http://localhost:8080/anthropic`                           |
| LiteLLM SDK                 | `http://localhost:8080/litellm`                             |
| Bedrock Converse and Invoke | `/bedrock`                                                  |
| Google GenAI                | `/genai`                                                    |

Confirm the exact path for your SDK on its integration page. Virtual keys go in the provider's usual key header.

## Claude Code

```bash
export ANTHROPIC_BASE_URL="http://localhost:8080/anthropic"
export ANTHROPIC_AUTH_TOKEN="$(cat ~/.config/bifrost-vk)"   # a virtual key, if enforcement is on
```

Use `ANTHROPIC_AUTH_TOKEN` (recommended; sent as `Authorization: Bearer`) or `ANTHROPIC_CUSTOM_HEADERS="x-bf-vk: <key>"`. If `settings.json` has a `model` field, remove it; it overrides env-based model selection. Model aliases such as `ANTHROPIC_DEFAULT_SONNET_MODEL` can point at any `provider/model` Bifrost serves.

## LiteLLM SDK applications

```python
from litellm import completion
completion(model="<model>", messages=[{"role": "user", "content": "hi"}], base_url="http://localhost:8080/litellm")
```

Works only for providers both LiteLLM and Bifrost support.

## Migrating a LiteLLM proxy

```bash
DRY_RUN=1 npx @maximhq/bifrost-migration-cli      # plan only, writes nothing
```

It reads the LiteLLM management API, its `config.yaml` and optionally its Postgres (the API masks secrets), then recreates models, providers and keys, organizations (as customers), teams, users and virtual keys through Bifrost's API. It is idempotent (HTTP 409 counts as success) and fault tolerant. See the migration page for the environment variables it needs and review the dry-run report before the real run. Use `litellm` for the source side.

## Other clients

Cursor, Codex CLI, Gemini CLI, Qwen Code, OpenCode, Zed, Roo Code, Open WebUI, LibreChat and GitHub Copilot have pages under `cli-agents/`. LangChain and Pydantic AI have drop-in pages under `integrations/`.
