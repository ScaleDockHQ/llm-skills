# Anthropic SDK: Messages, streaming, tools, thinking, betas

> Verified against anthropic-sdk-python v1.13.0 and anthropic-sdk-typescript sdk-v0.133.0 (platform docs), llama.cpp server README, Ollama Anthropic-compatibility docs, 2026-10-11

## Request shape differences from OpenAI

- `max_tokens` is required.
- `system` is a top-level field, not a message with role `system`.
- Roles are `user` and `assistant` only; content can be a string or a list of blocks (`text`, `image`, `tool_use`, `tool_result`, `thinking`).
- Answers come as `message.content` blocks; text is in the `text` blocks. `stop_reason` is `end_turn`, `max_tokens`, `stop_sequence` or `tool_use`.
- Usage is `message.usage.input_tokens` and `output_tokens`.

## Streaming

```python
with client.messages.stream(model=MODEL, max_tokens=256,
                            messages=[{"role": "user", "content": "Count to three."}]) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
    final = stream.get_final_message()
```

```js
const stream = client.messages.stream({ model, max_tokens: 256, messages });
stream.on("text", (t) => process.stdout.write(t));
const final = await stream.finalMessage();
```

`messages.create(..., stream=True)` returns raw events instead. If text arrives in one burst, a proxy is buffering the SSE stream: disable buffering, raise idle timeouts. The server must emit Anthropic-style events (`message_start`, `content_block_delta`, `message_stop`); a server that returns OpenAI-style chunks on this route is not Anthropic-compatible.

## Tools

```python
tools = [{"name": "get_weather", "description": "Weather for a city",
          "input_schema": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}]
r = client.messages.create(model=MODEL, max_tokens=512, tools=tools,
                           messages=[{"role": "user", "content": "Weather in Paris? Use the tool."}])
use = next(b for b in r.content if b.type == "tool_use")      # use.id, use.name, use.input (already a dict)
msgs = [{"role": "user", "content": "Weather in Paris? Use the tool."},
        {"role": "assistant", "content": r.content},
        {"role": "user", "content": [{"type": "tool_result", "tool_use_id": use.id, "content": "18 C"}]}]
r2 = client.messages.create(model=MODEL, max_tokens=512, tools=tools, messages=msgs)
```

Unlike OpenAI, `input` is a parsed object, tool results go in a `user` message, and tool definitions use `input_schema`. Server prerequisites: llama.cpp needs `--jinja` for tool use on this route; vLLM needs `--enable-auto-tool-choice --tool-call-parser <name>`; Ollama supports tools and tool results; gateways pass through to a backend that must support tools. If the model prints JSON as text, the parser or template is missing: see `tool-calling-parsers` (`npx skills add ScaleDockHQ/llms-skills --skill tool-calling-parsers`). Check coverage per server: Ollama and llama.cpp document subsets of the Messages API, so unsupported fields (certain content types, server tools, citations, caching) are ignored or rejected.

## Thinking

`thinking={"type": "enabled", "budget_tokens": 1024}` is accepted by servers that implement it (Ollama documents thinking support). Thinking blocks come back as `thinking` content and must be passed back unchanged between tool turns. On engines without support the field is ignored or causes a 400; remove it.

## Betas and server tools

`client.beta.messages.create(..., betas=[...])` sends the `anthropic-beta` header. Self-hosted servers usually do not implement betas or Anthropic's hosted tools (web search, code execution): they ignore or reject them. Use the non-beta `client.messages` with only `tools` you execute yourself.

## Token counting

`client.messages.count_tokens(...)` calls `/v1/messages/count_tokens`. llama.cpp and llama-swap list it; others may 404, in which case count with the model's tokenizer or the usage field after the call.

## Prompt caching fields

`cache_control` blocks are accepted as input on compatible servers but real caching is engine-side (prefix caching); do not expect Anthropic's cache usage fields.

## Model names

Pass the server's id (from `GET /v1/models`) or the gateway alias. Anthropic model ids mean nothing to a self-hosted engine unless a gateway maps them. See `server-recipes.md`.

## Official links

- Messages API: https://platform.claude.com/docs/en/api/messages
- Tool use: https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
- Streaming: https://platform.claude.com/docs/en/build-with-claude/streaming
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Ollama Anthropic compatibility: https://docs.ollama.com/api/anthropic-compatibility
