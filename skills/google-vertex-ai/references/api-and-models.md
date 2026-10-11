# Calling models: Gemini, OpenAI-compatible, Claude, open MaaS, batch

> Verified against Agent Platform docs (Get started, OpenAI compatibility, Call MaaS APIs for open models, Function calling for open models, Claude on Google Cloud, Use partner models, Batch inference with Gemini, Get batch predictions), Anthropic "Claude on Google Cloud" page, 2026-10-11

## Gemini native: generateContent

```
POST https://aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/global/publishers/google/models/$MODEL_ID:generateContent
```

Regional form: replace the host with `https://$LOCATION-aiplatform.googleapis.com` and `locations/global` with the location. Streaming uses `:streamGenerateContent`. The auth header is a bearer token from ADC (`gcloud auth print-access-token`) or an API key for these two methods only. See `setup-and-auth.md` for a full curl.

Gemini thinking models can spend `maxOutputTokens` on thoughts before any visible text. If `finishReason` is `MAX_TOKENS` and the text is empty, raise or omit the cap.

## OpenAI-compatible endpoint for Gemini

Base URL: `https://aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/endpoints/openapi` (docs use `global`). Model names are prefixed `google/`, for example `google/gemini-3.5-flash` in the docs. Only Google Cloud auth works with the OpenAI library here; the key is an OAuth access token that **expires after 1 hour**, so refresh it.

```python
import openai
from google.auth import default
import google.auth.transport.requests

credentials, _ = default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
credentials.refresh(google.auth.transport.requests.Request())

client = openai.OpenAI(
    base_url=f"https://aiplatform.googleapis.com/v1/projects/{project_id}/locations/global/endpoints/openapi",
    api_key=credentials.token,
)
resp = client.chat.completions.create(
    model="google/gemini-3.5-flash",
    reasoning_effort="low",  # minimal | low | medium | high, maps to thinking_level on Gemini 3
    messages=[{"role": "user", "content": "Explain how AI works"}],
)
```

Documented on this endpoint: streaming, function calling, image and audio input, structured output (`client.beta.chat.completions.parse`), `reasoning_effort`, direct thinking control via `extra_body.google.thinking_config`, and image generation with `"modalities": ["image","text"]` against `.../endpoints/openapi/chat/completions`.

## Open models as managed APIs (MaaS)

Serverless open models (Llama, Qwen, DeepSeek, gpt-oss, GLM, Kimi, MiniMax and others) use the same OpenAI-style chat completions route with `publisher/model-id` names:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/global/endpoints/openapi/chat/completions" \
  -d '{"model":"deepseek-ai/deepseek-v3.2-maas","messages":[{"role":"user","content":"Hello"}],"stream":false}'
```

- Regional form: `https://$LOCATION-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/endpoints/openapi/chat/completions`.
- Model IDs end in `-maas` (examples in the docs: `meta/llama-3.3-70b-instruct-maas`, `qwen/qwen3-next-80b-a3b-instruct-maas`, `deepseek-ai/deepseek-v3.2-maas`). The catalog and the locations each model supports change often; read https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/maas/use-open-models and the locations page before use.
- First message must be `user`; models operate on alternating turns.
- Tool calling notes from the docs: some models do not support `tool_choice="required"`; Qwen models do best with `tool_choice` set to `auto` or `none`; gpt-oss models want tool definitions in the system prompt.
- Pay-as-you-go quotas apply; see `limits-and-budgets.md`.

## Claude (partner MaaS)

1. Enable the Claude model in its Model Garden model card (**Enable**). That needs the Consumer Procurement Entitlement Manager IAM role, and the organization policy must allow `cloudcommerceconsumerprocurement.googleapis.com`.
2. The caller needs `aiplatform.endpoints.predict` (included in Agent Platform User).
3. Call `rawPredict` or `streamRawPredict`. The model is in the URL, not the body. `anthropic_version` is in the body and must be `vertex-2023-10-16`.

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/global/publishers/anthropic/models/$CLAUDE_MODEL_ID:rawPredict" \
  -d '{"anthropic_version":"vertex-2023-10-16","max_tokens":300,"messages":[{"role":"user","content":"Why is the sky blue?"}]}'
```

Use the exact model ID shown on the model card (do not guess dated suffixes). Regional hosts are `https://$LOCATION-aiplatform.googleapis.com`; multi-region `us` and `eu` locations exist for some models. Request-response logging (30 days) is supported for Claude on the platform. Claude Code can target this route with `CLAUDE_CODE_USE_VERTEX=1` and `ANTHROPIC_VERTEX_BASE_URL`; the Anthropic Messages shape from a gateway is covered by `llm-gateway`.

## Batch inference (Gemini)

- 50% discounted versus real-time, asynchronous, most jobs finish within 24 hours after start (incomplete jobs are cancelled and only completed requests are charged). Up to 200,000 requests per job; Cloud Storage input file limit 1 GB. Discounts for cache and batch do not stack: the 90% implicit-cache discount takes precedence.
- No predefined quota for Gemini batch; capacity is a shared pool, so jobs may queue.
- Input: BigQuery table (`bq://project.dataset.table`, dataset in the same region as the job, no multi-region datasets) or JSONL in Cloud Storage. Output: BigQuery or JSONL in Cloud Storage.
- Create with REST. Look up the current request body in the page below; the BigQuery shape is:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://$LOCATION-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/batchPredictionJobs" \
  -d '{
    "displayName": "my-batch",
    "model": "publishers/google/models/'"$MODEL_ID"'",
    "inputConfig": {"instancesFormat":"bigquery","bigquerySource":{"inputUri":"bq://'"$PROJECT_ID"'.ds.input"}},
    "outputConfig": {"predictionsFormat":"bigquery","bigqueryDestination":{"outputUri":"bq://'"$PROJECT_ID"'.ds.output"}}
  }'
```

For Cloud Storage use `"instancesFormat":"jsonl"` with `gcsSource.uris`, and `gcsDestination.outputUriPrefix` for output. A failed, cancelled or expired job can be resumed by submitting a new job with the previous output as input. MaaS batch uses OpenAI-schema JSONL.

## Sources

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start/openai
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/maas/call-open-model-apis
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/maas/capabilities/function-calling
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/partner-models/use-partner-models
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/partner-models/claude/use-claude
- https://docs.claude.com/en/api/claude-on-vertex-ai
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/batch-inference
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/reference/models/batch-prediction-api
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/deploy/batch-from-bigquery
