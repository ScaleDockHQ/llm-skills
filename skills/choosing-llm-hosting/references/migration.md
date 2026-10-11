# Migrating between tiers

> Verified against LiteLLM v1.105.0 docs (proxy config, fallbacks), vLLM v0.31.0 OpenAI-compatible server docs, provider OpenAI-compatibility pages for Anthropic, Gemini API, Together AI, Fireworks AI, Groq, DeepInfra, OpenRouter and Hugging Face, 2026-10-11

Decisions change: volume grows, a new model passes the eval, a policy shifts. This reference describes how to move a workload from one tier to another without breaking clients.

## The precondition: one endpoint

Migration is cheap only if clients never talk to a vendor directly.

- Clients call one OpenAI-compatible (and, where needed, Anthropic-compatible) base URL such as `https://llm.example.com/v1`.
- Clients use **aliases** (`chat-default`, `code`, `embed`), not vendor model IDs.
- Clients hold a gateway key, not provider keys.

If this is not true yet, the first migration is to put a gateway in front of whatever exists today (see `llm-gateway`). That step alone changes nothing for users, and every later move becomes a config change.

## Compatibility surface to check

Moving between tiers changes more than the URL. Check each item for the new target:

- [ ] **API shape**: Chat Completions, Responses, Anthropic Messages. Most providers offer an OpenAI-compatible path; some features only exist on native APIs.
- [ ] **Model behavior**: different model or quantization means different outputs. Re-run the eval.
- [ ] **Tokenizer and context**: token counts and maximum context differ; prompts near the limit may fail.
- [ ] **Tool calling and structured output**: schema support and parsing differ between engines and providers.
- [ ] **Sampling defaults**: temperature, top-p and max tokens defaults differ.
- [ ] **Streaming format**: usage reporting in streams, reasoning content fields.
- [ ] **Rate limits and timeouts**: new quotas, new latency profile.
- [ ] **Data terms**: the new target must meet the data floor.

## Migration procedure

1. **Add the new target** to the gateway as a separate deployment under a test alias. Nothing routes to it yet.
2. **Eval** the test alias with the workload's suite. Compare quality, latency and cost per task against the current target.
3. **Shadow or canary**: send a small share of real traffic (or duplicated traffic, if your data terms allow) and compare.
4. **Shift traffic** by changing the alias mapping, either all at once or with weighted load balancing.
5. **Keep the old target as a fallback** for one review cycle.
6. **Remove the old target** after the cycle, update the decision record, and tear down unused capacity (idle GPUs and reserved throughput keep billing).

## Common moves

| From → To | Why | Watch out for |
| --- | --- | --- |
| Frontier API → open-model API | Cost at volume | Quality on hard cases; keep frontier for an escalation subset |
| Open-model API → owned/rented GPUs | Utilization now above break-even, or data floor rose | Ops capacity, same model and quantization to keep behavior |
| Owned → rented GPU | Hardware end of life, need bigger accelerators | Egress, quotas, ephemeral disks |
| Rented GPU → serverless | Traffic became spiky | Cold starts |
| Any → hyperscaler | Enterprise contract, BAA, private networking | Regional model availability, quotas |
| Laptop → owned server | Team adoption | Concurrency; move to a batching engine such as vLLM |

## Rollback

Rollback is the same operation in reverse: repoint the alias. Make sure it is possible by keeping the old target's config (and capacity, if it is self-hosted) until the review date passes.

## Official links

- LiteLLM proxy config: https://docs.litellm.ai/docs/proxy/configs
- LiteLLM fallbacks: https://docs.litellm.ai/docs/proxy/reliability
- vLLM OpenAI-compatible server: https://docs.vllm.ai/en/latest/serving/online_serving/openai_compatible_server/
- Anthropic OpenAI SDK compatibility: https://platform.claude.com/docs/en/api/openai-sdk
- Gemini API OpenAI compatibility: https://ai.google.dev/gemini-api/docs/openai
