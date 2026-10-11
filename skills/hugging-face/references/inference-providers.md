# Hugging Face Inference Providers

> Verified against Inference Providers docs (index, Pricing and Billing, Chat Completion task) and the live router `GET /v1/models`, 2026-10-11

One Hugging Face token routes to many hosted providers (Cerebras, Groq, Together, Fireworks, DeepInfra, Novita, Scaleway, HF Inference and others; the partner table is on the index page). No markup on provider rates.

## Endpoint

- Base URL: `https://router.huggingface.co/v1` (OpenAI Chat Completions compatible; streaming, tools, structured output, vision for supported models).
- Auth: `Authorization: Bearer $HF_TOKEN` with a fine-grained token that has "Make calls to Inference Providers".
- Model field: `org/model` optionally followed by a policy or provider.

```bash
curl -sS https://router.huggingface.co/v1/chat/completions \
  -H "Authorization: Bearer $HF_TOKEN" -H "Content-Type: application/json" \
  -d '{"model":"openai/gpt-oss-120b:fastest","messages":[{"role":"user","content":"Say hi."}],"max_tokens":64}' \
  | jq '.choices[0].message.content, .usage'
```

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://router.huggingface.co/v1", api_key=os.environ["HF_TOKEN"])
```

## Provider selection

| Suffix             | Meaning                                                                       |
| ------------------ | ----------------------------------------------------------------------------- |
| none or `:fastest` | Highest throughput provider (default).                                        |
| `:cheapest`        | Lowest price per output token.                                                |
| `:preferred`       | First available provider in your order at hf.co/settings/inference-providers. |
| `:<provider>`      | A named provider, for example `:groq`, `:featherless-ai`.                     |

The policy can change which provider answers over time. For repeatable behavior (latency, quirks, pricing), name the provider and pin it.

## List what is available

```bash
hf models ls --warm --pipeline-tag text-generation --json     # models with at least one provider
curl -sS https://router.huggingface.co/v1/models | jq -r '.data[].id' | head       # works without auth
curl -sS https://router.huggingface.co/v1/models | jq '.data[0].providers'          # per-provider status, context_length, pricing, supports_tools, latency
```

Each model lists providers with `status`, and for many `context_length`, `pricing` (input and output), `supports_tools`, `supports_structured_output`, `first_token_latency_ms` and `throughput`. Read these live; do not copy prices.

## Billing routes

- **Routed by Hugging Face** (default): billed on your HF account at provider rates; monthly credits apply (PRO users and Team or Enterprise seats get general-purpose credits; check the current amount on the pricing page).
- **Custom provider key**: add your own provider key in Hub settings; the provider bills you, HF does not charge, and credits do not apply. Your code stays unchanged.
- **Organization billing**: send `X-HF-Bill-To: <org>` (or `bill_to="<org>"` in `InferenceClient`) to bill a Team or Enterprise org. Org admins can set a spending limit and disable providers in org settings. Enterprise: usage API at `/api/organizations/<org>/billing/usage/inference`.
- **HF Inference** provider (`hf-inference`, formerly "Inference API (serverless)"): billed by compute time times hardware price, mostly CPU models since July 2025.

## Other tasks

Embeddings (feature extraction), text to image, text to video, speech to text are available through the same token on supported providers. Use the `InferenceClient` for task-specific methods: https://huggingface.co/docs/huggingface_hub/guides/inference.

## Official links

- Index: https://huggingface.co/docs/inference-providers/en/index
- Pricing and billing: https://huggingface.co/docs/inference-providers/en/pricing
- Chat completion: https://huggingface.co/docs/inference-providers/en/tasks/chat-completion
