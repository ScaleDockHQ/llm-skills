# Gemini API: streaming, tools, structured output, Batch, caching, Files

> Verified against Gemini API docs: Generating content, Structured outputs, Batch API, Caching, Context caching, Files, OpenAI compatibility, 2026-10-11

## Streaming

- Native: `POST .../models/<id>:streamGenerateContent?alt=sse` returns server-sent events.
- OpenAI-compatible: `stream: true` on chat completions; `stream_options: {"include_usage": true}` is shown in the docs for usage in the stream.

## Function calling

Supported on the native API and on the compatibility endpoint (`tools` with `type: function`, `tool_choice: "auto"`). You run the function and send the result back; confirm the exact result-part shape in the generating-content docs.

## Structured output

Configure a JSON Schema so the response conforms. On the Interactions API the request field is `response_format`; on `generateContent` and the OpenAI-compatible endpoint see the structured-output page for the current field names (`responseSchema` style fields have changed across versions). SDKs accept Pydantic or Zod models.

- Make all output fields required; do not describe field order in the prompt (the docs tie field-order mismatches to repeated text).
- Avoid `\u` escapes in schema examples. See `references/troubleshooting.md`.

## Batch API

- 50% of standard cost; target turnaround 24 hours; currently documented for `generateContent` only.
- Submit inline requests (total under 20 MB) or a JSONL file uploaded with the Files API (input file up to 2 GB; each line a complete `GenerateContentRequest`). Prefer files for large jobs.
- Create: `POST /v1beta/models/<id>:batchGenerateContent`; the job name looks like `batches/<id>`.
- States: `JOB_STATE_PENDING`, `RUNNING`, `SUCCEEDED`, `FAILED`, `CANCELLED`, `EXPIRED` (expires after 48 hours pending or running, with no results).
- Results are kept for 6 weeks, then permanently deleted. Download them before then.
- Batch has its own limits (concurrent jobs, enqueued tokens per model); read the rate-limits page rather than copying numbers.
- Billing note: batch jobs may overshoot Prepay balances and spend caps (`references/limits-and-budgets.md`).
- OpenAI SDK batch compatibility covers create, status and results, but upload and download use the `genai` client.

## Context caching

- **Implicit caching** is on by default for Gemini 2.5 and newer models; savings pass through automatically when a request hits. Each model has a minimum input token count (see the caching page; do not copy). Put large, stable content first and send similar prefixes close together. Cache hits show in the usage metadata (`cachedContentTokenCount`-style fields; the Interactions API reports `usage.total_cached_tokens`).
- **Explicit caching** (`cachedContents` resource: create, list, get, patch to change TTL, delete) is only available through `generateContent`, not the Interactions API. Create sets `model`, `contents`, optional system instruction and a `ttl`. Cache storage is billed over its lifetime; read pricing on the pricing page.
- OpenAI-compatible: pass `extra_body={"extra_body": {"google": {"cached_content": "cachedContents/<id>"}}}`.
- Delete caches you no longer need: `DELETE /v1beta/cachedContents/<id>`.

## Files API

- Use it when the total request exceeds 100 MB (50 MB for PDFs).
- Files are stored for **48 hours** and then deleted automatically; up to 20 GB per project, 2 GB per file. File resources carry `expirationTime`.
- Operations: upload, `files.get`, `files.list`, `files.delete` (`DELETE /v1beta/files/<id>`); there is also `files.register`, see the Files reference.
- Uploaded files are visible to the project; delete sensitive files as soon as the call finishes.

## Where to read more

- https://ai.google.dev/gemini-api/docs/batch-mode
- https://ai.google.dev/gemini-api/docs/caching
- https://ai.google.dev/gemini-api/docs/files
- https://ai.google.dev/gemini-api/docs/structured-output
- https://ai.google.dev/api/caching
- https://ai.google.dev/api/files
