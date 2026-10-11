# Alerting for LLM serving

> Verified against Prometheus v3.15.0 alerting-rule docs, Alertmanager v0.34.1 configuration docs (rules and config validated with promtool and amtool), 2026-10-11

Page on what users feel; warn on what explains it. `assets/alert-rules.yml` ships 16 rules (target down, gateway error ratio and p95 latency, engine TTFT, deployment outage, queueing for vLLM, SGLang and llama.cpp, KV-cache pressure, preemptions, truncation, GPU XID and temperature, spend spike, zero-cost requests, logging failures). Thresholds are starting points; set them from SLOs.

| Severity  | Fires on                                                                         | Routed to           |
| --------- | -------------------------------------------------------------------------------- | ------------------- |
| `page`    | Symptoms: error ratio, p95 latency or TTFT over target, target down              | Pager, short repeat |
| `warning` | Causes and leading indicators: queueing, KV cache, preemptions, XID, spend spike | Chat or ticket      |

## Rule anatomy

`alert`, `expr`, `for` (hold time), optional `keep_firing_for` (stops flapping on recovery), `labels` (severity), `annotations` (summary, description, `runbook_url`). Use `for:` to absorb model swaps and rolling restarts.

## Alertmanager

`assets/alertmanager.yml` routes `severity="page"` to a `pager` receiver, groups by `alertname`, model and instance, repeats pages hourly and warnings every 4 h, and inhibits warnings on an instance whose target is down. Keep secret webhook URLs in a `0600` file via `url_file`; Slack uses `api_url_file`, email `smtp_auth_password_file`.

```bash
docker run --rm --entrypoint amtool -v "$PWD:/w" -w /w prom/alertmanager:v0.34.1 check-config alertmanager.yml
curl -fsS http://127.0.0.1:9093/api/v2/status | jq -r .versionInfo.version
curl -fsS http://127.0.0.1:9093/api/v2/alerts | jq -r '.[]|"\(.labels.alertname) \(.status.state)"'
```

## Operating

- Every alert needs an owner and a runbook URL; if nobody would act at 3 a.m., it is not a page.
- Silence during maintenance with Alertmanager silences, not by editing rules.
- Test once: stop a backend or force queueing and confirm the notification arrives. Test the receiver path too, not only the rule.
- Review volume monthly; demote or delete alerts that never lead to action.

## Pitfalls

- Division by zero on idle models: guard with a minimum-traffic term (`and sum(rate(...)) > 0.1`).
- Alerting on GPU memory used: engines pre-allocate it; use KV-cache usage.
- Metric name drift silently makes a rule return nothing; add `absent()` for one key metric per job or alert on `up`.
- `{{ $labels.x }}` renders empty if the label was aggregated away.
- llama-swap unloading backends is by design; do not page on their absence.

## Official links

- Alerting rules: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
- Alertmanager config: https://prometheus.io/docs/alerting/latest/configuration/
- Alerting practices: https://prometheus.io/docs/practices/alerting/
