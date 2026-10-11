# Privacy and exposure for metrics

> Verified against Prometheus v3.15.0, Grafana v13.2.3, LiteLLM v1.105.0 Prometheus docs and vLLM v0.31.0, 2026-10-11

Metrics carry numbers and label values, not prompts. The risk is in labels and in who can read the endpoints.

- **Gateway labels.** LiteLLM can label series with user email, client IP, user agent, end user, key alias and team. Remove them in the gateway (`prometheus_exclude_labels: [user_email, client_ip, user_agent, end_user]`) and, as a backstop, with `metric_relabel_configs` `labeldrop` at scrape.
- **Cardinality is also a privacy and cost problem.** Per-user labels explode series; check `prometheus_tsdb_head_series` after enabling.
- **Unauthenticated `/metrics`.** vLLM and SGLang expose model names and traffic without a key. Keep engine ports private.
- **Prometheus and Alertmanager APIs have no auth by default.** Bind to loopback or use `--web.config.file` for TLS and basic auth; keep `--web.enable-lifecycle` private.
- **Grafana.** Disable sign-up, use SSO or strong admin password from a file, restrict folders, and avoid public snapshots.
- **Retention is a decision.** Set `storage.tsdb.retention.time`; deleting a label needs deleting series (`--web.enable-admin-api`, off by default).
- **Alert payloads** go to third parties (chat); keep annotations free of user data.
- **Content stays elsewhere.** Prompt capture is a tracing decision: see `llm-observability` and `langfuse`.

Checklist: labels reviewed, ports private, auth on Grafana, retention set, receiver data policy checked.

## Official links

- LiteLLM Prometheus: https://docs.litellm.ai/docs/proxy/prometheus
- Prometheus security model: https://prometheus.io/docs/operating/security/
