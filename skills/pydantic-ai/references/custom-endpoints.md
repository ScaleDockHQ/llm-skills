# Pydantic AI: custom endpoints

> Verified against Pydantic AI v2.55.0 (pydantic-ai-slim 2.55.0, docs: models/openai, models/compatible-apis, models/ollama, models/anthropic), 2026-10-11

Pick the model class by the API the endpoint serves, and the provider by the server.

| Endpoint serves                                          | Model class and provider                                  | Base URL shape                | Key option                       |
| -------------------------------------------------------- | --------------------------------------------------------- | ----------------------------- | -------------------------------- |
| Chat Completions (llama-server, llama-swap, any gateway) | `OpenAIChatModel` + `OpenAIProvider(base_url, api_key)`   | `http://host:port/v1`         | `api_key` (env `OPENAI_API_KEY`) |
| vLLM                                                     | `OpenAIChatModel` + `VLLMProvider(base_url, api_key)`     | `http://host:8000/v1`         | `VLLM_API_KEY`                   |
| Ollama                                                   | `OllamaModel` + `OllamaProvider(base_url, api_key)`       | `http://host:11434/v1`        | `OLLAMA_API_KEY`                 |
| LiteLLM proxy                                            | `OpenAIChatModel` + `LiteLLMProvider(api_base, api_key)`  | proxy root, as the docs show  | the LiteLLM key                  |
| Responses (`/v1/responses`)                              | `OpenAIResponsesModel` + `OpenAIProvider`                 | `http://host:port/v1`         | `api_key`                        |
| Anthropic Messages (`/v1/messages`)                      | `AnthropicModel` + `AnthropicProvider(api_key, base_url)` | `http://host:port` (no `/v1`) | `api_key`; Bearer via client     |

The bare `'openai:name'` string resolves to `OpenAIResponsesModel`; `'openai-chat:name'` resolves to `OpenAIChatModel`. Env-resolved strings exist for `'vllm:name'` (with `VLLM_BASE_URL`) and `'ollama:name'` (with `OLLAMA_BASE_URL`). Upstream: compatibility with one API does not imply the other, and `OpenAIProvider` selects an OpenAI profile from the model name whatever the `base_url`.

## Install

```bash
pip install pydantic-ai                       # Python 3.11+, all providers
pip install "pydantic-ai-slim[openai]"        # slim: OpenAI-compatible, vLLM, Ollama, LiteLLM
pip install "pydantic-ai-slim[anthropic]"     # slim: Anthropic Messages
```

## Base URLs per backend

| Backend                  | `OpenAIProvider` `base_url` | `AnthropicProvider` `base_url` | Notes                                                                          |
| ------------------------ | --------------------------- | ------------------------------ | ------------------------------------------------------------------------------ |
| vLLM `vllm serve`        | `http://host:8000/v1`       | `http://host:8000`             | Use `VLLMProvider`. Tools need `--enable-auto-tool-choice --tool-call-parser`. |
| llama.cpp `llama-server` | `http://host:8080/v1`       | `http://host:8080`             | Tool use needs `--jinja`. Key via `--api-key-file`.                            |
| Ollama                   | `http://host:11434/v1`      | `http://host:11434`            | Use `OllamaProvider`.                                                          |
| LiteLLM proxy            | `https://gw.example.com/v1` | `https://gw.example.com`       | Use `LiteLLMProvider`, or `OpenAIProvider` with the same URL.                  |
| llama-swap               | `http://host:8080/v1`       | `http://host:8080`             | Model ids are its config keys.                                                 |

Confirm the shape and ids: `curl -fsS "$BASE/models" -H "Authorization: Bearer $(cat ~/.config/llm/key)" | jq -r '.data[].id'`.

## OpenAI-compatible (llama-server, llama-swap, gateways)

```python
import os
from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.openai import OpenAIProvider

model = OpenAIChatModel(
    "coder",                                           # alias from /v1/models
    provider=OpenAIProvider(
        base_url=os.environ["LLM_BASE_URL"],           # e.g. http://gpu1:8080/v1
        api_key=os.environ.get("LLM_API_KEY", "none"), # non-empty for unauthenticated engines
    ),
)
agent = Agent(model)
print(agent.run_sync("ping").output)
```

`OpenAIProvider` also takes `http_client` (httpx) or a prebuilt `openai_client=AsyncOpenAI(...)` (then `base_url`, `api_key` and `http_client` must be unset). Env fallbacks: `OPENAI_BASE_URL`, `OPENAI_API_KEY`. Use the client route for custom headers (`default_headers=`), TLS roots and retry settings.

## vLLM

```python
from pydantic_ai.providers.vllm import VLLMProvider
model = OpenAIChatModel("Qwen/Qwen3-8B", provider=VLLMProvider(base_url="http://gpu1:8000/v1"))
```

`VLLMProvider` takes `base_url` (or `VLLM_BASE_URL`) and `api_key` (or `VLLM_API_KEY`). It merges multiple leading system messages by default because some vLLM chat templates reject them; opt out with an `OpenAIModelProfile(openai_chat_supports_multiple_system_messages=True)`. Use the name vLLM serves (`--served-model-name` or the repo id).

## Ollama

```python
from pydantic_ai.models.ollama import OllamaModel
from pydantic_ai.providers.ollama import OllamaProvider
model = OllamaModel("qwen3", provider=OllamaProvider(base_url="http://host:11434/v1"))
```

`OllamaModel` uses Ollama's Chat Completions API. Env: `OLLAMA_BASE_URL`, `OLLAMA_API_KEY` (required only for Ollama Cloud). Self-hosted Ollama 0.5.0 and later enforces `response_format` `json_schema`, so `NativeOutput` is schema-valid. Raise Ollama's context for agents (`OLLAMA_CONTEXT_LENGTH`, see the `ollama` skill).

## LiteLLM proxy

```python
from pydantic_ai.providers.litellm import LiteLLMProvider
model = OpenAIChatModel("coder", provider=LiteLLMProvider(api_base=os.environ["LLM_BASE_URL"], api_key=os.environ["LLM_API_KEY"]))
```

Requests go out as Chat Completions to `api_base` as-is; the model name is the proxy's alias (use the `custom/` prefix for custom LLMs per the docs). If a model rejects more than one leading system message (`System message must be at the beginning.`), set `openai_chat_supports_multiple_system_messages=False` on its profile.

## Responses endpoint

```python
from pydantic_ai.models.openai import OpenAIResponsesModel
model = OpenAIResponsesModel("alias", provider=OpenAIProvider(base_url=..., api_key=...))
```

Use only if the endpoint implements `/v1/responses`. Five settings (`seed`, `presence_penalty`, `frequency_penalty`, `logit_bias`, `stop_sequences`) reach OpenAI only through Chat Completions and are dropped on the Responses path.

## Anthropic Messages

```python
from pydantic_ai.models.anthropic import AnthropicModel
from pydantic_ai.providers.anthropic import AnthropicProvider

model = AnthropicModel("coder", provider=AnthropicProvider(
    api_key=os.environ["LLM_API_KEY"], base_url=os.environ["LLM_ANTHROPIC_URL"]))   # root URL, no /v1
```

`AnthropicProvider` reads `ANTHROPIC_API_KEY` if `api_key` is unset and raises when no key exists. For a gateway that wants `Authorization: Bearer`, build the SDK client yourself and pass it: `AnthropicProvider(anthropic_client=AsyncAnthropic(auth_token=..., base_url=...))`. The `AsyncAnthropic` client retries on its own (`max_retries=2`); set `max_retries=0` when you manage retries.

## Model profiles

A profile tells the model class how to shape requests: JSON-schema restrictions, strict tools, thinking fields, system-message handling, whether JSON-schema or JSON-object output is supported. Pass one for models Pydantic AI does not know:

```python
from pydantic_ai.profiles.openai import OpenAIModelProfile
model = OpenAIChatModel("coder", provider=OpenAIProvider(base_url=..., api_key=...),
    profile=OpenAIModelProfile(
        openai_chat_supports_multiple_system_messages=False,   # merge leading system messages
        openai_chat_thinking_field="reasoning",                # servers that return thinking in `reasoning`
        openai_chat_streaming_requires_finish_reason=True,     # raise if a stream ends without finish_reason
    ))
```

Profile fields documented upstream include `json_schema_transformer`, `openai_chat_supports_multiple_system_messages`, `openai_chat_supports_max_completion_tokens` (set `False` for servers that only accept `max_tokens`), `openai_chat_thinking_field`, `openai_chat_send_back_thinking_parts` and `openai_chat_streaming_requires_finish_reason` (default `False`). Check the profile API page for the installed version before relying on a field.

## Authentication without printing secrets

- Keys live in environment variables or a `0600` file; never commit them or log provider arguments.
- A stray real `OPENAI_API_KEY` or `OPENAI_BASE_URL` is used when you leave `api_key` or `base_url` unset; pass them explicitly.
- Service-token headers: build `AsyncOpenAI(default_headers=...)` and pass it as `openai_client`.

## Model-name mapping

The model name is sent verbatim (the profile lookup normalizes it only for feature detection). Use ids from `/v1/models`. Because `OpenAIProvider` picks an OpenAI profile from the name, avoid aliases that look like real OpenAI models, or set an explicit profile.

## Official links

- https://pydantic.dev/docs/ai/models/openai/
- https://pydantic.dev/docs/ai/models/compatible-apis/
- https://pydantic.dev/docs/ai/models/ollama/
- https://pydantic.dev/docs/ai/models/anthropic/
- https://pydantic.dev/docs/ai/models/overview/
- https://github.com/pydantic/pydantic-ai
