---
name: choosing-llm-hosting
description: Decide where LLMs should run and record the decision. Compares seven hosting tiers (laptop or desktop local, owned server such as a DGX Spark or GPU box, rented GPU VM, serverless GPU, managed open-model API, frontier proprietary API, hyperscaler platform such as AWS Bedrock, Google Vertex AI / Gemini Enterprise Agent Platform or Microsoft Foundry) plus hybrid as an explicit outcome, with advantages, disadvantages and when to use each. Use when someone asks "should we self-host or use an API", "local vs cloud LLM", "is a GPU server worth it", "which LLM provider", "can we send this data to OpenAI/Anthropic/Gemini", "build vs buy for inference", on-prem vs cloud cost, break-even and utilization math, data residency, zero data retention, HIPAA/GDPR constraints, air-gapped requirements, open-weight vs frontier model quality, or when re-evaluating an existing LLM hosting choice. Produces a decision record and hands off to companion skills for the build.
license: MIT
compatibility: Works in any agent. Optional read-only discovery uses bash, nvidia-smi, and cloud CLIs (aws, gcloud, az) if installed. No network calls required.
metadata:
  author: ScaleDockHQ
  version: "1.0.1"
---

# Choosing LLM hosting

A decision guide for where language models should run. It turns requirements into one of seven hosting tiers, or a hybrid of them, and writes the choice down so it can be revisited.

This skill decides. It does not build. Once the decision is made, hand off to the companion skill that owns the build (see [Hand-off](#hand-off)).

## Scope

In scope: choosing a tier, comparing cost models, privacy and compliance constraints, quality and capability fit, hybrid patterns, migration between tiers, and writing the decision record.

Out of scope: installing runtimes, configuring gateways, running evals, quantizing models. Companion skills own those.

## The seven tiers

| Tier | Short name               | Example                                                                |
| ---- | ------------------------ | ---------------------------------------------------------------------- |
| 1    | Laptop / desktop local   | A model on a developer machine                                         |
| 2    | Owned server             | A DGX Spark, a GPU workstation, a rack server you own                  |
| 3    | Rented GPU VM            | A cloud GPU instance running your own serving stack                    |
| 4    | Serverless GPU           | Your model in a container that scales with requests, including to zero |
| 5    | Managed open-model API   | Open-weight models behind a provider's per-token API                   |
| 6    | Frontier proprietary API | Closed models from the labs that train them                            |
| 7    | Hyperscaler platform     | Models through your existing cloud account, IAM and network            |

Hybrid is not a fallback answer. It is an explicit outcome when different workloads land on different tiers. Full trade-offs: `references/options.md`.

## Discover first

Look before you ask. Run only read-only commands, and never print secrets or key values.

```bash
# Local hardware (tiers 1-2)
uname -sm
sysctl -n hw.memsize 2>/dev/null            # macOS: unified memory in bytes
free -g 2>/dev/null | head -2               # Linux: RAM
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null

# Local runtimes already installed
for c in ollama lms llama-server vllm litellm llama-swap; do command -v "$c" >/dev/null && echo "found: $c"; done

# Cloud accounts already authenticated (tiers 3-7)
aws sts get-caller-identity --query Account --output text 2>/dev/null
gcloud config list --format='value(core.project)' 2>/dev/null
az account show --query name -o tsv 2>/dev/null

# Which provider keys exist (names only, never values)
env | cut -d= -f1 | grep -E '_(API_KEY|TOKEN)$' | sort

# Existing gateway config
ls ./litellm*.y*ml ./config.y*ml ~/.config/litellm 2>/dev/null
```

Read what you find: a big local GPU, a hyperscaler account with committed spend, or an existing gateway all shift the answer. Then ask only what cannot be discovered.

## Intake checklist

Ask for anything still unknown. Keep it short; one round of questions is the target.

- [ ] **Data classification**: public, internal, confidential, regulated (PHI, PCI, special-category personal data), or secret/air-gapped. Who owns the data, and which contracts apply?
- [ ] **Quality bar**: which tasks, and what does "good enough" mean? Is there an existing model to beat?
- [ ] **Latency**: interactive (time to first token matters), streaming chat, or batch/offline?
- [ ] **Volume and utilization**: tokens per day now and in a year, peak vs average, hours per day of real load.
- [ ] **Budget**: monthly opex ceiling, appetite for capex, existing cloud commitments or credits.
- [ ] **Team ops capacity**: who patches drivers, rotates keys, gets paged? "Nobody" is a valid answer and rules out some tiers.
- [ ] **Compliance and residency**: required regions, BAA, DPA, zero data retention, audit logging, on-prem mandate.
- [ ] **Capabilities**: tool calling, vision, long context, reasoning, structured output, fine-tuning, embeddings.

## Decision flow

Walk these in order. Each step removes tiers; do not skip ahead to vendors.

1. **Apply the data floor.** Classification sets the minimum control level.
   - Air-gapped or secret: tiers 1-2 only (or tier 3 inside an isolated tenancy you control).
   - Regulated: tiers 1-3, or tiers 5-7 only with a signed BAA/DPA, zero or bounded retention, and the right region. Check each provider's data page, not its marketing page.
   - Internal or public: all tiers remain.
     → `references/privacy-compliance.md`
2. **Apply the quality bar.** If only frontier models pass your own eval, tiers 1-5 drop out for that workload unless an open-weight model is close enough. If a small open model passes, tiers 1-4 stay cheap options.
   → `references/quality-and-capabilities.md`
3. **Apply latency and shape.** Interactive and spiky favors APIs (5-7) or always-warm capacity. Batch and offline favors batch APIs or a busy owned box. Serverless GPU (4) fits only where cold starts are acceptable.
4. **Price at real utilization.** Compare per-token API cost against the fully loaded cost of GPU hours at the utilization you will actually reach, including idle time, power, egress and people.
   → `references/cost-model.md`
5. **Check ops capacity.** Tiers 2-4 need someone to own drivers, engines, upgrades and on-call. If nobody can, prefer 5-7.
6. **Check fit with what exists.** An existing hyperscaler account with IAM, private networking and committed spend often makes tier 7 the lowest-friction choice for regulated workloads.
7. **Decide per workload.** If different workloads land on different tiers, the outcome is hybrid.
   → `references/hybrid-patterns.md`
8. **Write the decision record** from `assets/decision-record.md`, including the re-decision date and the exit plan.

Quick heuristics (not substitutes for the flow):

- Prototype, single developer, private data: tier 1.
- Steady high volume on open models with ops capacity: tier 2 or 3.
- Spiky, low average volume, custom model: tier 4.
- Open models, no ops team: tier 5.
- Hardest reasoning, coding or agentic tasks: tier 6.
- Enterprise with a cloud contract, regulated data: tier 7.

## Rules

- **Requirements before vendors.** Fill the intake checklist before naming any provider or product.
- **Data classification sets the floor.** No cost or quality argument overrides it.
- **Evaluate on your own tasks.** Public leaderboards are a shortlist, not a decision.
- **Price at real utilization.** Owned and rented GPUs are cheap only when busy; idle hours count.
- **Keep clients behind one endpoint so the choice stays reversible.** Point apps at a gateway, never directly at a vendor.
- **Re-decide on a schedule.** Prices, models and policies move; put a review date in the record.

## Workflows

### New decision

- [ ] Run [Discover first](#discover-first) and summarize what exists.
- [ ] Complete the [intake checklist](#intake-checklist).
- [ ] Walk the [decision flow](#decision-flow) per workload → `references/options.md`.
- [ ] Build a cost comparison with the formulas → `references/cost-model.md`.
- [ ] Check data terms for every shortlisted provider → `references/privacy-compliance.md`.
- [ ] Plan a private eval on real tasks → `references/quality-and-capabilities.md` (hand the eval itself to `llm-evals`).
- [ ] If more than one tier wins, pick a hybrid pattern → `references/hybrid-patterns.md`.
- [ ] Write the record from `assets/decision-record.md`.
- [ ] Hand off to the build skill.

### Re-evaluate an existing choice

- [ ] Read the existing decision record; note what changed (volume, models, prices, policy, team).
- [ ] Re-run the cost model with measured utilization, not the original estimate.
- [ ] Re-run the private eval with current candidates.
- [ ] If the answer changes, plan the move → `references/migration.md`.
- [ ] Update the record and set the next review date.

### Explain options to a stakeholder

- [ ] Use the persona closest to their situation → `references/example.md`.
- [ ] Present the per-tier trade-offs → `references/options.md`.

## Hand-off

| Outcome                                         | Companion skill        |
| ----------------------------------------------- | ---------------------- |
| Tier 1 (laptop/desktop)                         | `local-llms`           |
| Tier 2 (owned server, DGX Spark)                | `self-hosted-llms`     |
| Tiers 3-7 (any cloud)                           | `cloud-llms`           |
| One endpoint, routing, fallbacks, keys, budgets | `llm-gateway`          |
| Choosing and validating models                  | `llm-evals`            |
| Fitting a model onto smaller hardware           | `model-quantization`   |
| Custom model behavior                           | `fine-tuning-llms`     |
| Tracing, cost and latency dashboards            | `llm-observability`    |
| Connecting apps and coding tools                | `llm-clients`          |
| Image, video, audio generation                  | `self-hosted-genmedia` |

Install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

## References

- `references/options.md`: each tier with what it is, advantages, disadvantages, best for, avoid when.
- `references/cost-model.md`: capex vs opex, utilization break-even formula with an illustrative worked example, tokens/s to tokens/month, power, idle, egress, ops time, pricing links.
- `references/privacy-compliance.md`: retention, zero data retention programs, training opt-out, residency, BAA/GDPR, air-gapped; provider data-usage policy links.
- `references/quality-and-capabilities.md`: open vs frontier gap, private evals, capability checklist.
- `references/hybrid-patterns.md`: local-first with cloud fallback, routing by task, burst to cloud, dev local / prod cloud, privacy-tiered routing.
- `references/migration.md`: moving between tiers without breaking clients.
- `references/example.md`: three anonymized personas and their decisions.
- `assets/decision-record.md`: the decision record to fill in.
