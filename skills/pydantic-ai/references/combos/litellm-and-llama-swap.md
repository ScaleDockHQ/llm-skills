# Pydantic AI behind LiteLLM or llama-swap

> Verified against Pydantic AI v2.55.0 (docs: models/compatible-apis, models/anthropic), 2026-10-11

A gateway gives the app one URL, one key and stable aliases. Run it with the `litellm` skill (`npx skills add ScaleDockHQ/llms-skills --skill litellm`) or `llama-swap` (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).

```python
import os
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.litellm import LiteLLMProvider
model = OpenAIChatModel("coder", provider=LiteLLMProvider(
    api_base=os.environ["LLM_BASE_URL"], api_key=os.environ["LLM_API_KEY"]))     # virtual key scoped at the gateway
```

- **LiteLLM:** `LiteLLMProvider` sends Chat Completions to `api_base` as-is; it cannot reach an API that only LiteLLM can translate. For llama-swap or any other gateway use `OpenAIProvider(base_url=...)`.
- **Ids** are gateway aliases (`GET /v1/models`); changing the engine behind an alias needs no app change, but profile flags (system-message handling, thinking field) follow the engine.
- **System messages:** backends behind a gateway often use chat templates that accept one system message; set `openai_chat_supports_multiple_system_messages=False` if you see 400s.
- **Anthropic route:** `AnthropicProvider(api_key=..., base_url="https://llm.example.com")` when the gateway serves `/v1/messages`; use an `AsyncAnthropic` client for Bearer auth.
- **Per-app keys:** one virtual key per service; rotate by changing the env var.
- **Behind a tunnel or access proxy:** pass `default_headers` through your own `AsyncOpenAI` client; ensure SSE is not buffered.
