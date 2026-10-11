# Groq batch and LoRA

> Verified against GroqDocs: Batch, API Reference (files, batches, fine_tunings), LoRA Inference, Your Data, Billing FAQs, 2026-10-11

## Batch API

Asynchronous processing at a documented discount (50% at time of reading; check https://groq.com/pricing), with its own limits that do not use your synchronous rate limits. Paid plan required. The discount does not stack with prompt caching. Supported request URLs inside the JSONL: `/v1/chat/completions`, `/v1/audio/transcriptions`, `/v1/audio/translations`.

### JSONL

One request per line:

```json
{
  "custom_id": "request-1",
  "method": "POST",
  "url": "/v1/chat/completions",
  "body": {
    "model": "<MODEL_ID>",
    "messages": [{ "role": "user", "content": "hi" }]
  }
}
```

Files API limits at time of reading: `.jsonl`, at most 50,000 lines and 200 MB. Split larger jobs. There is no stated cap on the number of batch jobs.

### Run

```bash
FILE_ID=$(curl -s https://api.groq.com/openai/v1/files -H "Authorization: Bearer $GROQ_API_KEY" \
  -F purpose="batch" -F "file=@batch.jsonl" | jq -r .id)

BATCH_ID=$(curl -s https://api.groq.com/openai/v1/batches -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"input_file_id\":\"$FILE_ID\",\"endpoint\":\"/v1/chat/completions\",\"completion_window\":\"24h\"}" | jq -r .id)

curl -s https://api.groq.com/openai/v1/batches/$BATCH_ID -H "Authorization: Bearer $GROQ_API_KEY" | jq '{status,output_file_id,error_file_id,request_counts}'
```

`completion_window` ranges from `24h` to `7d`; a longer window lowers the chance of expiry. Statuses: `validating`, `failed`, `in_progress`, `finalizing`, `completed`, `expired`, `cancelling`, `cancelled`.

Download output when `completed`:

```bash
curl -s https://api.groq.com/openai/v1/files/$OUT_FILE_ID/content -H "Authorization: Bearer $GROQ_API_KEY" -o results.jsonl
```

Match results to inputs by `custom_id`, not by order. Also download `error_file_id` if present. Input and output files are retained up to 30 days unless you delete them (`teardown.md`).

Cancel: `POST /openai/v1/batches/{batch_id}/cancel`. List: `GET /openai/v1/batches`.

## Fine-tuning and LoRA

Groq does not offer fine-tuning. It serves LoRA adapters you train elsewhere, and only to enterprise-tier customers:

- Text-generation models only, ranks 8, 16, 32 or 64, and you must train on the exact base-model version Groq supports.
- Upload a ZIP with exactly two files, `adapter_model.safetensors` (float16) and `adapter_config.json`.
- Two deployment options per the docs: shared multi-tenant pay-per-token, or dedicated hardware instances bought by the customer (contact enterprise sales for pricing).

Flow (needs access granted):

```bash
curl -s https://api.groq.com/openai/v1/files -H "Authorization: Bearer $GROQ_API_KEY" -F purpose="fine_tuning" -F "file=@adapter.zip"
curl -s https://api.groq.com/v1/fine_tunings -H "Authorization: Bearer $GROQ_API_KEY" -H "Content-Type: application/json" \
  -d '{"input_file_id":"<FILE_ID>","name":"my-adapter","type":"lora","base_model":"<SUPPORTED_BASE_MODEL>"}'
```

The response includes `fine_tuned_model` (`ft:<base>:<org>/<name>-<suffix>`); use it as `model` in chat calls. Other endpoints: `GET /v1/fine_tunings`, `GET /v1/fine_tunings/{id}`, `DELETE /v1/fine_tunings/{id}`. Cold start grows with rank. Not available for regional/sovereign endpoints per the docs. Adapter weights stay until you delete them. For training the adapter, use the `fine-tuning-llms` skill.

## Sources

- https://console.groq.com/docs/batch
- https://console.groq.com/docs/api-reference
- https://console.groq.com/docs/lora
- https://console.groq.com/docs/your-data
