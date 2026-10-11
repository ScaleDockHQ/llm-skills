# Anthropic API: streaming, tools, structured outputs, Batches, caching, Files

> Verified against Claude Platform docs: Streaming Messages, Tool use overview, Structured outputs, Message Batches, Prompt caching, Files API, 2026-10-11

## Streaming

Set `"stream": true` on `/v1/messages`; the response is server-sent events. Flow: `message_start`, then per content block `content_block_start`, one or more `content_block_delta`, `content_block_stop`, then `message_delta` and `message_stop`. `ping` events can appear anywhere. Delta types include `text_delta`, `input_json_delta` (tool arguments arrive as partial JSON), `thinking_delta` and `signature_delta`.

```bash
curl -sSN https://api.anthropic.com/v1/messages -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d "$(jq -n --arg m "$ANTHROPIC_MODEL" '{model:$m,max_tokens:256,stream:true,messages:[{role:"user",content:"Count to five."}]}')" \
  | grep '^data:' | sed 's/^data: //' | jq -r 'select(.type=="content_block_delta") | .delta.text // empty'
```

An `error` event can arrive after a `200` response; handle it separately from HTTP errors. Use streaming for long requests, since non-streaming long requests can hit `504 timeout_error`.

## Tools (function calling)

Define client tools with `name`, `description` and an `input_schema` (JSON Schema). Claude answers with a `tool_use` block and `stop_reason` indicating tool use; run the tool and send the result back as a `tool_result` block in a `user` message with the matching `tool_use_id`. Server tools (for example web search, `{"type": "web_search_20260209", "name": "web_search"}` in the docs) run on Anthropic's side and are subject to organization settings.

```python
tools = [{"name": "get_weather", "description": "Current weather for a city",
          "input_schema": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}]
r = client.messages.create(model="<pinned-model-id>", max_tokens=512, tools=tools,
                           messages=[{"role": "user", "content": "Weather in Paris?"}])
for block in r.content:
    if block.type == "tool_use":
        result = "18C, cloudy"  # run your function with block.input
        followup = client.messages.create(model="<pinned-model-id>", max_tokens=512, tools=tools, messages=[
            {"role": "user", "content": "Weather in Paris?"},
            {"role": "assistant", "content": r.content},
            {"role": "user", "content": [{"type": "tool_result", "tool_use_id": block.id, "content": result}]}])
```

`strict: true` on a tool (strict tool use) guarantees schema validation of tool names and inputs. Some current models do not accept forced `tool_choice` (`any` or a named tool): use `auto` there (see the API errors page). Treat tool inputs as untrusted.

## Structured outputs

Put the schema in `output_config.format` with `type: "json_schema"`; Claude returns valid JSON matching it in the text block. Check `capabilities.structured_outputs` for the model in `/v1/models`.

```bash
curl -sS https://api.anthropic.com/v1/messages -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d '{
  "model": "'"$ANTHROPIC_MODEL"'", "max_tokens": 1024,
  "messages": [{"role": "user", "content": "Extract: John Smith (john@example.com) wants the Enterprise plan."}],
  "output_config": {"format": {"type": "json_schema", "schema": {
    "type": "object", "properties": {"name": {"type": "string"}, "email": {"type": "string"}, "plan": {"type": "string"}},
    "required": ["name", "email", "plan"], "additionalProperties": false}}}}'
```

SDK helpers: `client.messages.parse(..., output_format=PydanticModel)` in Python and `zodOutputFormat()` in TypeScript. More patterns: `structured-outputs` skill.

## Message Batches

50% lower cost than synchronous calls (check the pricing page for current rates), their own rate limits, most batches finish within an hour.

```bash
H=(-H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01")
curl -sS https://api.anthropic.com/v1/messages/batches "${H[@]}" -H "content-type: application/json" -d '{
  "requests": [{"custom_id": "r1", "params": {"model": "'"$ANTHROPIC_MODEL"'", "max_tokens": 1024,
                "messages": [{"role": "user", "content": "Hello, world"}]}}]}' | jq -r .id
curl -sS https://api.anthropic.com/v1/messages/batches/$BATCH_ID "${H[@]}" | jq '{processing_status, request_counts, results_url}'
curl -sS "$RESULTS_URL" "${H[@]}" | jq -r '"\(.result.type): \(.custom_id)"'   # .jsonl, stream it
```

- Limits: 100,000 requests or 256 MB per batch, whichever comes first. Results are available 29 days after creation. Results can come back in any order: match on `custom_id`.
- `processing_status` goes `in_progress` then `ended` (or `canceling`). Cancel with `POST /v1/messages/batches/{id}/cancel`.
- Batches are isolated per workspace. Requests and responses are stored up to 29 days; delete with `DELETE /v1/messages/batches/{id}` (cancel in-progress ones first).

## Prompt caching

Native API only (the OpenAI layer does not support it). Two ways:

- **Automatic:** add one top-level `"cache_control": {"type": "ephemeral"}`; the breakpoint moves to the last cacheable block as the conversation grows.
- **Explicit:** put `cache_control` on specific content blocks (up to 4 breakpoints; automatic caching uses one slot).

Default TTL is 5 minutes; `"ttl": "1h"` costs more (pricing page). The cached prefix is `tools`, then `system`, then `messages`, so keep static content first. Caching only happens above a per-model minimum prompt length (the docs list values from 512 to 4,096 tokens depending on the model); shorter prompts are processed without caching and **without an error**. Verify via response `usage`: `cache_creation_input_tokens`, `cache_read_input_tokens`, and `input_tokens` (tokens after the last breakpoint). Cache reads usually do not count toward ITPM (`references/limits-and-budgets.md`).

## Files API

`POST /v1/files` (upload, up to 500 MB), `GET /v1/files`, `GET /v1/files/{id}`, `GET /v1/files/{id}/content`, `DELETE /v1/files/{id}`. Files persist until deleted or until `expires_at`, cannot be modified, and cannot be recovered after deletion; deleted files follow Anthropic's retention policy. The older `files-api-2025-04-14` beta header is no longer needed per the docs' migration note. The Files API is not ZDR or HIPAA eligible (`references/data-controls.md`).

## Where to read more

- https://platform.claude.com/docs/en/build-with-claude/streaming
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- https://platform.claude.com/docs/en/build-with-claude/batch-processing
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://platform.claude.com/docs/en/build-with-claude/files
