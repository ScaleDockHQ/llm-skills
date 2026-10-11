# Groq teardown

> Verified against GroqDocs: API Reference (files, batches, fine_tunings), Your Data, Spend Limits, LoRA Inference, 2026-10-11

Groq has no servers to stop. What persists or bills: batches, uploaded files, LoRA adapters, API keys and the plan itself. List before deleting and confirm ownership.

## 1. Batches

```bash
curl -s https://api.groq.com/openai/v1/batches -H "Authorization: Bearer $GROQ_API_KEY" | jq -r '.data[] | [.id,.status] | @tsv'
curl -s -X POST https://api.groq.com/openai/v1/batches/<BATCH_ID>/cancel -H "Authorization: Bearer $GROQ_API_KEY" | jq .status
```

Cancel moves a running batch to `cancelling` then `cancelled`. Download results first.

## 2. Files

```bash
curl -s https://api.groq.com/openai/v1/files -H "Authorization: Bearer $GROQ_API_KEY" | jq -r '.data[] | [.id,.purpose,.filename] | @tsv'
curl -s -X DELETE https://api.groq.com/openai/v1/files/<FILE_ID> -H "Authorization: Bearer $GROQ_API_KEY"
```

Delete batch input, output and error files, and fine-tuning ZIPs. Otherwise batch files expire after 30 days.

## 3. LoRA adapters (enterprise)

```bash
curl -s https://api.groq.com/v1/fine_tunings -H "Authorization: Bearer $GROQ_API_KEY" | jq .
curl -s -X DELETE https://api.groq.com/v1/fine_tunings/<ID> -H "Authorization: Bearer $GROQ_API_KEY"
```

Delete the adapter and its uploaded file. A dedicated hardware instance for LoRA is a contract matter: contact your Groq account team to end it.

## 4. Keys

Delete keys in the console: https://console.groq.com/keys. Rotate by creating the new key, updating consumers, then deleting the old one. No revocation API appears in the docs read. After deleting a leaked key, check the console usage view for unexpected spend.

## 5. Spend backstop and plan

Lower or keep the monthly spend limit at https://console.groq.com/settings/billing/limits. Downgrading to Free is in Settings, Billing and issues a final invoice that must be paid first.

## 6. Data

Enable Zero Data Retention or opt out of logging in https://console.groq.com/settings/data-controls if policy requires. This disables batch and fine-tuning.

## 7. Verify

```bash
for p in batches files; do curl -s https://api.groq.com/openai/v1/$p -H "Authorization: Bearer $GROQ_API_KEY" | jq -r ".data | length"; done
```

Expect 0 for resources you meant to remove, and confirm the keys list in the console.

## Sources

- https://console.groq.com/docs/api-reference
- https://console.groq.com/docs/your-data
- https://console.groq.com/docs/spend-limits
- https://console.groq.com/docs/lora
