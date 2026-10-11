# OpenCode with LiteLLM in front of local engines

> Verified against OpenCode v1.19.0 and LiteLLM v1.105.0 (docs: providers, config; anthropic_unified, response_api), 2026-10-11

Use when you want one key and one URL for several engines, budgets and logs. Gateway install, keys and Postgres are the `litellm` skill.

## Gateway side (summary)

```yaml
model_list:
  - model_name: coder
    litellm_params:
      model: openai/qwen3-coder
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/ENGINE_API_KEY
  - model_name: small
    litellm_params:
      model: openai/qwen3-small
      api_base: http://127.0.0.1:8081/v1
litellm_settings:
  drop_params: true # drop parameters a backend does not support
```

## OpenCode side

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LiteLLM",
      "options": {
        "baseURL": "http://GATEWAY:4000/v1",
        "apiKey": "{env:LITELLM_API_KEY}",
        "chunkTimeout": 600000
      },
      "models": {
        "coder": {
          "name": "Coder",
          "limit": { "context": 131072, "output": 16384 },
          "tool_call": true
        },
        "small": {
          "name": "Small",
          "limit": { "context": 32768, "output": 4096 },
          "tool_call": true
        }
      }
    }
  },
  "model": "litellm/coder",
  "small_model": "litellm/small"
}
```

```bash
export LITELLM_API_KEY="$(cat ~/.config/llm/litellm-key)"
OPENCODE_BASE_URL=http://GATEWAY:4000/v1 OPENCODE_KEY_ENV=LITELLM_API_KEY OPENCODE_MODEL=coder scripts/check-endpoint.sh
```

## Pitfalls

- Model keys are LiteLLM `model_name` aliases, not the backend names.
- Variant options (`reasoningEffort`, `reasoningSummary`) can be rejected by chat backends; keep `drop_params: true` or avoid variants.
- Do not buffer SSE at a reverse proxy; raise `chunkTimeout` for cold model loads.
- One virtual key per developer for attribution and revocation; each in a `0600` file or secret manager.
