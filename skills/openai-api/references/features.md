# OpenAI API: streaming, tools, structured output, Batch, caching, files

> Verified against OpenAI docs: Streaming API responses, Function calling, Structured outputs, Batch API, Prompt caching, API reference "Delete file", 2026-10-11

## Streaming

Set `stream: true` on `/v1/responses`. The stream is server-sent events with typed events.

```python
stream = client.responses.create(model="<pinned-model-id>", input="Count to ten.", stream=True)
for event in stream:
    if event.type == "response.output_text.delta":
        print(event.delta, end="")
    elif event.type == "response.completed":
        print()
    elif event.type == "error":
        print(event.message)
```

- Common events: `response.created`, `response.output_text.delta`, `response.completed`, `error`; tool-call and structured-output streaming have their own guides.
- Errors before the stream starts are plain HTTP errors; an error after streaming begins arrives as a stream event. Do not blindly replay a request after consuming output.
- Streaming makes moderation harder because partial output is harder to evaluate; moderation scores arrive after the full output.
- A WebSocket mode exists for persistent connections with `previous_response_id`.

## Function calling (tools)

Define `tools` with `type: "function"`, a `name`, `description`, JSON-Schema `parameters` and `strict: true`. The model returns `function_call` items; run the function and send back a `function_call_output` item with the same `call_id`.

```python
tools = [{
    "type": "function", "name": "get_horoscope",
    "description": "Get today's horoscope for a sign.",
    "parameters": {"type": "object", "properties": {"sign": {"type": "string"}},
                   "required": ["sign"], "additionalProperties": False},
    "strict": True,
}]
input_items = [{"role": "user", "content": "What is my horoscope? I am an Aquarius."}]
resp = client.responses.create(model="<pinned-model-id>", tools=tools, input=input_items)
input_items += resp.output  # keep the model's output items for the next turn
for item in resp.output:
    if item.type == "function_call":
        result = "..."  # run your function with json.loads(item.arguments)
        input_items.append({"type": "function_call_output", "call_id": item.call_id, "output": result})
resp = client.responses.create(model="<pinned-model-id>", tools=tools, input=input_items)
print(resp.output_text)
```

Execute tool calls in your own sandbox with allowlists; treat arguments as untrusted input. For self-hosted tool-call parsing see `tool-calling-parsers`.

## Structured Outputs

On Responses use `text.format` with `type: "json_schema"`, a `name`, `strict: true` and a schema with `additionalProperties: false` and all fields `required`:

```bash
curl -sS https://api.openai.com/v1/responses -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" -d '{
  "model": "<pinned-model-id>",
  "input": "Extract: John and Susan meet on Friday.",
  "text": {"format": {"type": "json_schema", "name": "event", "strict": true,
    "schema": {"type": "object",
      "properties": {"participants": {"type": "array", "items": {"type": "string"}}, "day": {"type": "string"}},
      "required": ["participants", "day"], "additionalProperties": false}}}}'
```

SDKs accept Pydantic or Zod types (for example `client.responses.parse(..., text_format=MyModel)`). Structured Outputs is the schema-guaranteeing mode; `json_object` only guarantees valid JSON. Chat Completions uses `response_format: {type: "json_schema", ...}`. Schema changes alter the prompt prefix and can miss the prompt cache. More patterns: `structured-outputs` skill.

## Batch API

50% cost discount versus synchronous calls (per the Batch guide), a separate rate-limit pool and a 24-hour completion window (the only supported value).

```bash
# 1. Each line: {"custom_id":"r1","method":"POST","url":"/v1/responses","body":{...}}  (one model per file)
curl -sS https://api.openai.com/v1/files -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F purpose=batch -F file=@batchinput.jsonl | jq -r .id   # -> file id

# 2. Create
curl -sS https://api.openai.com/v1/batches -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input_file_id":"'"$FILE_ID"'","endpoint":"/v1/responses","completion_window":"24h"}' | jq -r .id

# 3. Poll, then download output_file_id (and error_file_id) from the batch object
curl -sS https://api.openai.com/v1/batches/$BATCH_ID -H "Authorization: Bearer $OPENAI_API_KEY" | jq '{status, output_file_id, error_file_id, request_counts}'
curl -sS https://api.openai.com/v1/files/$OUT_ID/content -H "Authorization: Bearer $OPENAI_API_KEY" > batch_output.jsonl
```

- Supported endpoints include `/v1/responses`, `/v1/chat/completions`, `/v1/embeddings`, `/v1/completions`, `/v1/moderations`, `/v1/images/generations` and `/v1/images/edits`.
- Statuses: `validating`, `failed`, `in_progress`, `finalizing`, `completed`, `expired`, `cancelling`, `cancelled`. Cancelling can take up to 10 minutes: `POST /v1/batches/{id}/cancel`.
- Limits: up to 50,000 requests and 200 MB per batch file, up to 2,000 batch creations per hour, and a per-model queued-token limit shown in Settings. Output order is not input order: match on `custom_id`.
- Expired batches: completed requests are still billed and returned; unfinished ones go to the error file with `batch_expired`. Output files are deleted automatically 30 days after completion.
- Batch is not Zero Data Retention eligible (`references/data-controls.md`).

## Prompt caching

On by default for supported models; no code change needed. Only an identical prompt prefix hits, so put static content (instructions, tool definitions, documents) first and variable content last.

- Changing `model`, `tools`, `text.format`, `reasoning.effort`, `text.verbosity` or compaction can change the cached prefix.
- Minimum cacheable prefix is 1,024 tokens on GPT-5.6 and later; it varies by settings on earlier models.
- GPT-5.6 and later add explicit control: `prompt_cache_options.mode` (`implicit` or `explicit`), `prompt_cache_breakpoint` on content blocks, `prompt_cache_options.ttl` (minimum lifetime; `30m` is the only supported value and the default) and `prompt_cache_options.prewarm`. Cache writes cost more than uncached input on those models, reads cost far less: check the pricing page for the current multipliers instead of hardcoding them.
- Earlier models use a stable `prompt_cache_key` for routing (aim for about 15 requests per minute per key) and `prompt_cache_retention`.
- Watch cached tokens in the response `usage`, and use the Prompt Caching dashboard and diagnostics tool in the console.

## Files

Upload with `POST /v1/files` (`purpose`). Files persist until deleted unless you set `expires_after`. Delete with `DELETE /v1/files/{file_id}` (this also removes the file from all vector stores). `/v1/files` is not Zero Data Retention eligible.

## Where to read more

- https://developers.openai.com/api/docs/guides/streaming-responses
- https://developers.openai.com/api/docs/guides/function-calling
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://developers.openai.com/api/docs/guides/batch
- https://developers.openai.com/api/docs/guides/prompt-caching
