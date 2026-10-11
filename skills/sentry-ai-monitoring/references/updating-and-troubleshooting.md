# Sentry AI monitoring: updating and troubleshooting

> Verified against Sentry docs (Agents, Python and OpenAI integration pages, Self-Hosted), sentry-sdk 2.71.0 and @sentry/node 11.6.0, 2026-10-11

## Updating

- **SDKs:** pin exact versions (`sentry-sdk==2.71.0`). Agent features move quickly: the Agents dashboards want Python SDK 2.41.0 or newer, and standalone gen_ai spans (needed for Conversations) arrived in 2.64.0. Read the release notes in the SDK repository (`getsentry/sentry-python`, `getsentry/sentry-javascript`) before bumping, then send a canary agent run.
- **Integrations:** the LiteLLM integration needs litellm 1.77.5 or newer; the OpenAI integration needs openai 1.0 or newer.
- **Self-hosted Sentry:** check out the latest release tag of `getsentry/self-hosted`, run `./install.sh`, then `docker compose up --wait`. Back up first, and read the Releases and Upgrading page; the docs recommend upgrading regularly. Set `SENTRY_BEACON = False` if you do not want the beacon.
- **SaaS:** nothing to update; the docs pages move (Insights AI became Agents).

```bash
curl -fsS https://pypi.org/pypi/sentry-sdk/json | jq -r .info.version
```

## Troubleshooting

| Symptom                                    | Likely cause                                                             | Fix                                                                                                          |
| ------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Nothing under Explore, Agents              | No `invoke_agent` span, tracing off, DSN wrong                           | Enable tracing; check Explore, Traces, AI Spans first; add an `invoke_agent` span or a framework integration |
| Spans present, no prompts or responses     | PII off or `include_prompts=False`                                       | Decide on content; set `send_default_pii=True` and leave `include_prompts` true only if approved             |
| Agents unnamed, cannot filter              | No `gen_ai.agent.name`                                                   | Name agents through the framework `name` argument or the span attribute                                      |
| Conversations empty                        | No conversation id, SDK too old, standalone spans not ingested           | `set_conversation_id()`; update SDK; on self-hosted check `stream_gen_ai_spans`                              |
| Cost is zero                               | Model name unknown to pricing sources (local models), or no token counts | Report tokens; send `gen_ai.cost.total_tokens`                                                               |
| Negative or odd cost                       | Token attributes set wrongly                                             | Input and output are totals; cached, cache-write and reasoning are subsets                                   |
| Missing agent runs                         | Head-based sampling dropped the root span                                | Use a `traces_sampler` that keeps `gen_ai.operation.name` roots and AI routes at 100 percent                 |
| OTLP traces rejected or empty              | Wrong endpoint or key, span events used for content                      | Copy both from Client Keys; put content in attributes                                                        |
| Streamed OpenAI calls have no token counts | `tiktoken` missing                                                       | Install it and set `tiktoken_encoding_name`                                                                  |
| LiteLLM proxy shows only errors            | The `sentry` callback sends exceptions, not traces                       | Use the SDK integration in-process or OTel; see `references/otlp-and-gateways.md`                            |
| Secrets or prompts in events               | Content attributes not scrubbed by default                               | Advanced Data Scrubbing rules on the `gen_ai.*` span attributes; `include_prompts=False`                     |

## Teardown

Remove the integration and `sentry_sdk.init` options, unset `SENTRY_*` variables, delete or rotate the client key if it was created for this, and stop the self-hosted stack only after exporting what you need.
