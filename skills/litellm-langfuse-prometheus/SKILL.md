---
name: litellm-langfuse-prometheus
description: One LiteLLM gateway that reports traces to Langfuse and metrics to Prometheus and Grafana, so every request has a cost, latency and prompt trail. Use to turn on the prometheus and langfuse_otel callbacks together, scrape the dedicated metrics port, set privacy and label limits, build SLO and spend queries, and debug missing traces or empty dashboards. Not for single-product depth (litellm, langfuse, llm-observability) or engine-level GPU metrics (llm-observability).
license: MIT
compatibility: Docker Compose or Kubernetes, bash, curl and jq. Needs a running LiteLLM proxy (v1.101 or newer for the dedicated metrics port) and a Langfuse project. Editing config, restarting the gateway, opening ports and starting Prometheus or Grafana need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LiteLLM + Langfuse + Prometheus

Gateway-side observability in one pass: Langfuse answers "what happened in this request and what did it cost", Prometheus and Grafana answer "is the gateway healthy and how is spend trending".

**Scope:** this wiring only. Install and operate each product from its own skill; engine and GPU metrics are in `llm-observability`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Keys come from the environment or a `0600` file and are never printed.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i -E 'litellm|langfuse|prometheus|grafana'
curl -fsS http://127.0.0.1:4000/health/readiness | jq '{status, db}'        # LiteLLM, no key needed
curl -fsS http://127.0.0.1:3000/api/public/health | jq .                      # Langfuse web
curl -fsS http://127.0.0.1:9090/-/ready                                       # Prometheus
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | [.labels.job,.health] | @tsv'
grep -n -E 'callbacks|prometheus|turn_off_message_logging' litellm-config.yaml config.yaml 2>/dev/null
```

## Decision flow

1. No LiteLLM yet: install the `litellm` skill first. No Langfuse: use Langfuse Cloud or the `langfuse` skill. No Prometheus: the `llm-observability` skill has the Prometheus and Grafana install.
2. LiteLLM older than v1.101: scrape `/metrics` on the proxy port with a dedicated low-privilege key; v1.101 or newer: prefer the dedicated metrics port (`references/prometheus-side.md`).
3. Prompts or completions are sensitive: set `turn_off_message_logging: true` before sending anything to Langfuse (`references/privacy-and-cost.md`).
4. Per-team Langfuse projects: use team or key logging settings, never credentials from request bodies (`references/langfuse-side.md`).
5. No data after the change: follow the verification ladder in `references/verify-and-troubleshoot.md`.

## Rules

- **Ask before changing the system.** Config edits, restarts, new ports and new containers need approval and an undo path.
- **Secrets never touch output.** Langfuse keys and the LiteLLM scrape key live in `0600` env files or secret files.
- **Metrics port is not authenticated.** The dedicated Prometheus listener ignores virtual keys: keep it on a private network, never behind a public ingress.
- **Opt in to OTel v2.** The `langfuse_otel` preset needs `LITELLM_OTEL_V2=true` in the proxy environment, per the OTel v2 guide.
- **Content logging is a decision.** Traces carry prompts and completions unless you turn message logging off.
- **Mind label cardinality.** Per-user and per-key labels multiply series; trim with `prometheus_exclude_labels`.
- **Verify upstream.** Versions, callback names and metric names come from upstream docs read on the writing date.

## Build the stack

- [ ] Add the `prometheus` and `langfuse_otel` callbacks plus env names to LiteLLM -> `references/langfuse-side.md`
- [ ] Expose and scrape metrics, add the Prometheus job -> `references/prometheus-side.md`
- [ ] Set privacy, retention and label limits -> `references/privacy-and-cost.md`
- [ ] Send one test request, then walk the ladder -> `references/verify-and-troubleshoot.md`
- [ ] Verify: the Prometheus target is `up`, a Langfuse trace shows the model alias, and `litellm_proxy_total_requests_metric` increases.

## Reference index

- `references/langfuse-side.md`: callbacks, env names, `LITELLM_OTEL_V2`, per-team projects, SDK callback alternative.
- `references/prometheus-side.md`: dedicated metrics port, scrape job, auth, label and metric filtering, PromQL for latency, errors and spend.
- `references/privacy-and-cost.md`: message logging, redaction, spend-log retention, cost views in both tools.
- `references/verify-and-troubleshoot.md`: end-to-end test, verification ladder, symptom table.

## Companion skills

- `litellm`: install, config, keys, budgets. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `langfuse`: self-hosting, projects, prompts, scores. Install: `npx skills add ScaleDockHQ/llms-skills --skill langfuse`.
- `llm-observability`: Prometheus and Grafana install, alert rules, engine and GPU metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `llm-gateway`: choosing a gateway. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
