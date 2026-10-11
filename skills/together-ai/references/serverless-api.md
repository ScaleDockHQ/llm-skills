# Together AI serverless API

> Verified against Together docs: Quickstart, OpenAI compatibility, Call functions, Structured outputs, Rate limits (serverless), 2026-10-11

## Base URL and auth

- Base URL: `https://api.together.ai/v1`. Header: `Authorization: Bearer $TOGETHER_API_KEY`.
- Model IDs are namespaced (`openai/gpt-oss-120b`, `meta-llama/Llama-3.3-70B-Instruct-Turbo`). Names such as `gpt-4o` return 404.
- List what your key can call: `GET /v1/models`. The docs list serverless models at https://docs.together.ai/docs/serverless/models.

```bash
curl -s https://api.together.ai/v1/chat/completions \
  -H "Authorization: Bearer $TOGETHER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"MODEL_ID","messages":[{"role":"user","content":"Say hi"}],"max_tokens":64}' \
  | jq -r '.choices[0].message.content'
```

## OpenAI SDK

```python
import os
from openai import OpenAI

client = OpenAI(api_key=os.environ["TOGETHER_API_KEY"], base_url="https://api.together.ai/v1")
resp = client.chat.completions.create(
    model="MODEL_ID",
    messages=[{"role": "user", "content": "Hello"}],
)
print(resp.choices[0].message.content)
```

Together's own SDK: `from together import Together; client = Together()` (reads `TOGETHER_API_KEY`).

## Compatibility matrix (from the docs)

| Area                                                                             | Status                                                            |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Chat completions, streaming, vision, tools, `response_format`                    | Supported                                                         |
| Legacy completions, embeddings, image generation, text-to-speech, speech-to-text | Supported                                                         |
| Assistants, Threads, Runs                                                        | Not supported                                                     |
| OpenAI-shaped `fine_tuning.jobs.*`, `batches.*`                                  | Not supported; use the Together-native fine-tuning and Batch APIs |
| OpenAI-shaped `files.*`                                                          | Partial; Together has its own Files API                           |
| `moderations.create`                                                             | Not supported; use Llama Guard via chat completions               |

Parameter quirks to know:

- `seed` is best-effort. `logit_bias` is not supported on most models. `n` works on most chat models, not all.
- `service_tier`, `store`, `metadata` and `prediction` are accepted but ignored. The vision `detail` field is accepted but ignored.
- `reasoning_effort` works on GPT-OSS models. Other reasoning controls (`reasoning={"enabled": False}`) are Together-native, not OpenAI API.
- Reasoning models return thinking in `reasoning` or `reasoning_content` on the message, depending on the model. Pass it back under the same key on later turns.
- `usage` token detail location varies by model: nested `prompt_tokens_details.cached_tokens` on reasoning models, flat `cached_tokens` on some non-reasoning ones. Read both.
- Errors are OpenAI-shaped, but `type` and `code` values are Together's. Match on HTTP status (400, 401, 404, 429, 500, 503).

## Function calling

Pass `tools` and optionally `tool_choice`. Calls arrive in `message.tool_calls`, and `message.content` may be `null` on a tool turn.

```python
resp = client.chat.completions.create(
    model="MODEL_ID",
    messages=[{"role": "user", "content": "Weather in Paris?"}],
    tools=[{"type": "function", "function": {
        "name": "get_current_weather",
        "description": "Get the weather for a city",
        "parameters": {"type": "object",
                       "properties": {"location": {"type": "string"}},
                       "required": ["location"]}}}],
    tool_choice="auto",
)
print(resp.choices[0].message.tool_calls)
```

`tool_choice` accepts `"auto"` (default), `"none"`, `"required"`, or `{"type":"function","function":{"name":"..."}}`. With streaming, tool calls arrive incrementally in `delta.tool_calls`. Support varies by model: test with your real tool schemas. Parallel and agentic patterns are in the function-calling pages linked below.

## Structured outputs

Use `response_format` with a JSON schema. Also tell the model in the prompt to answer only in JSON and include the schema text.

```python
resp = client.chat.completions.create(
    model="MODEL_ID",
    messages=[
        {"role": "system", "content": "Answer only in JSON matching the schema."},
        {"role": "user", "content": "Extract: Ada Lovelace, born 1815"},
    ],
    response_format={"type": "json_schema",
                     "json_schema": {"name": "person", "schema": {
                         "type": "object",
                         "properties": {"name": {"type": "string"}, "year": {"type": "integer"}},
                         "required": ["name", "year"]}}},
)
```

A regex mode exists: `response_format={"type":"regex","pattern":"(positive|neutral|negative)"}`. Check the serverless and dedicated model catalogs for which models support structured outputs. If JSON is cut off, check `finish_reason == "length"` and raise `max_tokens`.

## Serverless limits

Serverless is best-effort. High demand can return `429 Too Many Requests` or `503 Service Unavailable`; back off exponentially. Committed throughput comes from provisioned throughput (contact sales) or dedicated endpoints. See `limits-and-spend.md`.

## Sources

- https://docs.together.ai/docs/inference/openai-compatibility
- https://docs.together.ai/docs/inference/function-calling/overview
- https://docs.together.ai/docs/inference/function-calling/single-call
- https://docs.together.ai/docs/inference/chat/structured-outputs
- https://docs.together.ai/docs/inference/chat/reasoning
- https://docs.together.ai/docs/serverless/rate-limits
