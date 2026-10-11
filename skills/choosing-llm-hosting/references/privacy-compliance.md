# Privacy and compliance

> Verified against OpenAI "Data controls in the OpenAI platform", Anthropic "API and data retention" and "Data residency", Gemini API Additional Terms, Gemini Enterprise Agent Platform zero data retention page, AWS Bedrock data protection and cross-Region inference, Microsoft Foundry deployment types, Fireworks, Groq, DeepInfra, OpenRouter and Hugging Face data pages, 2026-10-11

This is not legal advice. It lists the questions to ask and where each provider answers them. Policies change; re-read the linked pages before you sign off, and record the date you checked in the decision record.

## Classification sets the floor

| Data class                             | Allowed tiers (typical)                        | Conditions                                                                  |
| -------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------------- |
| Public                                 | All                                            | None beyond normal terms                                                    |
| Internal                               | All                                            | Paid tiers only (free tiers may train on data), no-training terms confirmed |
| Confidential                           | 1-4; 5-7 with contract                         | No training, bounded or zero retention, DPA signed, region chosen           |
| Regulated (PHI, PCI, special-category) | 1-3; 5-7 only with BAA/DPA                     | Eligible service and region, zero data retention where required, audit logs |
| Secret / air-gapped                    | 1-2 (3 inside an isolated tenancy you control) | No external network path at all                                             |

## Questions to answer per provider

- [ ] **Training use.** Are prompts and outputs used to train models? Is that the default, and does it differ for free vs paid use?
- [ ] **Retention.** How long are prompts and outputs kept, and why (abuse monitoring, debugging, features such as stored conversations, batches, files)?
- [ ] **Zero data retention.** Is ZDR available, who approves it, and which features does it exclude?
- [ ] **Human review.** Can staff read content (for abuse review or quality)?
- [ ] **Residency.** Where does inference run and where is data stored at rest? Can you pin a region or geography?
- [ ] **Sub-processors and upstreams.** Does the provider route to other hosts (routers and marketplaces often do)?
- [ ] **Contracts.** DPA for GDPR, BAA for HIPAA, and which services and regions are covered.
- [ ] **Logging on your side.** Your own gateway and observability stack may store prompts too.

## What the providers say (as checked on 2026-10-11)

**OpenAI API.** API data is not used for training unless you opt in. Abuse-monitoring logs may contain prompts and responses and are retained for up to 30 days by default. Eligible customers can apply for Modified Abuse Monitoring or Zero Data Retention, which need prior approval. Data residency is a project-level option available through sales, and OpenAI documents a price uplift for residency endpoints on newer models.
Source: https://developers.openai.com/api/docs/guides/your-data

**Anthropic API.** Offers zero data retention (ZDR) and HIPAA-readiness arrangements, with a feature eligibility table. Retained data is not used for training without express permission. Some "Covered Models" require 30-day retention. The `inference_geo` request parameter (or a workspace default) controls where inference runs.
Sources: https://platform.claude.com/docs/en/build-with-claude/zero-data-retention, https://platform.claude.com/docs/en/build-with-claude/data-residency, commercial retention policy https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data

**Gemini API (Google AI Studio).** Under the Unpaid Services terms, Google uses submitted content and responses to improve products, and human reviewers may read them; the terms say not to submit sensitive, confidential or personal information. API use counts as a Paid Service only through a Cloud project with active billing, which has different data terms.
Source: https://ai.google.dev/gemini-api/terms

**Gemini Enterprise Agent Platform (formerly Vertex AI).** Google states it will not use customer data to train or fine-tune models without permission. Prompt logging for abuse monitoring may apply; zero data retention requires requesting an exception, and some features (for example Grounding with Google Search) store data that cannot be disabled.
Source: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention

**AWS Bedrock.** Model providers have no access to the Bedrock deployment accounts, logs, or customer prompts and completions. Cross-Region inference can route requests to other Regions within a geography (geographic profiles) or worldwide (global profiles): choose geographic profiles, or single-Region invocation, when residency matters. PrivateLink keeps traffic off the public internet.
Sources: https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html, https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html

**Microsoft Foundry / Azure OpenAI.** Deployment types determine where processing happens: Global (any region), Data Zone (within a geography such as the EU or US), or Standard/Regional. Pick the type that matches residency requirements.
Sources: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types, https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/openai/data-privacy

**Open-model APIs (examples).**

- Fireworks: does not log or store prompt or generation data for open models without opt-in; enterprise ZDR policy available; Responses API stores data when `store=true` (the default). https://docs.fireworks.ai/guides/security_compliance/data_handling
- Groq: retains customer data only for features that need it (batch files for 30 days, fine-tuning artifacts) or as described on its page. https://console.groq.com/docs/your-data
- DeepInfra: inference inputs are not stored to disk. https://docs.deepinfra.com/account/data-privacy
- OpenRouter: does not store prompts unless you opt in; it documents which upstream providers may capture data for training, and offers ZDR routing controls. https://openrouter.ai/docs/guides/privacy/data-collection, https://openrouter.ai/docs/guides/features/zdr
- Hugging Face Inference Providers: Hugging Face does not store request bodies or responses when routing; the upstream provider's policy also applies. https://huggingface.co/docs/inference-providers/security
- Together AI: see the privacy policy. https://www.together.ai/privacy

## Residency patterns

- **Pin the region** on the hyperscaler endpoint, and avoid global routing profiles for regulated data.
- **Use data-zone deployments** (Azure) or geographic inference profiles (Bedrock) when a single region lacks capacity but data must stay within a geography.
- **Keep the gateway in the same region** as the model endpoint. A gateway in another region is a second data path.
- **Self-host** (tiers 1-3) when no provider offers the region you need.

## HIPAA, GDPR and similar

- HIPAA: you need a BAA, and only eligible services are covered. AWS: https://aws.amazon.com/compliance/hipaa-eligible-services-reference/ · Google Cloud: https://docs.cloud.google.com/docs/security/compliance/hipaa · Anthropic HIPAA readiness: see the Anthropic retention page above.
- GDPR: sign the provider's DPA, document sub-processors and transfer mechanisms, and set retention on your own logs.
- Sector or national rules may require on-prem or sovereign cloud. Treat those as an air-gapped or region-pinned floor.

## Air-gapped deployments

- Only tiers 1-2 (or an isolated tier 3 tenancy) qualify.
- Mirror model weights, container images and Python wheels through an approved transfer process.
- Disable telemetry in engines and tools, and verify with an egress-deny firewall rule rather than trusting config flags.
- Plan updates: an air-gapped stack still needs patched drivers and engines.

## Your own stack is a data path too

A gateway, tracing tool or log pipeline can store every prompt. Apply the same classification to them: set retention, redact or hash PII where possible, and restrict who can read traces. See `llm-observability` and `llm-gateway`.
