# Portkey with LiteLLM and clients

> Verified against Portkey AI Gateway v1.15.2 (README, src/globals.ts), docs.portkey.ai (messages-api, universal-api) and LiteLLM docs (openai_compatible, proxy/configs), 2026-10-11

## OpenAI SDK and curl

```python
from openai import OpenAI
client = OpenAI(
    base_url="http://127.0.0.1:8787/v1",
    api_key="<provider key from env, not literal>",
    default_headers={"x-portkey-provider": "openai"},
)
```

Per request config: `client.with_options(extra_headers={"x-portkey-config": json_string})`. For hosted: `base_url="https://api.portkey.ai/v1"`, header `x-portkey-api-key`, models as `@provider/model`.

## Portkey SDKs

`pip install portkey-ai`, `npm install portkey-ai`. For self-hosted point `base_url` at the gateway and pass `provider` and the provider key as `Authorization`:

```python
from portkey_ai import Portkey
client = Portkey(base_url="http://127.0.0.1:8787/v1", provider="openai", Authorization="<provider key from env>")
client = client.with_options(config={"retry": {"attempts": 3}})
```

Pin the SDK version you test with.

## LiteLLM in front of or behind Portkey

Use Portkey as an OpenAI-compatible upstream behind LiteLLM, so LiteLLM keeps virtual keys and budgets and Portkey adds config routing:

```yaml
model_list:
  - model_name: coder
    litellm_params:
      model: openai/<model> # openai/ prefix routes as an OpenAI-compatible endpoint
      api_base: http://127.0.0.1:8787/v1
      api_key: os.environ/OPENAI_API_KEY # forwarded to the provider by Portkey
      extra_headers: { "x-portkey-provider": "openai" }
```

LiteLLM documents `extra_headers` in `litellm_params` and the `openai/` prefix for custom OpenAI-compatible endpoints. Retries and fallbacks live in both layers: pick one owner (see `litellm` skill). A static `x-portkey-config` string can go in `extra_headers` too, which embeds provider keys in LiteLLM's config, so keep that file `0600` and out of git.

## Claude Code and Anthropic SDK

`/v1/messages` is supported by the gateway (open source and hosted). Point `ANTHROPIC_BASE_URL` at the gateway root without `/v1` (`http://127.0.0.1:8787`) and send gateway headers through the client's custom-header mechanism (`ANTHROPIC_CUSTOM_HEADERS` in Claude Code). Hosted Portkey documents Claude Code integration and a Portkey CLI that sets up gateway routing; read https://portkey.ai/docs/integrations/libraries/claude-code. Confirm the headers reach the gateway before trusting results (`x-portkey-last-used-option-index` in the response).

## Agent frameworks

Portkey documents Autogen, CrewAI, LangChain, LlamaIndex and others, all via the OpenAI-compatible base URL or the Portkey SDK. Features that depend on the hosted app (logging, prompt management) show as "available on the hosted app".

## Smoke test

```bash
curl -fsS http://127.0.0.1:8787/v1/chat/completions \
  -H "x-portkey-provider: openai" -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"Reply OK"}],"max_tokens":8,"stream":true}' | head -5
```
