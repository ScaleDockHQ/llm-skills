# LlamaIndex behind LiteLLM or llama-swap

> Verified against LlamaIndex llama-index v0.14.25 (llama-index-llms-openai-like 0.8.1, llama-index-embeddings-openai-like 0.4.0), 2026-10-11

A gateway gives the app one URL, one key and stable aliases. Run it with the `litellm` skill (`npx skills add ScaleDockHQ/llms-skills --skill litellm`) or `llama-swap` (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).

```python
import os
from llama_index.llms.openai_like import OpenAILike
llm = OpenAILike(model="coder", api_base=os.environ["LLM_BASE_URL"],    # https://llm.example.com/v1
                 api_key=os.environ["LLM_API_KEY"],                      # virtual key scoped at the gateway
                 is_chat_model=True, is_function_calling_model=True, context_window=32768)
```

- **Ids** are gateway aliases (`GET /v1/models`); changing the engine behind an alias needs no app change, but update `context_window` and the capability flags to match.
- **Capability flags describe the weakest engine** an alias can route to; if fallbacks differ, declare the lowest common ability.
- **Embeddings** can use the same gateway through `OpenAILikeEmbedding`; give embedding aliases their own virtual-key budget.
- **Anthropic route:** `Anthropic(base_url="https://llm.example.com", api_key=...)` when the gateway serves `/v1/messages`.
- **Per-app keys:** one virtual key per service; rotate by changing the env var.
- **Behind a tunnel or access proxy:** `default_headers` for service tokens; ensure SSE is not buffered.
