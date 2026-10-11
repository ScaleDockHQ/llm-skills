---
name: sentry-ai-monitoring
description: "Sentry AI monitoring (Agent Tracing, formerly AI Insights): gen_ai spans, Conversations, model cost and agent dashboards next to errors and traces. Use to trace apps calling vLLM, llama.cpp, SGLang, Ollama or LiteLLM with sentry-sdk, send OTLP, set include_prompts and send_default_pii, sample agent runs, price local models, self-host Sentry, or fix empty Agents and zero cost. Not for choosing a stack (llm-observability)."
license: MIT
compatibility: Python 3.9+ or Node 18+ with pip or npm, bash, curl and jq; optional Docker for an OpenTelemetry Collector. Needs a Sentry project DSN (SaaS or self-hosted). Sending prompts to a hosted service and installs need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Sentry AI monitoring

A working Sentry Agent Tracing setup that records LLM calls, agent runs and conversations from apps using self-hosted endpoints and gateways, keeps prompt content under an explicit privacy decision, samples agent traffic without losing runs, and reports cost.

**Scope:** this one product: SDK integrations, manual `gen_ai` spans, OTLP, privacy and scrubbing, sampling, cost, self-hosted Sentry, update, troubleshoot. Choosing between Sentry, Langfuse, PostHog and others is `llm-observability`; engine metrics are `prometheus-grafana-llm`; the LiteLLM proxy is `litellm`; eval method is `llm-evals`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
pip show sentry-sdk litellm openai 2>/dev/null | grep -E '^(Name|Version)'
grep -rIlE --include='*.py' --include='*.ts' --include='*.js' 'sentry_sdk|@sentry/' . 2>/dev/null | head
env | cut -d= -f1 | grep -E '^(SENTRY_|OTEL_EXPORTER)' || true      # names only
docker ps --format '{{.Names}}\t{{.Image}}' | grep -Ei 'sentry|otel|litellm|vllm' || true
curl -fsS https://pypi.org/pypi/sentry-sdk/json | jq -r .info.version   # newest Python SDK
```

Ask only what discovery cannot show: SaaS or self-hosted Sentry, which clients or gateway send calls, whether prompts may leave the network, whether Sentry is already in use for errors.

## Decision flow

1. **Prompts may not leave your network:** self-hosted Sentry, or keep `send_default_pii` off. -> `references/privacy-and-sampling.md`
2. **Python or Node app calling a local OpenAI-compatible server:** SDK with the OpenAI integration and an `invoke_agent` span. -> `references/setup-and-sdks.md`
3. **LiteLLM or another gateway, or OTel sources:** -> `references/otlp-and-gateways.md`
4. **Agent runs missing:** head-based sampling. -> `references/privacy-and-sampling.md`
5. **Cost zero for a local model, dashboards, alerts:** -> `references/cost-and-alerting.md`
6. **SDK or self-hosted update, or an error:** -> `references/updating-and-troubleshooting.md`

## Rules

- **Ask before sending data off the machine.** Sentry SaaS is third-party hosting; get approval and decide content capture first.
- **Secrets never touch output.** DSNs and auth tokens live in environment variables or `0600` files; check presence by name only.
- **Content is off by default.** `send_default_pii=False` sends metadata only; `include_prompts=False` or `recordInputs`/`recordOutputs` override per integration. The `gen_ai.*` message and tool attributes are not scrubbed by default; add scrubbing rules.
- **Sample agent runs at 100 percent.** Sampling is head-based; a dropped root span loses the whole run.
- **Name agents and set conversation ids.** `gen_ai.agent.name` and `gen_ai.conversation.id` drive the dashboards and Conversations.
- **Local models need custom cost.** Unknown models cost zero; send `gen_ai.cost.total_tokens`.
- **OTLP is open beta; span events are dropped.** Put content in attributes.
- **Pin SDKs.** Agent features depend on SDK versions.
- **Verify upstream.** The product was renamed and docs move; read the docs and registries at use time.

## Workflows

### First trace

- [ ] Install the SDK (pin), set `SENTRY_DSN` from a file, `sentry_sdk.init` with tracing -> `references/setup-and-sdks.md`.
- [ ] Wrap one call in an `invoke_agent` span; open Explore, Traces, AI Spans, then Explore, Agents.

### Gateway or OTel path

- [ ] Collector (`assets/otel-collector.yaml`) or direct OTLP; canary run -> `references/otlp-and-gateways.md`.

### Privacy and sampling

- [ ] Metadata-only default, scrubbing rules, `traces_sampler`; canary string must not appear -> `references/privacy-and-sampling.md`.

### Cost

- [ ] Report tokens; send custom cost for local models -> `references/cost-and-alerting.md`.

## Reference index

| File                                         | Read when                                                             |
| -------------------------------------------- | --------------------------------------------------------------------- |
| `references/setup-and-sdks.md`               | SaaS versus self-hosted, Python and Node setup, LiteLLM, manual spans |
| `references/otlp-and-gateways.md`            | Direct OTLP, Collector, LiteLLM `sentry` callback, engines            |
| `references/privacy-and-sampling.md`         | PII settings, scrubbing rules, sampling, canary test                  |
| `references/cost-and-alerting.md`            | Custom cost attributes, dashboards, alerts                            |
| `references/updating-and-troubleshooting.md` | Version minimums, upgrades, symptom to cause to fix, teardown         |

Template: `assets/otel-collector.yaml` (validated). Script: `scripts/check.sh` (names and reachability only).

## Companion skills

- `llm-observability`: choosing a stack. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `litellm`: the proxy. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `prometheus-grafana-llm`: engine metrics and alerts. Install: `npx skills add ScaleDockHQ/llms-skills --skill prometheus-grafana-llm`.
- `llm-evals`: evaluation method. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
