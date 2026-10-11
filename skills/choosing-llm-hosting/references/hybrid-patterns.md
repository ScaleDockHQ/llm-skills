# Hybrid patterns

> Verified against LiteLLM v1.105.0 docs (Fallbacks / reliability, provider budget routing), 2026-10-11

Hybrid means different requests run on different tiers, on purpose. It is the most common end state for teams beyond a single prototype. Every pattern below assumes clients talk to **one gateway endpoint**, and the gateway decides where a request goes. Gateway configuration (model groups, fallbacks, budgets, keys) is owned by the `llm-gateway` skill; cloud-specific entries are in `cloud-llms`.

## 1. Local-first with cloud fallback

Requests go to a self-hosted model (tier 1 or 2). If it is down, overloaded or times out, the gateway retries on a cloud model (tier 5, 6 or 7).

- Good for: owned-server teams that want uptime without buying a second box.
- Watch: the fallback target must meet the data floor for **all** traffic that can fail over. If some data must never leave, exclude it from fallback.
- Gateway feature: fallbacks between model groups, retries and cooldowns (in LiteLLM: `router_settings.fallbacks`, `num_retries`, `allowed_fails`, `cooldown_time`).

## 2. Routing by task

Each workload gets the cheapest tier that passes its eval: for example, extraction and embeddings on a local model, coding agents on a frontier API, nightly summarization on a batch API.

- Good for: mixed workloads with different quality bars.
- Watch: clients choose a model name (an alias such as `fast`, `smart`, `embed`), never a vendor model ID, so you can repoint aliases later.

## 3. Burst to cloud

Owned capacity handles the baseline; peaks overflow to rented GPUs (tier 3), serverless (tier 4) or an API (tier 5-7).

- Good for: predictable baselines with occasional spikes (month-end, launches).
- Watch: the overflow model should behave like the base model. Overflowing from an open model to the same open model on an open-model API keeps behavior consistent.
- Gateway feature: load balancing across deployments in one model group with rate limits per deployment, plus fallbacks.

## 4. Dev local, prod cloud

Developers use local models (tier 1) for iteration; production uses a cloud tier.

- Good for: cheap, private development without shared-GPU contention.
- Watch: dev and prod models differ, so results differ. Run the eval suite against the production model before release.

## 5. Privacy-tiered routing

Classify each request (by caller, team key, header or content scan) and route by class: regulated data to self-hosted or a BAA-covered hyperscaler region, everything else to the cheapest passing tier.

- Good for: organizations with mixed data classes on one platform.
- Watch: classification must happen **before** the request leaves your network. Fail closed: if a request cannot be classified, send it to the most restrictive tier.
- Gateway feature: separate virtual keys or teams with access only to allowed model groups.

## 6. Frontier for the hard subset

Most traffic runs on an open model; a router or a confidence check escalates hard cases to a frontier model.

- Good for: high-volume workloads where a small fraction needs top quality.
- Watch: measure the escalation rate; if it creeps up, the cost model changes.

## Choosing a pattern

| Situation | Pattern |
| --- | --- |
| Own a server, need uptime | 1 |
| Several workloads, different quality bars | 2 |
| Steady base plus spikes | 3 |
| Developers want private, free iteration | 4 |
| Mixed data classes | 5 |
| High volume, few hard cases | 6 |

Patterns combine. A common shape: privacy-tiered routing (5) on top of local-first with cloud fallback (1) and routing by task (2).

## Requirements that make hybrid safe

- [ ] One gateway endpoint for all clients; aliases instead of vendor model IDs.
- [ ] Each alias maps to models that passed the eval for that workload.
- [ ] Fallback chains respect the data floor.
- [ ] Budgets per provider and alerts on spend (see `llm-gateway`; cloud budgets in `cloud-llms`).
- [ ] Tracing shows which tier served each request (see `llm-observability`).

## Official links

- LiteLLM fallbacks and reliability: https://docs.litellm.ai/docs/proxy/reliability
- LiteLLM provider budget routing: https://docs.litellm.ai/docs/proxy/provider_budget_routing
