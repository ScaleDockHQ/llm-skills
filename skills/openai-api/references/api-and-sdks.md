# OpenAI API: endpoints and SDKs

> Verified against OpenAI docs: Developer quickstart, Text generation, Migrate to Responses, API reference "List models", Production best practices, 2026-10-11

## Pick the endpoint

| Endpoint                    | Use                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------ |
| `POST /v1/responses`        | Recommended for new text apps and reasoning models; tools, state, structured output        |
| `POST /v1/chat/completions` | Older API still available; what most OpenAI-compatible clients, gateways and servers speak |
| `GET /v1/models`            | List visible models with `owned_by` and `shutdown_date`                                    |
| `POST /v1/batches`          | Asynchronous bulk work (`references/features.md`)                                          |
| `POST /v1/files`            | Upload inputs (batch, fine-tuning, assistants)                                             |

The docs state reasoning models do better on Responses and recommend Responses over Chat Completions for new text generation work. The migration guide covers moving existing Chat Completions code.

## SDKs and CLI

```bash
pip install openai          # Python
npm install openai          # Node, Deno, Bun
# Other official clients exist for Go, Java, C# (.NET) and Ruby; see the quickstart.
```

SDKs read `OPENAI_API_KEY` from the environment. The quickstart also shows an `openai` CLI (for example `openai responses create ...`); check `openai --help` for your installed version.

## First call

Pick the model ID from `GET /v1/models` and keep it in a variable; the docs' own examples use frontier IDs like `gpt-6-astra` and cheaper tiers such as `gpt-5.6-terra` and `gpt-5.6-luna`, and recommend pinning a dated snapshot in production.

```bash
curl -sS https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d "$(jq -n --arg m "$OPENAI_MODEL" '{model:$m, input:"Say hello in five words.", max_output_tokens:64}')" \
  | jq -r '.output_text // (.output[] | select(.type=="message") | .content[0].text)'
```

```python
from openai import OpenAI

client = OpenAI()  # reads OPENAI_API_KEY
resp = client.responses.create(
    model="<pinned-model-id>",
    instructions="Answer briefly.",
    input="Are semicolons optional in JavaScript?",
    reasoning={"effort": "low"},
)
print(resp.output_text)
```

Notes from the docs:

- `output` is an array that can hold tool calls and reasoning items; do not assume the text is at `output[0].content[0].text`. SDKs expose `output_text`.
- `instructions` applies only to the current request; with `previous_response_id` the earlier turn's instructions are not carried over.
- `developer` messages carry app rules; `user` messages carry end-user input.

## Chat Completions (compatibility path)

```bash
curl -sS https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d "$(jq -n --arg m "$OPENAI_MODEL" '{model:$m, messages:[{role:"user",content:"Hello"}], max_completion_tokens:64}')" \
  | jq -r '.choices[0].message.content'
```

Unverified: exact parameter name differences per model family (`max_tokens` vs `max_completion_tokens`); check the Chat Completions reference for your model.

## Reducing latency and size

- Lower `max_output_tokens`, stream for interactivity, and use smaller models for simple tasks (production best practices).
- You can compress `POST /v1/responses` bodies with `zstd` (`Content-Encoding: zstd`); compressed and decompressed bodies must each be at most 128 MiB and the decompressed size at most 100x the compressed one, else `413`.
- Rate limit accounting uses the larger of `max_tokens` and an estimate from your input, so set it near the expected output size.

## Deprecations to watch

From the docs on the writing date: `gpt-3.5-turbo-instruct` has a scheduled shutdown on 2026-09-28; reusable prompt objects (`v1/prompts`) are scheduled to shut down on 2026-11-30 (keep prompts in code); the Videos API shutdown date was 2026-09-24. Always re-check the deprecations page linked from the OpenAI docs and each model's `shutdown_date` in `/v1/models`.

## Where to read more

- https://developers.openai.com/api/docs/guides/text
- https://developers.openai.com/api/docs/guides/migrate-to-responses
- https://developers.openai.com/api/docs/api-reference/models/list
