# LiteLLM and clients

> Verified against Helicone docs (gateway integrations) and LiteLLM docs, 2026-10-11

Sources: <https://docs.helicone.ai/gateway/integrations/litellm>, <https://docs.helicone.ai/gateway/integrations/overview>, <https://docs.helicone.ai/gateway/integrations/vercel-ai-sdk>.

## OpenAI SDK

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://ai-gateway.helicone.ai", api_key=os.environ["HELICONE_API_KEY"])
client.chat.completions.create(
    model="<model-id>", messages=[{"role": "user", "content": "ping"}],
    extra_headers={"Helicone-Session-Id": "demo-1", "Helicone-Property-Environment": "dev"},
)
```

## LiteLLM

Per the Helicone docs, the LiteLLM SDK sends traffic through Helicone when the model name has a `helicone/` prefix and `HELICONE_API_KEY` is set:

```python
from litellm import completion
completion(model="helicone/<model-id>", messages=[{"role": "user", "content": "ping"}])
```

For a LiteLLM proxy, use an OpenAI-compatible upstream pointing at the gateway with the key from the environment:

```yaml
model_list:
  - model_name: helicone-model
    litellm_params:
      model: openai/<model-id>
      api_base: https://ai-gateway.helicone.ai
      api_key: os.environ/HELICONE_API_KEY
```

Use `litellm` for the proxy side: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.

## Other clients

Docs cover Claude Agent SDK, LangChain, LangGraph, DSPy, Langfuse, OpenAI Agents, PostHog, Semantic Kernel and Vercel AI SDK under `gateway/integrations/`. Older per-provider integrations (separate proxy hosts per provider) are marked legacy; avoid ones that put the API key in the URL path, such as the Claude Code legacy page.
