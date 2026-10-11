# LangChain: custom endpoints

> Verified against LangChain langchain v1.4.4 (langchain-core 1.6.9, langchain-openai 1.7.0, langchain-anthropic 1.7.5, langchain-ollama 1.1.0, langchain-litellm 0.11.0), 2026-10-11

Pick the class by the API the endpoint serves.

| Endpoint serves                                                          | Class (package)                         | Base URL shape                    | Key option                                               |
| ------------------------------------------------------------------------ | --------------------------------------- | --------------------------------- | -------------------------------------------------------- |
| Chat Completions (vLLM, llama-server, LiteLLM, llama-swap, Ollama `/v1`) | `ChatOpenAI` (`langchain-openai`)       | `http://host:port/v1`             | `api_key` (env `OPENAI_API_KEY`)                         |
| Anthropic Messages (`/v1/messages`)                                      | `ChatAnthropic` (`langchain-anthropic`) | `http://host:port` (**no** `/v1`) | `api_key` (env `ANTHROPIC_API_KEY`) or `default_headers` |
| Ollama native `/api`                                                     | `ChatOllama` (`langchain-ollama`)       | `http://host:11434`               | `client_kwargs={"headers": {...}}`                       |
| LiteLLM SDK as the client library                                        | `ChatLiteLLM` (`langchain-litellm`)     | LiteLLM provider settings         | LiteLLM provider env vars                                |

Upstream says custom `base_url` with `ChatOpenAI` is for "basic chat functionality" against Chat Completions-compatible endpoints, and that `ChatOpenAI` targets the official OpenAI spec only.

## Install

```bash
pip install -U langchain langchain-openai        # Python 3.10+
pip install -U langchain-anthropic               # only for /v1/messages
pip install -U langchain-ollama                  # only for native Ollama
```

## Base URLs per backend

| Backend                  | `ChatOpenAI` `base_url`     | `ChatAnthropic` `base_url` | Notes                                                             |
| ------------------------ | --------------------------- | -------------------------- | ----------------------------------------------------------------- |
| vLLM `vllm serve`        | `http://host:8000/v1`       | `http://host:8000`         | Tools need `--enable-auto-tool-choice --tool-call-parser <name>`. |
| llama.cpp `llama-server` | `http://host:8080/v1`       | `http://host:8080`         | Tool use needs `--jinja`. Key via `--api-key-file`.               |
| Ollama                   | `http://host:11434/v1`      | `http://host:11434`        | Native `ChatOllama` uses `http://host:11434`.                     |
| LiteLLM proxy            | `https://gw.example.com/v1` | `https://gw.example.com`   | Model ids are `model_name` aliases.                               |
| llama-swap               | `http://host:8080/v1`       | `http://host:8080`         | Model ids are its config keys.                                    |

Confirm the shape and ids from the endpoint: `curl -fsS "$BASE/models" -H "Authorization: Bearer $(cat ~/.config/llm/key)" | jq -r '.data[].id'`.

## ChatOpenAI

```python
import os
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="coder",                                   # alias from /v1/models
    base_url=os.environ["LLM_BASE_URL"],             # e.g. http://gpu1:8000/v1
    api_key=os.environ.get("LLM_API_KEY", "none"),   # non-empty string for unauthenticated engines
    stream_usage=True,                               # off by default when a custom base URL is set
    temperature=0,
    # extra_body={"chat_template_kwargs": {"enable_thinking": False}},   # server-specific fields
    # default_headers={"CF-Access-Client-Id": ...},
)
```

Resolution order for the base URL (first match wins): explicit `base_url` or `openai_api_base`; env `OPENAI_API_BASE`; env `OPENAI_BASE_URL` (read by the underlying `openai` SDK). When a base URL is set from any of them, `stream_usage` is not enabled by default.

- `use_responses_api=True` sends `/v1/responses`; leave it unset for chat-only endpoints. `ChatOpenAI` also routes to Responses automatically when you use Responses-only features such as built-in tools or reasoning summaries.
- `extra_body` passes vendor fields (upstream examples: LM Studio `ttl`, vLLM `use_beam_search`). Confirm the server honors them.
- `http_client` and `http_async_client` let you set TLS roots or proxies; `openai_proxy` sets a proxy. For a private CA prefer `SSL_CERT_FILE=/path/ca.pem` or `httpx.Client(verify="/path/ca.pem")`; do not disable verification.

## ChatAnthropic

```python
import os
from langchain_anthropic import ChatAnthropic

claude = ChatAnthropic(
    model="coder",
    base_url=os.environ["LLM_ANTHROPIC_URL"],        # http://gw:4000  (root, no /v1)
    api_key=os.environ["LLM_API_KEY"],               # sent as x-api-key
    max_tokens=1024,
)
```

Base URL falls back to env `ANTHROPIC_API_URL`, then `ANTHROPIC_BASE_URL`. For gateways that want `Authorization: Bearer`, pass `default_headers={"Authorization": "Bearer " + os.environ["LLM_API_KEY"]}`; the package's own error message names that as the way to supply non-key credentials. Confirm which header the gateway checks with `scripts/probe.sh anthropic`.

## ChatOllama

```python
from langchain_ollama import ChatOllama
llm = ChatOllama(model="qwen3:8b", base_url="http://host:11434", num_ctx=16384,
                 client_kwargs={"headers": {"Authorization": "Bearer " + os.environ["OLLAMA_PROXY_KEY"]}})
```

`base_url` also supports `http://user:pass@host` userinfo, which upstream warns is insecure. Use `client_kwargs` headers instead. Use the exact tag from `ollama list`.

## init_chat_model

```python
from langchain.chat_models import init_chat_model
model = init_chat_model(model="coder", model_provider="openai",
                        base_url=os.environ["LLM_BASE_URL"], api_key=os.environ["LLM_API_KEY"])
```

This is the documented way to use one config path for any OpenAI-compatible provider. Pass `profile={...}` for models LangChain does not know (see below).

## Authentication without printing secrets

- Keys live in environment variables or a `0600` file (`api_key=Path("~/.config/llm/key").expanduser().read_text().strip()`); never commit them.
- Do not print the model object with secrets enabled; LangChain stores keys as `SecretStr`, so `repr(llm)` hides them, but logging your own config dict does not.
- A stray real `OPENAI_API_KEY` is sent to whatever `base_url` you set; set `api_key` explicitly for self-hosted endpoints.
- `LANGSMITH_GATEWAY` and `LANGSMITH_GATEWAY_API_KEY` act as fallback base URL and key for `ChatOpenAI` and `ChatAnthropic`; an explicit `base_url` or `api_key` always wins, so pass them.

## Model-name mapping and profiles

The `model` string is sent verbatim; use ids from `/v1/models`. LangChain model profiles (`model.profile`, from models.dev data) describe context size and capabilities by known names; custom aliases have none, so features that depend on them (such as automatic structured-output strategy selection and summarization limits) cannot see your model's real limits. Supply one:

```python
model = init_chat_model("coder", model_provider="openai", base_url=..., api_key=...,
                        profile={"max_input_tokens": 65536, "tool_calling": True, "structured_output": True})
```

Keep gateway aliases neutral rather than copying real vendor model names.

## Reasoning content

`ChatOpenAI` does not extract or preserve `reasoning_content`, `reasoning` or `reasoning_details` from third-party servers. If you need it: serve the model so thinking is stripped by the engine's reasoning parser (it then arrives separately and is dropped, harmlessly), call the endpoint with the `openai` SDK for the raw field, or use a provider package. `ChatOllama` has a `reasoning` option for native Ollama.

## JavaScript note

For LangChain.js, `@langchain/openai` takes `new ChatOpenAI({ model, apiKey, configuration: { baseURL, defaultHeaders } })`; `configuration` accepts the OpenAI SDK's client options. Python behavior in this skill does not carry over automatically.

## Official links

- https://docs.langchain.com/oss/python/integrations/chat
- https://docs.langchain.com/oss/python/integrations/chat/openai
- https://docs.langchain.com/oss/python/integrations/chat/anthropic
- https://docs.langchain.com/oss/python/integrations/chat/ollama
- https://docs.langchain.com/oss/python/integrations/chat/vllm
- https://docs.langchain.com/oss/python/integrations/chat/litellm
- https://docs.langchain.com/oss/python/langchain/models
- https://docs.langchain.com/oss/javascript/integrations/chat/openai

## Starter snippet

```python
import os
from langchain.chat_models import init_chat_model

def get_llm(alias=None):
    return init_chat_model(
        model=alias or os.environ.get("LLM_MODEL", "coder"),
        model_provider="openai",
        base_url=os.environ["LLM_BASE_URL"],            # e.g. http://gpu1:8000/v1
        api_key=os.environ.get("LLM_API_KEY", "none"),  # non-empty for unauthenticated engines
        stream_usage=True,
        temperature=0,
        profile={"max_input_tokens": int(os.environ.get("LLM_CONTEXT", "32768")), "tool_calling": True},
    )
```
