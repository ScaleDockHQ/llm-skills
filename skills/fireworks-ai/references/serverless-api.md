# Fireworks AI serverless API

> Verified against Fireworks docs: OpenAI compatibility, Anthropic compatibility, Tool Calling, Structured Outputs, Serverless Modes, Serverless Rate Limits, Data handling and Zero Data Retention policy, 2026-10-11

## Endpoints

| Surface              | Base URL                                                   | Notes                                             |
| -------------------- | ---------------------------------------------------------- | ------------------------------------------------- |
| OpenAI-compatible    | `https://api.fireworks.ai/inference/v1`                    | Chat completions, completions, others per docs    |
| Anthropic-compatible | `https://api.fireworks.ai/inference` (`POST /v1/messages`) | Serverless and on-demand deployments              |
| Management REST      | `https://api.fireworks.ai/v1/accounts/{account_id}/...`    | Models, deployments, datasets, batch jobs, quotas |

Model IDs look like `accounts/fireworks/models/<name>`. List them in the Model Library (https://fireworks.ai/models) or with `GET /v1/accounts/fireworks/models`. Fireworks Nexus also offers router models (for example `accounts/fireworks/routers/...`); read https://docs.fireworks.ai/nexus/firerouter before using them.

```bash
curl -s https://api.fireworks.ai/inference/v1/chat/completions \
  -H "Authorization: Bearer $FIREWORKS_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"accounts/fireworks/models/MODEL","messages":[{"role":"user","content":"Hi"}],"max_tokens":64}'
```

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://api.fireworks.ai/inference/v1", api_key=os.environ["FIREWORKS_API_KEY"])
```

```python
import os, anthropic
client = anthropic.Anthropic(api_key=os.environ["FIREWORKS_API_KEY"], base_url="https://api.fireworks.ai/inference")
resp = client.messages.create(model="accounts/fireworks/models/MODEL", max_tokens=256,
                              messages=[{"role": "user", "content": "Hello"}])
```

Training data uses the OpenAI chat format (`messages` with `role`, `content`, `tool_calls`, `weight`), so OpenAI SFT datasets need no conversion. For NIM and vLLM request fields such as `chat_template_kwargs`, see https://docs.fireworks.ai/tools-sdks/nim-compatibility.

## Tool calling

Standard OpenAI `tools` and `tool_choice` (`auto`, `none`, `required`, or a named function). Some models support parallel tool calls; check the model before relying on it. If the model does not call tools, try `tool_choice="required"`. Tool `parameters` accept the same JSON Schema feature set as `response_format` json_schema, with only in-document `$ref` pointers (`#/...`); external `$ref` URIs are rejected. Older deployment images can 400 on recursive `$ref` or nested `$defs`; redeploy on a current image.

## Structured outputs

```python
resp = client.chat.completions.create(
    model="accounts/fireworks/models/MODEL",
    messages=[{"role": "user", "content": "Return the winner as JSON matching the schema."}],
    response_format={"type": "json_schema",
                     "json_schema": {"name": "result", "schema": {
                         "type": "object",
                         "properties": {"winner": {"type": "string"}},
                         "required": ["winner"]}}},
)
```

- Also available: `{"type": "json_object"}` (any valid JSON) and custom grammars. `json_schema` is recommended.
- Always tell the model to produce JSON in the prompt and include the schema there, or it may emit whitespace until the token limit.
- `finish_reason="length"` means truncated, invalid JSON; raise `max_tokens`.
- Using `response_format` with `json_schema` disables reasoning output. For both reasoning and JSON, put the schema in the prompt and omit `response_format`.
- With tool calling, JSON mode is enabled automatically.

## Serverless modes (service tiers)

Standard is the default. Set `"service_tier": "priority"` on chat completions or Anthropic messages for higher reliability at peak (less likely to be shed with 503); select models only, at a higher price. Fast variants are separate model IDs (for example a `...-fast` router ID) for 100+ tokens per second. Models and prices: https://docs.fireworks.ai/serverless/pricing.

## Rate limits and errors

Serverless returns `429 Too Many Requests` when you exceed adaptive limits and `503 Service Overloaded` under load. Details and how to check your limits: `limits-and-spend.md`. On-demand deployments are not governed by serverless TPM limits; a 429 there usually means the deployment is saturated.

## Data handling

Per the docs on 2026-10-11: most inference does not store prompts or generations. Features that do store content include stored responses (Responses API `store=true` default), batch jobs and training. An enterprise Zero Data Retention policy can block those features account-wide: https://docs.fireworks.ai/accounts/zero-data-retention. Prompt caching holds KV caches in memory only.

## Sources

- https://docs.fireworks.ai/tools-sdks/openai-compatibility
- https://docs.fireworks.ai/tools-sdks/anthropic-compatibility
- https://docs.fireworks.ai/guides/function-calling
- https://docs.fireworks.ai/structured-responses/structured-response-formatting
- https://docs.fireworks.ai/serverless/serverless-modes
- https://docs.fireworks.ai/guides/security_compliance/data_handling
