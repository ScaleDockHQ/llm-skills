# Anthropic API: data controls, retention and ZDR

> Verified against Claude Platform docs: API and data retention, Message Batches, Files API, Prompt caching, Rate limits (inference_geo), 2026-10-11

## Defaults and commitments

- Retained data is never used for training without your express permission.
- Conversation content (prompts and outputs) is **not retained by default** on the Claude API, except for Covered Models (below) and where a feature needs storage.
- Where the Claude API is used, Anthropic is the data processor. On Amazon Bedrock and Google Cloud's Agent Platform the cloud provider is; use their retention docs (`aws-bedrock`, `google-vertex-ai`).
- Even with ZDR or HIPAA readiness, data can be retained where law requires or where automated trust-and-safety systems flag it (up to 2 years).

## Arrangements (contact Anthropic sales)

| Arrangement     | What it does                                                                                                               |
| --------------- | -------------------------------------------------------------------------------------------------------------------------- |
| ZDR             | Prompts and responses are not stored at rest after the response; enabled per organization                                  |
| HIPAA readiness | Safeguards for PHI with a BAA; self-serve in Console > Settings > Data retention for eligible orgs; permanent once enabled |

- ZDR is enabled per organization; a new organization needs it enabled separately. Console and playground use is not covered; neither are Claude Managed Agents, Free/Pro/Max plans, or CORS (route browser calls through a backend).
- HIPAA readiness blocks non-eligible features with `400 invalid_request_error`; use a separate organization for non-HIPAA work. Do not put PHI in JSON schemas (schemas are cached separately for up to 24 hours).
- Claude Platform on AWS follows the same policy; ZDR on request, HIPAA readiness unavailable.

## Covered Models need 30-day retention

Some models are designated Covered Models and require 30-day retention, so they are not available under ZDR unless Anthropic authorizes it. Without retention enabled you get `400 invalid_request_error: In order to access this model, your organization or workspace must have data retention enabled.` A ZDR organization can enable 30-day retention for one workspace only (Console > Settings > Workspaces > workspace > Security > Data retention > Privacy controls). Check the current model list on the retention page.

## Feature eligibility (excerpt; re-read the table)

| Feature                                                                                | ZDR             | Notes                                                         |
| -------------------------------------------------------------------------------------- | --------------- | ------------------------------------------------------------- |
| Messages, token counting, thinking, effort, citations, PDF, data residency, 1M context | Yes             |                                                               |
| Prompt caching                                                                         | Yes             | KV cache and hashes held in memory for the TTL, then deleted  |
| Structured outputs, strict tool use                                                    | Yes (qualified) | Only the JSON schema is cached, up to 24 hours since last use |
| Message Batches                                                                        | **No**          | 29-day retention, async storage                               |
| Files API                                                                              | **No**          | Until deleted or `expires_at`                                 |
| Code execution, programmatic tool calling                                              | **No**          | Container data up to 30 days                                  |
| MCP connector, Agent skills, Managed Agents                                            | **No**          | Per standard policy; sessions persist until deleted           |
| Web search, web fetch                                                                  | Yes             | Dynamic filtering not eligible                                |

Using a "No" feature does not block the request under ZDR: it steps outside your arrangement for that data.

## Data residency

The `inference_geo` request parameter (or a workspace default) controls where inference runs; it is ZDR and HIPAA eligible. Rate limits are shared across `inference_geo` values. Check the docs for supported values and pricing effects.

## Practical rules

- Decide per alias whether the data class allows the API at all (`choosing-llm-hosting`, `cloud-llms`).
- Avoid Batches, Files and code execution for data that needs ZDR.
- Delete files and batches when done (`references/teardown.md`).
- Gateways and tracing add their own copies (`llm-observability`).

## Where to read more

- https://platform.claude.com/docs/en/build-with-claude/api-and-data-retention
