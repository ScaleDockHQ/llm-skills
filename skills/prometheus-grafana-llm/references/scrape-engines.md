# Scraping LLM engines, gateways and GPU exporters

> Verified against vLLM v0.31.0, SGLang v0.5.21, llama.cpp master b11556, llama-swap v263, LiteLLM v1.105.0, Ollama v0.40.3 and Prometheus v3.15.0, 2026-10-11

Every common OpenAI-compatible engine speaks Prometheus format on its HTTP port. These are cheap, content-free signals. Scrape engines directly; scrape the gateway separately for the user-facing view.

| Engine                   | Enable                                         | Default port              | Auth on `/metrics`                                                | Prefix       |
| ------------------------ | ---------------------------------------------- | ------------------------- | ----------------------------------------------------------------- | ------------ |
| vLLM                     | always on                                      | 8000                      | none, even with `--api-key`                                       | `vllm:`      |
| SGLang                   | `--enable-metrics`                             | 30000                     | none, exempt from `--api-key`                                     | `sglang:`    |
| llama.cpp `llama-server` | `--metrics` (env `LLAMA_ARG_ENDPOINT_METRICS`) | 9931 (8080 before b11521) | key required if `--api-key` is set                                | `llamacpp:`  |
| llama-swap               | always on                                      | 8080                      | key required if `apiKeys` is set                                  | `llamaswap_` |
| LiteLLM proxy            | `callbacks: ["prometheus"]`                    | 4000                      | key required by default; or dedicated `--prometheus_metrics_port` | `litellm_`   |
| DCGM exporter            | n/a                                            | 9400                      | none, or `--web-config-file`                                      | `DCGM_`      |
| Ollama                   | no `/metrics` endpoint                         | 11434                     | n/a                                                               | n/a          |

## Ollama has no Prometheus endpoint

At v0.40.3 Ollama exposes no `/metrics`; the upstream request (issue 3144) is open. Options: measure at the gateway (LiteLLM `/metrics` per model), poll `/api/ps` and `/api/version` with a probe or blackbox check for liveness and loaded models, or use a community exporter after you review its code (none verified here). Do not scrape `/api/ps` as if it were Prometheus format.

## Scrape jobs

`assets/prometheus.yml` has all of these. Core patterns:

```yaml
scrape_configs:
  - job_name: vllm
    static_configs:
      - targets: ["node-a:8000"]
        labels: { backend: vllm, model: "<served-model-name>" }
  - job_name: llamacpp
    authorization:
      {
        type: Bearer,
        credentials_file: /etc/prometheus/secrets/llamacpp-api-key,
      }
    static_configs:
      - targets: ["node-a:9931"]
        labels: { backend: llamacpp, model: "<model-id>" }
  - job_name: llamacpp-router-<model-id> # router mode needs ?model=<id>, one job per model
    params: { model: ["<model-id>"] }
    static_configs: [{ targets: ["node-a:9931"] }]
```

llama.cpp has no model label: one series set per process, so add `model` in the scrape config. llama-swap `/metrics` is host and GPU only; for request latency use the backend or gateway. Through `/upstream/<model_id>/metrics` a request to an unloaded model makes llama-swap load it; scrape backend ports directly, or add `^/metrics$` to `upstream.ignorePaths`.

Key facts for dashboards and rules:

- **vLLM** (labels `model_name`, `engine`): `vllm:num_requests_running`, `vllm:num_requests_waiting`, `vllm:kv_cache_usage_perc`, `vllm:num_preemptions_total`, `vllm:prompt_tokens_total`, `vllm:generation_tokens_total`, `vllm:request_success_total{finished_reason}`, histograms `vllm:time_to_first_token_seconds`, `vllm:inter_token_latency_seconds`, `vllm:e2e_request_latency_seconds`, `vllm:request_queue_time_seconds`, prefix cache `vllm:prefix_cache_hits_total` / `_queries_total`.
- **SGLang** (label `model_name`): `sglang:num_running_reqs`, `sglang:num_queue_reqs`, `sglang:token_usage`, `sglang:gen_throughput`, histograms `sglang:time_to_first_token_seconds`, `sglang:inter_token_latency_seconds`, `sglang:e2e_request_latency_seconds`, `sglang:cache_hit_rate`.
- **llama.cpp**: `llamacpp:prompt_tokens_total`, `llamacpp:tokens_predicted_total`, `llamacpp:requests_processing`, `llamacpp:requests_deferred`, `llamacpp:prompt_tokens_seconds`, `llamacpp:predicted_tokens_seconds`. `/slots` is for debugging and can reveal request details; do not scrape it.
- **LiteLLM**: counters carry `_total` (`litellm_proxy_total_requests_metric_total`, `litellm_spend_metric_total`), `litellm_request_total_latency_metric_bucket`, `litellm_deployment_state`.
- Counters gain `_total` in exposition even when docs list the base name; histograms add `_bucket`, `_sum`, `_count`.

## Read-only checks

```bash
curl -fsS http://node-a:8000/metrics  | cut -d'{' -f1 | grep -E '^vllm:' | sort -u | head -40
curl -fsS http://node-a:30000/metrics | grep -c '^sglang:'
curl -fsS -H "Authorization: Bearer $(cat ~/.llamacpp-key)" http://node-a:9931/metrics | grep -c '^llamacpp:'   # key from a file, not echoed
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.health!="up") | "\(.labels.job) \(.lastError)"'
```

After any engine upgrade, diff `cut -d'{' -f1 | sort -u` of `/metrics` against the names your dashboards and rules use. vLLM `--show-hidden-metrics-for-version=<prev minor>` temporarily re-enables deprecated metrics.

## Tuning

- `scrape_interval` 15 s default; 5 s for short debugging only. `scrape_timeout` must be at most the interval.
- `metric_relabel_configs` with `labeldrop` removes high-cardinality labels at ingest.
- Unauthenticated `/metrics` on vLLM and SGLang reveals served model names and traffic: bind engines to the private network, front them with the gateway.

## Official links

- vLLM metrics: https://docs.vllm.ai/en/latest/usage/metrics.html
- SGLang metrics: https://docs.sglang.io/references/production_metrics.html
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- llama-swap: https://github.com/mostlygeek/llama-swap
- LiteLLM Prometheus: https://docs.litellm.ai/docs/proxy/prometheus
- Ollama metrics request: https://github.com/ollama/ollama/issues/3144
