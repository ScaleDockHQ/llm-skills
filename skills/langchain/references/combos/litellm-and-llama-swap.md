# LangChain behind LiteLLM or llama-swap

> Verified against LangChain langchain v1.4.4 (langchain-openai 1.7.0, langchain-litellm 0.11.0), 2026-10-11

A gateway gives the app one URL, one key and stable aliases. Run it with the `litellm` skill (`npx skills add ScaleDockHQ/llms-skills --skill litellm`) or `llama-swap` (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).

```python
import os
from langchain_openai import ChatOpenAI
llm = ChatOpenAI(model="coder", base_url=os.environ["LLM_BASE_URL"],   # https://llm.example.com/v1
                 api_key=os.environ["LLM_API_KEY"], stream_usage=True)  # virtual key scoped at the gateway
```

- **Ids** are gateway aliases (`GET /v1/models`); changing the engine behind an alias needs no app change.
- **Anthropic route:** `ChatAnthropic(base_url="https://llm.example.com", api_key=...)` when the gateway serves `/v1/messages`.
- **`ChatOpenAI` vs `ChatLiteLLM`:** `ChatLiteLLM` (`langchain-litellm`) embeds the LiteLLM SDK in your process and needs provider keys locally; to use a gateway you already run, `ChatOpenAI` with its URL is simpler and keeps keys server-side. `ChatLiteLLMRouter` wraps LiteLLM's Router for in-process fallbacks.
- **Non-standard fields** (reasoning content from the gateway) are dropped by `ChatOpenAI`, as for any server.
- **Per-app keys:** one virtual key per service; rotate by changing the env var.
- **Behind a tunnel or access proxy:** `default_headers` for service tokens; ensure SSE is not buffered.
