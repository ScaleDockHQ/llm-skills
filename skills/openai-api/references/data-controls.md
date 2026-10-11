# OpenAI API: data controls, retention and ZDR

> Verified against OpenAI docs: Data controls in the OpenAI platform ("Your data"), Prompt caching, Batch API, 2026-10-11

## Defaults

- Data sent to the API is **not used for training** (the endpoint table lists "No" for every API endpoint).
- **Abuse monitoring logs** are generated for all API usage and kept up to 30 days by default (longer only where law or harm prevention requires). They can contain prompts, responses and derived metadata.
- **Application state** (stored objects) depends on the endpoint: for example Responses are stored 30 days by default or when `store` is `true`; Files, Batches, Fine-tuning jobs, Conversations, Vector stores and Assistants-era objects persist until you delete them.

## Controls that need OpenAI approval

| Control                   | What it does                                                                                           |
| ------------------------- | ------------------------------------------------------------------------------------------------------ |
| Modified Abuse Monitoring | Excludes customer content from abuse-monitoring logs on all endpoints                                  |
| Zero Data Retention (ZDR) | Same exclusion plus `store` on `/v1/responses` and `/v1/chat/completions` is always treated as `false` |
| Private Safety Processing | Automated safety monitoring while preserving ZDR protections                                           |

Approval and extra requirements apply; contact OpenAI. Once approved, Settings > Organization > Data controls gets a Data Retention tab: choose a mode for the organization, then per project `default` (inherit), a specific mode, or None. OpenAI may make specific models ineligible for a customer with advance written notice, and image or file inputs are scanned for CSAM and retained for review if flagged, even under ZDR.

## Endpoint eligibility (excerpt; always re-read the table)

| Endpoint                                                                                                  | ZDR eligible     | Notes                                                                                                         |
| --------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------- |
| `/v1/responses`, `/v1/chat/completions`                                                                   | Yes, with limits | `store` forced to `false`; background mode, hosted tools and third-party MCP servers have their own retention |
| `/v1/embeddings`, `/v1/completions`, `/v1/realtime`, `/v1/audio/speech`                                   | Yes              |                                                                                                               |
| `/v1/images/*`                                                                                            | Yes, with limits | Only listed image models                                                                                      |
| `/v1/files`, `/v1/batches`, `/v1/fine_tuning/jobs`, `/v1/vector_stores`, `/v1/conversations`, `/v1/evals` | No               | Persist until deleted                                                                                         |

Other details from the page: audio outputs are stored for 1 hour for multi-turn use; background mode keeps data about 10 minutes for polling; prompt caching can hold encrypted KV tensors in GPU-local storage and drops them by the 24-hour mark; Assistants-era objects are deleted 30 days after you delete them.

## Practical rules

- Decide per alias whether the data class allows OpenAI at all (`choosing-llm-hosting`, `cloud-llms`).
- If you cannot get ZDR, set `store: false` on Responses and avoid Files, Batch, Conversations and vector stores for sensitive data.
- Delete stored responses and files when done (`references/teardown.md`).
- Gateways and tracing tools add their own copies; treat them as part of the data path (`llm-observability`).

## Data residency

Data residency is a project configuration option for eligible customers; contact OpenAI sales. Residency endpoints carry a surcharge for eligible models released on or after 2026-03-05 (check the page for the current figure). Per the Batch guide, some current models support EU data residency with Standard, Flex and Batch processing; confirm model eligibility in the residency section.

## Where to read more

- https://developers.openai.com/api/docs/guides/your-data
- https://developers.openai.com/api/docs/guides/prompt-caching
