# LangChain: structured output, tools and streaming

> Verified against LangChain langchain v1.4.4 (langchain-core 1.6.9, langchain-openai 1.7.0), 2026-10-11

Self-hosted models differ from hosted ones in three ways: JSON enforcement depends on the engine, tool calls depend on a server-side parser, and streamed usage is opt-in.

## Structured output

```python
from pydantic import BaseModel
class Weather(BaseModel):
    city: str
    temp_c: float

structured = llm.with_structured_output(Weather)                       # ChatOpenAI default: method="json_schema"
structured = llm.with_structured_output(Weather, method="function_calling")   # via tool calling
structured = llm.with_structured_output(Weather, method="json_mode")          # prompt must describe the shape
```

`ChatOpenAI.with_structured_output` accepts `method` of `function_calling`, `json_mode` or `json_schema`; for `ChatOpenAI` the default is `json_schema` (OpenAI's structured outputs API). Choose by what the engine enforces:

- `json_schema`: needs the engine to honor `response_format: json_schema` (vLLM, recent llama-server and Ollama do; check with `scripts/probe.sh openai`, line `json_schema`). If it ignores the field you get prose and a parse error.
- `function_calling`: works wherever tool calling works; the safest first choice for custom endpoints with a tool parser.
- `json_mode`: only valid JSON, no schema; put the schema in the prompt.
- `include_raw=True` returns the raw message and the parse error instead of raising.
- `strict=True` is OpenAI-specific and requires a schema without optional (defaulted) fields; leave off for self-hosted servers.

## Agents and response_format

```python
from langchain.agents import create_agent
from langchain.agents.structured_output import ToolStrategy, ProviderStrategy

agent = create_agent(model=llm, tools=[get_weather], response_format=ToolStrategy(Weather))
```

Passing a schema type directly auto-selects `ProviderStrategy` when the model profile says native structured output is supported, otherwise `ToolStrategy`. For custom aliases choose explicitly: `ToolStrategy` needs only tool calling, `ProviderStrategy` needs `json_schema` support. JSON Schema dicts must be wrapped in an explicit strategy. `ProviderStrategy(strict=...)` needs `langchain>=1.2`.

## Tool calling

```python
from langchain_core.tools import tool

@tool
def get_weather(city: str) -> str:
    """Weather by city."""
    return f"{city}: 18C"

llm_t = llm.bind_tools([get_weather])
resp = llm_t.invoke("Weather in Paris? Use the tool.")
resp.tool_calls                                      # [] means the engine returned plain text
```

- LangChain sends OpenAI `tools`; the engine must parse model output into `tool_calls`: vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama-server `--jinja`, Ollama models whose template supports tools. Otherwise `tool_calls` is empty and the JSON sits in `content`.
- Forcing a tool with `tool_choice` is not supported by every server; if it returns 400, drop it.
- `bind_tools(..., strict=True)` is OpenAI-specific; skip it on self-hosted engines.
- Small models call tools unreliably: fewer tools, short descriptions, one test per alias.
- Async tools and built-in tools (web search and similar) are Responses-API features of OpenAI, not of self-hosted engines.

## Streaming

```python
for chunk in llm.stream("Write a haiku."):
    print(chunk.content, end="", flush=True)
last = None
for chunk in llm.stream("hi"):
    last = chunk if last is None else last + chunk
print(last.usage_metadata)        # populated only with stream_usage=True and server support
```

- `stream_usage` defaults off with a custom base URL; set `stream_usage=True` so an extra chunk with usage metadata arrives, and make sure the engine honors `stream_options.include_usage`.
- `astream` and `astream_events` are the async forms; run long streams with a timeout (`timeout=` on the model) and `max_retries=` low so a slow local model is not re-sent.
- Proxies that buffer SSE (Nginx without `proxy_buffering off`) deliver one late chunk.

## Reasoning models

`<think>` text inline in `content` means the engine's reasoning parser is off (vLLM `--reasoning-parser`). Separate `reasoning_content` fields are dropped by `ChatOpenAI`. Reasoning can use the whole `max_tokens`, leaving empty content; raise `max_tokens` or disable thinking in the engine.

## Official links

- https://docs.langchain.com/oss/python/langchain/structured-output
- https://docs.langchain.com/oss/python/langchain/tools
- https://docs.langchain.com/oss/python/langchain/models
- https://docs.langchain.com/oss/python/integrations/chat/openai
- https://reference.langchain.com/python/langchain-openai/chat_models/base/ChatOpenAI
