# Groq setup and auth

> Verified against GroqDocs: Quickstart, OpenAI Compatibility, Projects, Billing FAQs, Client Libraries, API Reference (authentication), 2026-10-11

## Console, organization and projects

- Keys are created at https://console.groq.com/keys. Docs: https://console.groq.com/docs/quickstart.
- **Projects** isolate workloads (development, staging, production). Each project has its own API keys, customizable per-model rate limits and role-based access. Your organization role caps your project permissions. Organization roles named in the docs read are Owner (manages organization-level settings such as spend limits and model permissions) and Developer (can configure project-level model permissions). Other roles: unverified, check https://console.groq.com/docs/projects.
- Rate limits apply at the organization level; project-level limits can be customized within it. See `limits-and-spend.md`.
- Free tier and Developer tier: upgrading needs a payment method (card, US bank account or SEPA debit). Batch processing, flex processing, spend limits and higher rate limits need the Developer (paid) plan. Downgrading issues a final invoice for outstanding usage.
- Billing is monthly in arrears; new accounts have progressive billing thresholds until lifetime usage passes a documented amount. Details: https://console.groq.com/docs/billing-faqs. Prices: https://groq.com/pricing.

## Create and store a key

Create the key in the console (inside the intended project), copy it once, and store it without printing:

```bash
umask 077
mkdir -p ~/.config/groq
# put the key into the file with your editor, not on a command line
chmod 600 ~/.config/groq/api-key
export GROQ_API_KEY="$(cat ~/.config/groq/api-key)"
```

Rotate by creating a new key, deploying it, then deleting the old key in the console. The docs read do not describe a key-revocation API or per-key spend limits (spend limits are organization-wide). Unverified: check https://console.groq.com/keys for expiry or rotation options.

## SDKs and CLI

```bash
pip install groq          # Groq Python library
npm install groq-sdk      # JavaScript / TypeScript
```

Pass the key from `os.environ.get("GROQ_API_KEY")`. A Vercel AI SDK integration is documented at https://console.groq.com/docs/ai-sdk. No official command-line tool appears in the docs; use curl and jq.

## OpenAI SDK

```python
import os, openai
client = openai.OpenAI(base_url="https://api.groq.com/openai/v1", api_key=os.environ["GROQ_API_KEY"])
```

## Verify

```bash
curl -s https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY" | jq -r '.data[].id' | head
```

Without a key the endpoint returns 401.

## Data controls

Inference logs for reliability and abuse monitoring are kept up to 30 days (opt out in Data Controls), and features that need retention are kept (batch files up to 30 days, fine-tuning artifacts until deleted). Zero Data Retention is configured in https://console.groq.com/settings/data-controls, which disables the batch and fine-tuning features. Retained data is stored in US GCP buckets. See `limits-and-spend.md`.

## Sources

- https://console.groq.com/docs/quickstart
- https://console.groq.com/docs/projects
- https://console.groq.com/docs/billing-faqs
- https://console.groq.com/docs/libraries
- https://console.groq.com/docs/your-data
