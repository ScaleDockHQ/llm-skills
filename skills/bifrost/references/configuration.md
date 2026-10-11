# Configuration

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/quickstart/gateway/provider-configuration>, <https://docs.getbifrost.ai/deployment-guides/config-json>, <https://docs.getbifrost.ai/deployment-guides/runtime-contract>. Schema: <https://www.getbifrost.ai/schema>.

## Three ways to configure

| Mode                    | When                                           | Behaviour                                                                                                           |
| ----------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| UI or API only          | no `config.json`                               | creates a SQLite config store; edits via UI and `/api` persist                                                      |
| DB-backed `config.json` | file exists, `config_store` omitted or enabled | file seeds or reconciles the store at startup; default `source_of_truth: "split"` keeps UI edits for unchanged rows |
| File-only               | `config_store.enabled: false`                  | everything loaded into memory; UI changes unavailable; restart to apply                                             |

Use file-only for GitOps. Always add `"$schema": "https://www.getbifrost.ai/schema"` for editor validation.

## Minimal config.json

See `assets/config.json`. Never write secrets into the file: reference them as `env.NAME` (Enterprise also supports `vault.<path>`):

```json
{
  "$schema": "https://www.getbifrost.ai/schema",
  "encryption_key": "env.BIFROST_ENCRYPTION_KEY",
  "providers": {
    "openai": {
      "keys": [
        {
          "name": "openai-primary",
          "value": "env.OPENAI_API_KEY",
          "models": ["*"],
          "weight": 1.0
        }
      ]
    }
  },
  "config_store": { "enabled": false }
}
```

Key names must be unique within a provider. `weight` splits traffic across keys.

## Providers through the API

```bash
curl -sS http://localhost:8080/api/providers -H 'Content-Type: application/json' -d '{
  "provider": "openai",
  "keys": [{ "name": "openai-key-1", "value": "env.OPENAI_API_KEY", "models": ["*"], "weight": 1.0 }]
}'
curl -sS http://localhost:8080/api/providers | jq .
```

With dashboard auth on, add admin credentials to admin calls (for example `-u "$BIFROST_ADMIN_USER:$BIFROST_ADMIN_PASSWORD"` from variables loaded out of a `0600` file).

## Self-hosted OpenAI-compatible servers

Register them as a custom provider with a base provider type:

```json
{
  "provider": "vllm-local",
  "keys": [
    { "name": "vllm-key-1", "value": "dummy", "models": ["*"], "weight": 1.0 }
  ],
  "network_config": {
    "base_url": "http://vllm-host:8000",
    "default_request_timeout_in_seconds": 60
  },
  "custom_provider_config": {
    "base_provider_type": "openai",
    "allowed_requests": {
      "chat_completion": true,
      "chat_completion_stream": true
    }
  }
}
```

Bifrost also lists first-class `vllm`, `ollama` and `sgl` providers; read `providers/supported-providers/` for the current list and options.

## Calling it

`model` is `provider/model` (for example `openai/<model>`); bare names resolve through the model catalog (`providers/provider-routing`). The API follows OpenAI format at `/v1/chat/completions`; Anthropic, Bedrock, GenAI and LiteLLM-shaped endpoints are under `/anthropic`, `/bedrock`, `/genai`, `/litellm` (see `integrations.md`).

## Process settings

Flags: `-port` (8080), `-host` (localhost for npx), `-log-level`, `-log-style`, `-app-dir`. Docker uses `APP_PORT`, `APP_HOST`, `APP_DIR`, `LOG_LEVEL`, `LOG_STYLE`. Also `GOMEMLIMIT` (about 90% of the container limit is the documented starting point), `BIFROST_ENCRYPTION_KEY`, `BIFROST_SETUP_TOKEN`. Application data under app-dir: `config.json`, `config.db`, `logs.db`.

`client` options such as `enable_logging` and `drop_excess_requests` are documented in `deployment-guides/config-json/client`.
