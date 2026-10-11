# Choosing LLM Hosting Skill

An agent skill that helps decide where language models should run: on a laptop, on a server you own (such as a DGX Spark or GPU box), on rented GPU VMs, on serverless GPUs, through a managed open-model API, through a frontier proprietary API, or through a hyperscaler platform (AWS Bedrock, Google's Gemini Enterprise Agent Platform, Microsoft Foundry). Hybrid is treated as an explicit outcome. The agent discovers what already exists, asks only what it cannot discover, walks a decision flow, and writes a decision record that hands off to the skill that builds it.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting
```

## Rules

- **Requirements before vendors.** Fill the intake checklist before naming any provider or product.
- **Data classification sets the floor.** No cost or quality argument overrides it.
- **Evaluate on your own tasks.** Public leaderboards are a shortlist, not a decision.
- **Price at real utilization.** Owned and rented GPUs are cheap only when busy; idle hours count.
- **Keep clients behind one endpoint so the choice stays reversible.** Point apps at a gateway, never directly at a vendor.
- **Re-decide on a schedule.** Prices, models and policies move; put a review date in the record.

## References

The `SKILL.md` overview is always loaded; the agent pulls a reference only when a step needs it.

- [`references/options.md`](references/options.md): the seven tiers with advantages, disadvantages, best for, avoid when.
- [`references/cost-model.md`](references/cost-model.md): capex vs opex, break-even utilization formula, an illustrative worked example, hidden costs, pricing page links.
- [`references/privacy-compliance.md`](references/privacy-compliance.md): retention, zero data retention, training use, residency, BAA/GDPR, air-gapped, provider data policies.
- [`references/quality-and-capabilities.md`](references/quality-and-capabilities.md): the open vs frontier gap, private evals, capability checklist.
- [`references/hybrid-patterns.md`](references/hybrid-patterns.md): local-first with fallback, routing by task, burst to cloud, dev local / prod cloud, privacy-tiered routing.
- [`references/migration.md`](references/migration.md): moving between tiers without breaking clients.
- [`references/example.md`](references/example.md): three anonymized personas and their decisions.
- [`assets/decision-record.md`](assets/decision-record.md): the decision record template.

## Companion skills

All in [ScaleDockHQ/llms-skills](https://github.com/ScaleDockHQ/llms-skills); install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `local-llms`: laptops and desktops (Ollama, LM Studio, llama.cpp, MLX).
- `self-hosted-llms`: your own servers, DGX Spark first-class, LiteLLM + llama-swap + engines behind one endpoint.
- `cloud-llms`: running and consuming LLMs in the cloud.
- `llm-gateway`: providers, keys, budgets, routing, fallbacks, API bridging.
- `llm-evals`: eval methods and quality gates.
- `llm-clients`, `model-quantization`, `fine-tuning-llms`, `llm-observability`, `self-hosted-genmedia`.

## License

MIT
