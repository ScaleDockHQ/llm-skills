# Cost model

> Verified against OpenAI Batch and prompt caching guides, Anthropic Message Batches and prompt caching docs, Gemini API batch mode docs, RunPod Serverless endpoint configuration docs, Hugging Face Inference Endpoints autoscaling docs, 2026-10-11

Prices change often. This reference gives formulas and links to pricing pages instead of numbers. The worked example uses made-up round numbers and is labeled **illustrative**. Replace every input with a current quote before deciding.

## The two cost shapes

| Shape                       | Tiers               | You pay for                                  | Cost grows with          |
| --------------------------- | ------------------- | -------------------------------------------- | ------------------------ |
| Per token (opex)            | 5, 6, 7 on-demand   | Input + output tokens                        | Usage                    |
| Per hour of capacity (opex) | 3, 4, 7 provisioned | GPU time, busy or idle                       | Time the capacity exists |
| Capex + running cost        | 1, 2                | Hardware up front, then power, space, people | Time, mostly fixed       |

The core question: **at the utilization you will really reach, is a token cheaper from capacity you pay for by the hour (or own) than from an API that bills per token?**

## Converting throughput to tokens per month

```
tokens_per_month = aggregate_tokens_per_second × 3600 × busy_hours_per_day × days_per_month
```

- Use **aggregate** throughput under your real concurrency, not single-stream speed. Measure it with the benchmark protocol in `cloud-llms` (or `self-hosted-llms`).
- `busy_hours_per_day` is the honest number of hours with enough requests to keep the engine batching. Utilization is `busy_hours / 24`.

## Per-token API cost

```
api_cost_per_month = (input_tokens × price_in + output_tokens × price_out) / 1,000,000
```

Adjust for features that discount tokens:

- **Batch APIs** (OpenAI Batch, Anthropic Message Batches, Gemini batch mode): discounted versus synchronous calls, with up to a 24-hour turnaround. Use them for anything that is not interactive.
- **Prompt caching** (automatic on OpenAI and Gemini 2.5+ models; `cache_control` on Anthropic): repeated prefixes are billed at a reduced cached-input rate. Long system prompts, RAG context and agent loops benefit most.
- **Provisioned or reserved throughput** on hyperscalers changes the shape to per-hour capacity; treat it like tier 3.

## Capacity cost (owned or rented)

**Rented (tier 3), per month:**

```
rented_cost = gpu_hourly_rate × hours_running + storage + egress + ops_time_cost
```

If you shut instances down when idle, `hours_running` shrinks, but startup time (pulling weights) and quotas become your problem.

**Owned (tier 2), per month:**

```
owned_cost = hardware_price / amortization_months
           + power_kw × 24 × days × electricity_price × PUE
           + hosting_or_colo + network
           + ops_time_cost
```

- `power_kw` is average draw, not nameplate. Measure at the wall under load and at idle.
- `PUE` (cooling overhead) is about 1.0 under a desk and higher in a server room or colo.
- `amortization_months` is often 24-36; accelerators lose value as new generations ship.

**Serverless (tier 4), per month:**

```
serverless_cost = per_second_rate × (active_seconds + cold_start_seconds) + warm_worker_hours × hourly_equivalent
```

Keeping workers warm (RunPod "active workers", Modal `min_containers`, a minimum replica count) removes cold starts but bills continuously.

## Cost per million tokens from capacity

```
cost_per_M_tokens = monthly_capacity_cost / (tokens_per_month / 1,000,000)
```

## Break-even utilization

Set capacity cost per token equal to the API price and solve for hours:

```
break_even_busy_hours_per_day =
    monthly_capacity_cost / (blended_api_price_per_M × aggregate_tps × 3600 × days / 1,000,000)
```

`blended_api_price_per_M` weights input and output by your real mix:

```
blended = (in_share × price_in) + (out_share × price_out)
```

If your expected busy hours are well above the break-even, capacity wins. If they are below, the API wins. Near the line, prefer the API: it carries no idle risk and no ops time.

## Worked example (illustrative numbers only)

> All numbers below are made up for the arithmetic. They are not quotes and not benchmarks.

Inputs:

- Owned server: hardware 12,000 (any currency) amortized over 36 months → 333/month.
- Power: 0.5 kW average × 24 h × 30 days × 0.30 per kWh × PUE 1.0 → 108/month.
- Ops time: 4 hours/month × 75 per hour → 300/month.
- Monthly capacity cost: 333 + 108 + 300 = **741**.
- Measured aggregate throughput at target concurrency: 400 tokens/s.
- Comparable API blended price: 0.60 per million tokens.

Break-even:

```
741 / (0.60 × 400 × 3600 × 30 / 1,000,000)
= 741 / (0.60 × 43.2)
= 741 / 25.92
≈ 28.6 busy hours per day
```

That is more than 24, so at these illustrative prices the owned box **never** breaks even against that API on cost alone. It would take a pricier API model, higher throughput, cheaper hardware, or a non-cost reason (data floor, offline, fixed budget) to justify it.

Change one input: if the comparable API costs 3.00 per million tokens, break-even falls to about 5.7 busy hours per day, and the box wins for a team that keeps it busy through the working day.

The lesson: **utilization and the comparison model dominate the answer.** Always compare against the cheapest API model that passes your eval, not the most expensive one.

## Hidden costs checklist

- [ ] Idle GPU hours (rented VMs left running, warm serverless workers, provisioned throughput at night).
- [ ] Egress: traffic leaving a cloud region or provider, including responses and model downloads across regions.
- [ ] Storage: model weights on persistent disks or network volumes, snapshots, logs.
- [ ] Ops time: upgrades, incidents, security patches, key rotation, on-call.
- [ ] Evaluation and migration time when models change.
- [ ] Gateway, observability and database infrastructure.
- [ ] Support plans and enterprise minimums required for retention or residency programs.
- [ ] Residency uplifts: some providers charge more for regional processing (for example, OpenAI documents an uplift for data-residency endpoints on newer models).

## Pricing pages

Frontier and hyperscaler:

- OpenAI API pricing: https://developers.openai.com/api/docs/pricing
- Anthropic pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- AWS Bedrock pricing: https://aws.amazon.com/bedrock/pricing/
- Gemini Enterprise Agent Platform pricing: https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing
- Azure OpenAI in Microsoft Foundry pricing: https://azure.microsoft.com/en-us/pricing/details/azure-openai/

Open-model APIs:

- Together AI: https://www.together.ai/pricing
- Fireworks AI: https://fireworks.ai/pricing
- DeepInfra: https://deepinfra.com/pricing
- OpenRouter (per-model prices): https://openrouter.ai/models
- Hugging Face: https://huggingface.co/pricing
- Groq: https://groq.com/pricing (redirected to the homepage when checked; look for the pricing link there)

GPU capacity:

- Lambda: https://lambda.ai/pricing
- RunPod: https://www.runpod.io/pricing
- Vast.ai: https://vast.ai/pricing
- CoreWeave: https://www.coreweave.com/pricing
- Modal: https://modal.com/pricing
- Hugging Face Inference Endpoints: https://huggingface.co/docs/inference-endpoints/en/pricing
- AWS EC2 on-demand: https://aws.amazon.com/ec2/pricing/on-demand/
- Google Compute Engine (GPUs): https://cloud.google.com/products/compute/pricing
- Azure virtual machines: https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/
