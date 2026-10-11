# CoreWeave: Serverless Inference

> Verified against CoreWeave docs: Serverless Inference overview, API reference, List models, Available models, Usage information and limits, 429 and 401 support articles, and About CoreWeave Inference, 2026-10-11

Serverless Inference serves open-source foundation models through an OpenAI-compatible API, billed per token. It is the Weights & Biases Inference service, now documented by CoreWeave (Forge): the host is still `api.inference.wandb.ai`.

## Endpoint and auth

- Base URL: `https://api.inference.wandb.ai/v1`
- Auth: `Authorization: Bearer <Forge API key>` (create at `forge.coreweave.com/settings`)
- Usage attribution: `OpenAI-Project: <team>/<project>` header (OpenAI SDK: `project=`). If omitted, your default entity and the project name `inference` are used. If you belong to several teams, set it.
- Requires a Forge account with Serverless Inference credits.
- Methods: `POST /chat/completions` and `GET /models`.
- Prefix caching is applied to hosted models. No batch ingestion endpoint exists for Serverless or Dedicated Inference per the docs.

## Discover models

```bash
curl -sS https://api.inference.wandb.ai/v1/models \
  -H "Authorization: Bearer $WANDB_API_KEY" -H "OpenAI-Project: $WANDB_PROJECT" | jq -r '.data[].id'
```

Model ids look like `deepseek-ai/DeepSeek-V3.1` and `openai/gpt-oss-20b`. The docs page "Available models" lists context window, parameters and per-model pricing; do not copy prices, read that page. Pin the exact id in your config.

## Call it

```bash
curl -sS https://api.inference.wandb.ai/v1/chat/completions \
  -H "Authorization: Bearer $WANDB_API_KEY" \
  -H "OpenAI-Project: $WANDB_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model-id>","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

```python
import os, openai
client = openai.OpenAI(
    base_url="https://api.inference.wandb.ai/v1",
    api_key=os.environ["WANDB_API_KEY"],
    project=os.environ["WANDB_PROJECT"],   # "team/project"
)
r = client.chat.completions.create(model="<model-id>", messages=[{"role": "user", "content": "ping"}])
print(r.choices[0].message.content)
```

Playground: `forge.coreweave.com/inference`. LoRA adapters can be served on supported base models (see the product docs); storage for adapters can bill separately. Streaming, tools and structured output: unverified here, check each model on https://docs.coreweave.com/products/inference/serverless/models and the usage examples page before relying on them.

## Limits and spend

- Concurrency limits per W&B project and per user (not RPM or TPM as published numbers). Exceeding returns `429 Concurrency limit reached for requests`. Fix: fewer parallel requests, delays, exponential backoff, batching in your own queue. Ask Forge support (forge-support@coreweave.com) for increases.
- Default spending caps by tier (verified in the docs on 2026-10-11): Free 100 USD per month, Pro 6,000 USD per month, Enterprise 700,000 USD per year. Changing a cap needs your account executive or support. Re-check the page before quoting.
- Paid access is prepaid. When credits run out you must activate pay-as-you-go; Pro overages bill monthly.
- Monitor on the Forge Billing page.

## Data and privacy

Check the CoreWeave Forge terms and data handling pages before sending regulated data. Unverified: check https://docs.coreweave.com for retention and training-use statements.

## Sources

- https://docs.coreweave.com/products/inference/serverless
- https://docs.coreweave.com/products/inference/serverless/api-reference
- https://docs.coreweave.com/products/inference/serverless/usage-limits
- https://docs.coreweave.com/support/models/articles/why-am-i-getting-rate-limit-errors-429-w
