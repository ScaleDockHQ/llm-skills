# Datadog Agent Observability: updating and troubleshooting

> Verified against Datadog Agent Observability docs, ddtrace 4.15.6 and dd-trace 6.20.1, 2026-10-11

## Updating

- **Pin the tracer:** exact `ddtrace==x.y.z` and `dd-trace` versions in lock files. Integrations need minimum tracer versions (for example vLLM needs ddtrace 4.2.0, LiteLLM 3.9.0, OpenAI 2.9.0; the docs table lists all). Trace sampling through `llmobs_sample_rate` needs ddtrace 4.12.0 or Node dd-trace 5.110.0.
- Read the tracer release notes (`DataDog/dd-trace-py`, `DataDog/dd-trace-js` on GitHub) before bumping, then send a canary span and check it appears with the expected `ml_app`.
- **Agent:** if you use the Datadog Agent, update it per Datadog's Agent docs, independently of the SDK.
- Docs and product names changed (LLM Observability to Agent Observability); re-check URLs at use time.

```bash
pip index versions ddtrace 2>/dev/null | head -1 || curl -fsS https://pypi.org/pypi/ddtrace/json | jq -r .info.version
```

## Troubleshooting

| Symptom                                   | Likely cause                                                                             | Fix                                                                                                        |
| ----------------------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Nothing in Agent Observability            | `DD_LLMOBS_ENABLED` unset, wrong `DD_SITE`, no Agent and not agentless                   | Set `DD_LLMOBS_ENABLED=1`; match site to your org; add `DD_LLMOBS_AGENTLESS_ENABLED=1` with `DD_API_KEY`   |
| Auth errors, 403                          | Wrong or revoked API key, key for another site                                           | Create a key on the right site, rotate, retry; never paste the key in chat                                 |
| No LLM spans, only HTTP                   | Integration not matched (version below minimum, framework not in the table)              | Check the supported table; update the tracer; add manual spans                                             |
| Process exits before spans appear         | Short-lived job did not flush                                                            | Call `LLMObs.flush()` (Node `llmobs.flush()`) before exit                                                  |
| OTel traces ignored                       | Missing `dd-otlp-source=llmobs`, gRPC exporter, `dd_llmobs_enabled` not set or set false | Add the header, use http/protobuf, set `OTEL_RESOURCE_ATTRIBUTES=dd_llmobs_enabled=true`                   |
| OTel mapping warnings                     | Library emits pre-1.37 attributes                                                        | `OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental`; compare raw attributes in the linked APM trace |
| Cost empty for a local model              | No public price                                                                          | Supply `input_cost` and `output_cost` in `metrics`                                                         |
| Cost totals disagree with yours           | Only partial cost supplied                                                               | Supply input, output and total consistently                                                                |
| Cost metric by team missing               | Tag not promoted, or high cardinality                                                    | Pass bounded keys in `cost_tags`                                                                           |
| Spans missing some requests               | Sampling                                                                                 | Check `DD_LLMOBS_SAMPLE_RATE`                                                                              |
| Prompts visible in APM too                | OTel data also written to APM                                                            | Apply a restricted dataset in APM                                                                          |
| Gateway spans are separate from app spans | No shared trace context                                                                  | Enable the SDK on both sides; wrap in `LLMObs.workflow`; keep headers propagating                          |

## Teardown

Remove `ddtrace-run` or the `LLMObs.enable` call, unset `DD_LLMOBS_*`, revoke the API key if it was created for this, and delete test `ml_app` data per your retention rules.
