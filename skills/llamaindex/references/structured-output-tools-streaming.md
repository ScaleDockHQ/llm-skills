# LlamaIndex: structured output, tools and streaming

> Verified against LlamaIndex llama-index v0.14.25 (llama-index-core 0.14.25, llama-index-llms-openai-like 0.8.1), 2026-10-11

Self-hosted models differ from hosted ones in three ways: JSON enforcement depends on the engine, tool calls depend on a server-side parser, and streamed usage is opt-in. LlamaIndex also decides behavior from the flags you declare on the LLM, not from probing the server.

## Structured output

```python
from pydantic import BaseModel
from llama_index.core.prompts import PromptTemplate

class Weather(BaseModel):
    city: str
    temp_c: float

out = llm.structured_predict(Weather, PromptTemplate("Weather in {city} as JSON."), city="Paris")
sllm = llm.as_structured_llm(Weather); sllm.complete("Weather in Paris")
```

With the default `pydantic_program_mode`, LlamaIndex picks:

- `is_function_calling_model=True`: a function-calling program (the schema is sent as a tool). Needs a working tool parser on the engine.
- `is_function_calling_model=False`: a text-completion program that asks for JSON in the prompt and parses the reply. Works anywhere, less reliable on small models.
- `OpenAILike(should_use_structured_outputs=True)` sends `response_format` with the schema; set it only after `scripts/probe.sh openai` shows the `json_schema` line enforced.

Other modes (`PydanticProgramMode.LLM`, `FUNCTION`, and so on) can be set per LLM to force one path. Keep temperature low and catch validation errors.

## Agents and tools

```python
from llama_index.core.agent.workflow import FunctionAgent
from llama_index.core.tools import FunctionTool

def get_weather(city: str) -> str:
    """Weather by city."""
    return f"{city}: 18C"

agent = FunctionAgent(tools=[FunctionTool.from_defaults(get_weather)], llm=llm,
                      system_prompt="Use tools when useful.")
# in async code: resp = await agent.run("Weather in Paris?")
```

- `FunctionAgent` raises `LLM must be a FunctionCallingLLM` when `is_function_calling_model` is false. Declare it only for models and engines that really return `tool_calls` (vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama-server `--jinja`, Ollama tool-capable models).
- For models without tool support use a ReAct-style agent (`ReActAgent` in `llama_index.core.agent.workflow`), which works through plain text.
- `OpenAI`-based classes have a `strict` flag for tool schemas (default `False`); leave it off for self-hosted engines.
- Parallel tool calls are off by default in the function-calling LLM helpers; most small models do not benefit from enabling them.

## Streaming

```python
from llama_index.core.llms import ChatMessage

for r in llm.stream_chat([ChatMessage(role="user", content="Write a haiku.")]):
    print(r.delta, end="", flush=True)
```

- `stream_complete`, `stream_chat`, `astream_chat` and `astream_complete` exist on every LLM.
- LlamaIndex does not request streamed usage on its own. Pass `additional_kwargs={"stream_options": {"include_usage": True}}` on the LLM; the OpenAI class removes `stream_options` from non-streaming calls, so it is safe to leave set. The engine must honor it; read usage from the final `response.raw`.
- Set `timeout` on `OpenAILike` and `request_timeout` on `Ollama`; lower `max_retries` so a slow local model is not re-sent.
- Proxies that buffer SSE deliver one late chunk.

## Reasoning models

Thinking text inline as `<think>...</think>` means the engine's reasoning parser is off (vLLM `--reasoning-parser`). Reasoning can consume all of `max_tokens`, leaving empty content; raise `max_tokens` or disable thinking (`thinking=False` on `Ollama`). Check the installed integration version for how it surfaces non-standard reasoning fields.

## Official links

- https://developers.llamaindex.ai/python/framework/module_guides/querying/structured_outputs/
- https://developers.llamaindex.ai/python/framework/understanding/agent/
- https://github.com/run-llama/llama_index/tree/main/llama-index-core/llama_index/core/program
- https://github.com/run-llama/llama_index/tree/main/llama-index-core/llama_index/core/agent/workflow
