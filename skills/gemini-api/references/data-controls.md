# Gemini API: data use, retention and terms

> Verified against Gemini API Additional Terms of Service, Billing, Files, Batch API, 2026-10-11

## Paid vs unpaid services

| Aspect              | Unpaid services (free quota, AI Studio without billing)                                            | Paid services (paid quota)                                                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Use of your content | Prompts and responses may be used to improve Google products and ML; human reviewers may read them | Prompts, system instructions, cached content, files and responses are not used to improve products; processed under the Data Processing Addendum |
| Sensitive data      | Do not submit sensitive, confidential or personal data                                             | Allowed subject to your own policy                                                                                                               |

- In the EEA, Switzerland and the UK the paid-service data terms apply to all services, including free quota, and only Paid Services may be used when making API clients available to users there.
- AI Studio access counts as a paid service when your account has a Cloud project with an active billing account (or is a Workspace enterprise account).
- Other operational data (usage metrics, safety triggers, errors) is still collected for paid services.
- Content uploaded for tuning is used only for tuning and may be retained with the tuned model; deleting the tuned model deletes it.

## Feature-specific storage

- **Grounding with Google Search:** prompts, context and output are stored for 30 days for creating grounded results and debugging, and grounded results have display and no-caching or no-training obligations. Read the terms before enabling.
- **Grounding with Google Maps:** separate restrictions (no training on Maps data); read the terms.
- **Files API:** 48 hours, then deleted (`references/features.md`).
- **Batch results:** kept 6 weeks.
- **Explicit caches:** until TTL expiry or deletion.
- Zero data retention, regional residency and customer-managed keys are not offered in the pages read; for those controls use Vertex AI (`google-vertex-ai`). Unverified: check the terms page for any current exception.

## Practical rules

- Classify data before choosing the key: sensitive data needs a project on a paid, billed account.
- Keep free-tier keys out of production gateways.
- Delete files and caches when done (`references/teardown.md`).
- Gateways and tracing add their own copies (`llm-observability`).

## Where to read more

- https://ai.google.dev/gemini-api/terms
- https://ai.google.dev/gemini-api/docs/billing
