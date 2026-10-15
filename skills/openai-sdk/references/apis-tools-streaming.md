# OpenAI SDK: APIs, streaming, tools, structured output

> Verified against openai-python v3.28.0 and openai-node v7.32.0, vLLM docs (tool calling, reasoning outputs), llama.cpp server README, Ollama OpenAI-compatibility docs, llama-swap README, 2026-10-11

## Chat Completions or Responses

| Call                                                         | Route                       | Works on                                                                                                        |
| ------------------------------------------------------------ | --------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `client.chat.completions.create` / `chat.completions.create` | `POST /v1/chat/completions` | Every OpenAI-compatible server                                                                                  |
| `client.responses.create` / `responses.create`               | `POST /v1/responses`        | Servers that list it: vLLM, llama.cpp, Ollama (stateless), llama-swap (proxied), LiteLLM (bridged, probe first) |

Default to Chat Completions for self-hosted work. Use Responses only after `check-endpoint.sh` or a `curl` shows the route answers, and expect gaps: Ollama's Responses is stateless (no stored conversations, `previous_response_id` chains), hosted tools like web search are not available on local engines, and stateful features need a gateway that stores them. A 404 on `/v1/responses` means the server lacks it; bridge in the gateway or switch call.

## Streaming

```python
stream = client.chat.completions.create(
    model=MODEL, messages=msgs, stream=True,
    stream_options={"include_usage": True},      # final chunk carries token usage
)
for chunk in stream:
    if chunk.choices:
        print(chunk.choices[0].delta.content or "", end="")
```

```js
const stream = await client.chat.completions.create({
  model,
  messages,
  stream: true,
  stream_options: { include_usage: true },
});
for await (const chunk of stream)
  process.stdout.write(chunk.choices[0]?.delta?.content ?? "");
```

- With `include_usage` the last chunk has an empty `choices` list; guard for it.
- If tokens arrive all at once, a proxy is buffering: disable proxy buffering for SSE and raise idle timeouts.
- Ollama supports `stream_options`; if a server rejects it, drop it and compute usage another way.
- A stream cut by an idle timeout shows as `APIConnectionError` or a truncated final message; raise the gateway and client timeouts.

## Tools (function calling)

```python
tools = [{"type": "function", "function": {
    "name": "get_weather", "description": "Weather for a city",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]
r = client.chat.completions.create(model=MODEL, messages=msgs, tools=tools)
call = r.choices[0].message.tool_calls[0]          # call.function.name, call.function.arguments (JSON string)
msgs += [r.choices[0].message.model_dump(exclude_none=True),
         {"role": "tool", "tool_call_id": call.id, "content": '{"temp_c": 18}'}]
r2 = client.chat.completions.create(model=MODEL, messages=msgs, tools=tools)
```

`arguments` is a string: `json.loads` / `JSON.parse` it and handle invalid JSON from small models. Server prerequisites:

| Engine              | Needed for `tool_calls`                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM                | `--enable-auto-tool-choice --tool-call-parser <name>` (plus a tool chat template for some models); `tool_choice` of named function or `required` uses structured outputs, so the first call can be slow |
| llama.cpp           | `--jinja` (default enabled) with a tool-capable template; may need `--chat-template-file`                                                                                                               |
| Ollama              | A model that supports tools; `tool_choice` is not supported                                                                                                                                             |
| LiteLLM, llama-swap | Pass-through, so the backend must support it                                                                                                                                                            |

If the model prints the call as plain text in `content`, the parser flag or template is missing: see the `tool-calling-parsers` skill (`npx skills add ScaleDockHQ/llm-skills --skill tool-calling-parsers`).

## Structured output

`response_format={"type": "json_schema", ...}` and `client.chat.completions.parse(...)` work on engines that implement guided decoding (vLLM, llama.cpp grammar, LiteLLM pass-through). Check with a probe call; where unsupported the server may ignore the field and return free text. Always validate the parsed result.

## Reasoning models

vLLM with `--reasoning-parser` returns the thinking in `message.reasoning` (older versions used `reasoning_content`; read both). llama.cpp returns `message.reasoning_content` per `--reasoning-format`. The OpenAI Python types do not declare these fields: read with `getattr(message, "reasoning", None)` or `model_extra`; in Node they are untyped properties. For streaming, check `delta` for the same names. Do not send reasoning back as assistant `content`.

## Vendor parameters and extra fields

```python
client.chat.completions.create(model=MODEL, messages=msgs,
    extra_body={"top_k": 40, "chat_template_kwargs": {"enable_thinking": False}})
```

Node: put the keys in the request body object (extra properties are sent as-is) or use the `// @ts-expect-error` escape for typed fields. Python also has `extra_query` and `extra_headers`. Servers ignore unknown fields or reject them (400): remove the field if so.

## Embeddings and other routes

`client.embeddings.create(model=..., input=...)` works on vLLM (embedding models), llama.cpp (`--embeddings`), Ollama and gateways. Audio, images and files depend on the server; probe first.

## Model names

The `model` string must equal an id from `GET /v1/models`. Some single-model servers accept any name; gateways do not. See `server-recipes.md`.

## Official links

- Chat Completions: https://platform.openai.com/docs/api-reference/chat
- Responses: https://platform.openai.com/docs/api-reference/responses
- vLLM tool calling: https://docs.vllm.ai/en/latest/features/tool_calling.html
- vLLM reasoning outputs: https://docs.vllm.ai/en/latest/features/reasoning_outputs.html
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Ollama OpenAI compatibility: https://docs.ollama.com/api/openai-compatibility
