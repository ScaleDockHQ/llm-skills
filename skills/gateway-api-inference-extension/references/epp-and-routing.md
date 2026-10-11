# EPP and routing (llm-d router)

> Verified against llm-d router v0.11.0 (README, `docs/architecture.md`, `docs/operations.md`, chart README, release notes) and Gateway API Inference Extension v1.6.2, 2026-10-11

## What the EPP does

For each request the EPP (an Envoy ext-proc service) runs: request control (flow-control admission, candidate lookup,
screeners, data producers, admission plugins), then one or more **scheduling profiles**: filters -> weighted scorers ->
picker. The highest score wins, ties are broken at random. Data comes from a pluggable data layer that scrapes the
model servers' `/metrics`.

## Plugin configuration

The EPP reads `EndpointPickerConfig` (`apiVersion: llm-d.ai/v1alpha1`) from `--config-file` or `--config-text`; the chart
exposes it as `router.epp.pluginsConfig`/`pluginsConfigFile` (default `default-plugins.yaml`). Example from upstream:

```yaml
apiVersion: llm-d.ai/v1alpha1
kind: EndpointPickerConfig
plugins:
  - type: precise-prefix-cache-producer
    parameters: { tokenProcessorConfig: { blockSizeTokens: 5 } }
  - type: prefix-cache-scorer
    parameters: { prefixMatchInfoProducerName: precise-prefix-cache-producer }
  - type: decode-filter
  - type: max-score-picker
  - type: single-profile-handler
schedulingProfiles:
  - name: default
    plugins:
      - pluginRef: decode-filter
      - pluginRef: max-score-picker
      - pluginRef: prefix-cache-scorer
        weight: 50
```

One profile for plain serving; two (prefill and decode) for disaggregation. Feature gates: `--feature-gates name=bool,...`
or `featureGates` in the config file (for example `haPopulateNonLeaderDatastore`, on by default). The full plugin list is
in the repo at `pkg/epp/framework/plugins/README.md`: read it for your version rather than copying plugin names from old
posts (names changed across releases; for example the dayaLayer gate was removed in 0.8.0 and the flow-control queue
`MaxMinHeap` became `PriorityQueue`).

Parsers: `router.epp.parsers` (for example `openai-parser`, `anthropic-parser`), empty for auto-selection. The OpenAI
parser also claims `/v1/images/generations` in recent releases.

## Priorities, rewrites and flow control

- `InferenceObjective`: per-request priority and performance goals (chart value `router.inferenceObjectives`).
- `InferenceModelRewrite`: rewrite model names for A/B tests and canary splits.
- Flow control queues requests under saturation. Since the 2026-07 release notes: queueing is bounded by default
  (`defaultRequestTTL` 60s, per-band `maxRequests` 5000); an explicit `defaultRequestTTL: "0s"` disables the TTL;
  rejections at capacity with an empty pool return 503 with header `x-llm-d-request-dropped-reason: rejected-no-endpoints`.
  Scale-to-zero pools must raise `defaultRequestTTL` above cold-start time (and size `noEndpointRequestTTL`).
- Set a global `flowControl.maxBytes` below the container memory limit: buffered request bodies live in EPP memory.

## High availability

`router.epp.replicas > 1` defaults to active-passive leader election (`--ha-enable-leader-election`): only the leader
serves ext-proc and is Ready; standbys answer NOT_SERVING on purpose. `helm --wait` then fails with the default `Recreate`
strategy (Helm 3: set `deploymentStrategy.type: RollingUpdate` with `maxUnavailable >= replicas-1` and `maxSurge: 0`;
Helm 4/kstatus: install without `--wait`). Active-active (`ha-enable-leader-election: false`) scales throughput
(about 2.0x with 2 replicas, 2.7x with 3, 3.5x with 4 per upstream benchmarks) but needs plugins that read live backend
state and should be avoided with approximate prefix routing, because replicas do not share prefix state; flow-control
state is per replica. `--drain-timeout` (default 30s) governs graceful EPP shutdown.

## Disaggregated prefill/decode

The router can schedule P/D (and E/P/D) with the `llm-d-router-disagg-sidecar` next to the decode worker (`--kv-connector`
values include the offloading connector; flags `--connector` and the `--prefiller-use-tls` family were removed in 0.10).
Technique-level guidance: skill `disaggregated-serving`; full stack: skill `llm-d-vllm-kubernetes`.

## Sizing (upstream operations guide)

- CPU: roughly 0.5 to 1.0 core per request/second for large agentic workloads (about 100k input and 1k output tokens);
  a large `maxPrefixTokensToMatch` raises CPU; idle CPU grows with the number of model pods scraped.
- Memory: 4 to 6 GiB at 50 to 100 req/s with 1k output tokens; 20+ GiB with 5k output tokens (state for in-flight requests).
- Chart defaults request 8 CPU and 8Gi with a 16Gi memory limit: lower them only after measuring.
- Active-passive replicas do not add throughput.

## Sources

https://github.com/llm-d/llm-d-router/blob/main/docs/architecture.md, https://github.com/llm-d/llm-d-router/blob/main/docs/operations.md
