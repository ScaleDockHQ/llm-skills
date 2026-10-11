# Example decisions: three anonymized personas

> Verified against the other references in this skill (options, cost model, privacy and compliance, hybrid patterns), 2026-10-11

Three fictional teams walk through the intake checklist and decision flow. Names, numbers and hosts are placeholders. No prices are given; each team ran the formulas in `cost-model.md` with its own quotes.

## Persona A: solo consultant with client code

**Intake**
- Data: confidential client source code under NDA; contracts forbid sending it to third parties without consent.
- Quality bar: code explanation, refactoring suggestions, test generation. Frontier quality is nice but not required for most tasks.
- Latency: interactive, inside an editor.
- Volume: one user, a few hours a day.
- Budget: small; already owns a laptop with a large unified memory.
- Ops capacity: themselves, minimal.
- Compliance: NDA only.

**Discovery found** a laptop with plenty of unified memory, Ollama installed, no cloud accounts.

**Decision flow**
1. Data floor: third-party APIs excluded for client code unless a client consents. Tiers 1-2 remain for that work.
2. Quality: a mid-size open coding model passed their private eval on 60 real tasks from past projects (with client consent, redacted).
3. Cost: tier 1 costs nothing extra.

**Decision: tier 1 (local) for client work; tier 6 (frontier API) only for their own non-client projects.** Both are reached through one local gateway endpoint so editor settings never change.

**Hand-off:** `local-llms`, `llm-clients`. Review in six months or when a client contract changes.

## Persona B: 40-person product company with a support assistant

**Intake**
- Data: customer support tickets, containing personal data (names, emails, order details). GDPR applies.
- Quality bar: answer drafting and classification with retrieval. A large open model and two frontier models were candidates.
- Latency: interactive for agents; batch for nightly ticket tagging.
- Volume: steady during business hours in one region, quiet at night and weekends.
- Budget: opex preferred; no appetite for hardware.
- Ops capacity: one platform engineer, part-time.
- Compliance: GDPR with EU residency preferred.

**Discovery found** an existing Google Cloud project (gcloud authenticated), no GPUs, provider keys for one open-model API in the environment.

**Decision flow**
1. Data floor: personal data → providers need a DPA, no training, EU region.
2. Quality: the large open model matched frontier on classification; frontier was clearly better on drafting tricky replies.
3. Latency/shape: drafting is interactive; tagging is batch.
4. Cost: at business-hours-only utilization, rented GPUs never beat per-token pricing; break-even needed far more busy hours than they have.
5. Ops: part-time engineer → avoid running GPUs.
6. Fit: existing Google Cloud contract and billing.

**Decision: hybrid, all tier 7 plus tier 5.** Drafting on a frontier model through their hyperscaler platform in an EU region; classification on an open model through the same platform's model-as-a-service catalog (or an open-model API with a DPA and EU processing, if the platform lacks the model); nightly tagging on the batch API. One gateway, aliases `draft`, `classify`, `tag-batch`.

**Hand-off:** `cloud-llms`, `llm-gateway`, `llm-evals`, `llm-observability`. Review quarterly; re-run the cost model if volume doubles.

## Persona C: research lab with sensitive datasets and a DGX Spark

**Intake**
- Data: unpublished research data and health-adjacent records under a data-use agreement that requires on-prem processing.
- Quality bar: summarization and extraction from long documents; coding help for researchers.
- Latency: mixed; most jobs are batch.
- Volume: moderate, with bursts before deadlines.
- Budget: grant money for capex; tight opex.
- Ops capacity: one research engineer who already runs lab servers.
- Compliance: on-prem mandate for the regulated dataset only.

**Discovery found** a DGX Spark on the lab network (node-a, 10.0.0.1), vLLM and LiteLLM installed, an AWS account used for other work.

**Decision flow**
1. Data floor: regulated dataset → tier 2 only. Other work (public papers, code) has no floor.
2. Quality: an open model on the Spark passed extraction and summarization; frontier was better for complex coding.
3. Cost: the Spark is already owned; marginal cost is power. Burst capacity before deadlines would otherwise mean long queues.
4. Ops: the engineer can own the Spark and gateway.

**Decision: hybrid with privacy-tiered routing.** Regulated jobs use only the on-prem alias, enforced by a dedicated gateway key that has no cloud models. Everything else is local-first with cloud fallback: the Spark first, overflow to the same open model on rented GPUs or an open-model API during deadline bursts, and a frontier API alias for complex coding.

**Hand-off:** `self-hosted-llms` (Spark, LiteLLM, engines), `cloud-llms` (overflow and frontier entries), `llm-gateway` (keys per data class). Review each semester or when the data-use agreement is renewed.

## What the three have in common

- Requirements first; vendors only after the data floor and eval.
- One gateway endpoint so the decision stays reversible.
- A written record with a review date (`templates/decision-record.md`).
