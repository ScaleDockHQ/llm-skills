# SambaNova with LiteLLM, OpenAI clients and coding tools

> Verified against LiteLLM provider page (docs.litellm.ai/docs/providers/sambanova), SambaNova OpenAI and Anthropic compatibility pages, docs index of integrations, 2026-10-11

## LiteLLM SDK

Prefix `sambanova/`, env var `SAMBANOVA_API_KEY`. LiteLLM documents chat, streaming, tool calling, vision (`Llama-4-Maverick...` in its example, now retired), structured output (`json_schema`) and embeddings.

```python
from litellm import completion
r = completion(model="sambanova/gpt-oss-120b", messages=[{"role": "user", "content": "Hello"}], max_tokens=64)
```

LiteLLM's own examples use older model IDs. Use IDs from `GET /v1/models`.

## LiteLLM proxy

```yaml
model_list:
  - model_name: samba-gpt-oss
    litellm_params:
      model: sambanova/gpt-oss-120b
      api_key: os.environ/SAMBANOVA_API_KEY
      rpm: 40 # keep below the tier RPM from the rate-limits page
```

Validate:

```bash
curl -sS http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"samba-gpt-oss","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq .usage
```

Add a second deployment (another provider) under the same `model_name` for failover. Gateway and fallback design: `llm-gateway`, `litellm`, `cloud-llms`.

## OpenAI-compatible tools

| Field    | Value                         |
| -------- | ----------------------------- |
| Base URL | `https://api.sambanova.ai/v1` |
| API key  | `SAMBANOVA_API_KEY`           |
| Model    | exact ID from `/v1/models`    |

## Anthropic-protocol tools (Claude Code and similar)

SambaNova exposes `POST /v1/messages`. Point the tool at SambaNova with environment variables:

```bash
export ANTHROPIC_BASE_URL="https://api.sambanova.ai/v1"   # per the Anthropic compatibility page
export ANTHROPIC_API_KEY="$(cat ~/.config/sambanova.key)"
```

The SambaNova Claude Code integration page (https://docs.sambanova.ai/docs/en/integrations/claude-code.md) is the authority for that tool's variable names and model mapping. If the tool appends `/v1/messages` itself and you get 404, drop the trailing `/v1` from the base URL. Use a SambaNova model ID, not a Claude name.

## Other integrations

The docs list integrations for Cursor, Cline, Continue, Codex, Kilo Code and many frameworks under `https://docs.sambanova.ai/docs/en/integrations/`. Check each page for current settings.

## Official links

- LiteLLM: https://docs.litellm.ai/docs/providers/sambanova
- Integrations index: https://docs.sambanova.ai/docs/llms.txt
