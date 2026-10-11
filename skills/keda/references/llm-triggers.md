# Triggers for LLM serving

> Verified against KEDA v2.21.0, 2026-10-11

## Which signal

| Signal                         | Trigger                                                         | Use it for                                                          |
| ------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| Requests waiting in the engine | Prometheus on `vllm:num_requests_waiting`                       | Primary scale-out signal for online serving.                        |
| KV-cache pressure              | Prometheus on `vllm:kv_cache_usage_perc`                        | Guard: waiting can be 0 while the cache is full and latency climbs. |
| Running plus waiting           | `vllm:num_requests_running` + waiting                           | Concurrency-based sizing.                                           |
| Work queue length              | `rabbitmq`, `redis`, `aws-sqs-queue`, `nats-jetstream`, `kafka` | Batch, async and worker pools that pull jobs.                       |
| Anything with a JSON endpoint  | `metrics-api`                                                   | A gateway or custom status route.                                   |
| GPU utilization                | Prometheus on DCGM metrics                                      | Weak signal; see below.                                             |

vLLM metric names are exposed with a `vllm:` prefix (`vllm:num_requests_waiting`, `vllm:num_requests_running`,
`vllm:kv_cache_usage_perc`). Check the live names first: `curl -s <pod>:8000/metrics | grep -E '^vllm:(num_requests|kv_cache)'`.
Other engines use their own names; the trigger shape is the same.

## Prometheus trigger

```yaml
triggers:
  - type: prometheus
    name: vllm-waiting
    metricType: AverageValue # default; threshold is per replica
    metadata:
      serverAddress: http://prometheus-operated.monitoring.svc:9090
      query: sum(vllm:num_requests_waiting{namespace="llm",model_name="qwen"})
      threshold: "4" # waiting requests tolerated per replica
      activationThreshold: "0" # active when the sum is above this
      ignoreNullValues: "false" # error instead of reading 0 when the series is missing
```

Rules of thumb:

- The query must return one element (vector with a single sample, or a scalar): wrap in `sum(...)`.
- Replicas requested = ceil(sum / threshold). A threshold of 4 means KEDA aims for at most 4 waiting per pod.
- Select the model and namespace by labels so other deployments' pods do not count. Confirm label names with a
  Prometheus query; they depend on your scrape config.
- Use more than one trigger: the HPA takes the largest desired replica count among triggers. A KV-cache guard such as
  `max(vllm:kv_cache_usage_perc{...})` with `metricType: Value` and `threshold: "0.85"` adds replicas when the cache
  nears full. With `Value` the HPA scales replicas by metric/threshold ratio, not per pod average.
- Start thresholds from a load test (concurrency at which p95 latency hits your target), not from guesses.
- Optional trigger fields: `useCachedMetrics: true` (reuses the value for `pollingInterval`), `unsafeSsl`, `timeout`,
  `customHeaders`, `namespace` (Thanos), `queryParameters`.

## GPU metrics (DCGM)

`DCGM_FI_DEV_GPU_UTIL` and `DCGM_FI_DEV_FB_USED` come from dcgm-exporter (skill `dcgm-exporter`; operator-managed in
`nvidia-gpu-operator`). LLM decode keeps utilization high at low load, so a utilization threshold scales late or never.
Use it as a secondary trigger or for idle detection:

```yaml
- type: prometheus
  name: gpu-idle-guard
  metadata:
    serverAddress: http://prometheus-operated.monitoring.svc:9090
    query: avg(DCGM_FI_DEV_GPU_UTIL{namespace="llm"})
    threshold: "85"
```

## Queue scalers (batch and async LLM workers)

Workers that pull from a queue scale on queue length; the model server pods behind them scale separately.

```yaml
- type: rabbitmq
  metadata:
    protocol: amqp
    queueName: llm-jobs
    mode: QueueLength
    value: "20" # messages per replica
    activationValue: "1"
  authenticationRef:
    name: rabbitmq-auth # TriggerAuthentication with a 'host' parameter (references/authentication.md)
```

Redis lists: `type: redis`, `listName`, `listLength`, `address` (`host:port`) with `passwordFromEnv` or a
TriggerAuthentication. SQS: `type: aws-sqs-queue`, `queueURL`, `queueLength`, `awsRegion`, with
`podIdentity.provider: aws`. NATS JetStream: `type: nats-jetstream`, `natsServerMonitoringEndpoint`, `stream`, `consumer`,
`lagThreshold`. Long jobs on pods: pair `terminationGracePeriodSeconds` with a preStop hook, or run each job as a
`ScaledJob` (`templates/scaledobject-queue-worker.yaml` notes both).

## metrics-api trigger

`type: metrics-api` with `url`, `valueLocation` (JSON path), `targetValue`, and an `authMode` for secured endpoints.
Use it when a gateway or router exposes JSON but not Prometheus metrics.

## Composing triggers

Several triggers on one ScaledObject: the HPA scales to the maximum desired count. To combine them into one number
(for example waiting + 2 × running), use `advanced.scalingModifiers` with `formula`, `target` and named triggers
(`references/scaledobject-tuning.md`).
