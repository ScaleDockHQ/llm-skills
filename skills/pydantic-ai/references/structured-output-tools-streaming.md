# Pydantic AI: structured output, tools and streaming

> Verified against Pydantic AI v2.55.0 (docs: output, tools, models/compatible-apis, models/ollama), 2026-10-11

Self-hosted models differ from hosted ones in three ways: JSON enforcement depends on the engine, tool calls depend on a server-side parser, and what the library assumes depends on the model profile.

## Output modes

```python
from pydantic import BaseModel
from pydantic_ai import Agent, ToolOutput, NativeOutput, PromptedOutput

class Weather(BaseModel):
    city: str
    temp_c: float

agent = Agent(model, output_type=Weather)                       # default: Tool Output
agent = Agent(model, output_type=NativeOutput(Weather))         # JSON schema response format
agent = Agent(model, output_type=PromptedOutput(Weather))       # schema in the instructions, parsed from text
```

Upstream defines three methods:

- **Tool Output** (default): the schema becomes the parameters of a special output tool. Needs working tool calling on the engine (vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama-server `--jinja`, Ollama tool-capable models).
- **Native Output**: the engine must enforce `response_format` with `json_schema`. vLLM, recent llama-server and self-hosted Ollama (0.5.0 and later) do; check `scripts/probe.sh openai` (`json_schema` line). Ollama Cloud does not enforce it yet.
- **Prompted Output**: the schema is injected into the instructions and the reply is parsed; usable with any model and the least reliable. When the API supports JSON mode (`json_object`) it is enabled, but the model may still ignore the schema. Pydantic AI validates and asks the model to retry on failure.

Start with Tool Output for models with a tool parser, Native Output for engines that enforce schemas, Prompted Output as the fallback. Each output tool has its own retry counter.

## Tools

```python
@agent.tool_plain
def get_weather(city: str) -> str:
    """Weather by city."""
    return f"{city}: 18C"

result = agent.run_sync("Weather in Paris? Use the tool.")
```

- Pydantic AI sends OpenAI `tools`; the server must turn model output into `tool_calls`. Without a parser the tool JSON shows up as text and the run fails validation or returns text.
- Strict tool schemas are controlled by the profile (`openai_supports_strict_tool_definition`, default true in the OpenAI profile). Servers that reject `strict` need a profile that turns it off; see `custom-endpoints.md`.
- Small models call tools unreliably: fewer tools, short descriptions, one test per alias.

## Streaming

```python
import asyncio

async def main():
    async with agent.run_stream("Write a haiku.") as result:
        async for text in result.stream_text(delta=True):
            print(text, end="", flush=True)
        print(result.usage())

asyncio.run(main())
```

- `run_stream` returns a context manager; `stream_text()` yields the accumulated text, `stream_text(delta=True)` yields deltas.
- The Chat Completions model sends `stream_options: {include_usage: true}` for streamed requests, so usage appears when the server honors it; no extra flag is needed (unlike most other clients).
- Some compatible servers close a stream without a terminal `finish_reason`, so a truncated reply looks complete. If your server always sends one, set `openai_chat_streaming_requires_finish_reason=True` so Pydantic AI raises `ModelAPIError` on a cut stream.
- Proxies that buffer SSE deliver one late chunk; disable buffering.

## Thinking and system messages

- Thinking returned in `reasoning` or `reasoning_content` fields is read by the Chat Completions model; set `openai_chat_thinking_field` on the profile for other field names. Inline `<think>` tags mean the engine's reasoning parser is off (vLLM `--reasoning-parser`).
- Some chat templates (newer Qwen, Mistral, Gemma, Command-R families) reject more than one leading system message with 400 errors such as `System message must be at the beginning.` or `Conversation roles must alternate`. Set `openai_chat_supports_multiple_system_messages=False` in the profile to merge them (the merge joins them with two newlines); `VLLMProvider` already does this by default.
- Reasoning can consume all output tokens, leaving empty text; raise `max_tokens` in `ModelSettings` or disable thinking in the engine.

## Official links

- https://pydantic.dev/docs/ai/output/
- https://pydantic.dev/docs/ai/tools/
- https://pydantic.dev/docs/ai/models/compatible-apis/
- https://pydantic.dev/docs/ai/api/pydantic-ai/profiles/
