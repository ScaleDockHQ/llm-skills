# GenAI semantic conventions: status and opt-in

> Verified against open-telemetry/semantic-conventions-genai (main, 2026-10-09), opentelemetry-python-genai 1.2b0, opentelemetry-util-genai 1.2b0 and core semantic-conventions v1.44.0, 2026-10-11

## Status

- Every GenAI signal document says **Status: Development** (the lowest tier of the OpenTelemetry document status). Names, attributes and metrics can change or be removed in any release. Only a few shared attributes, such as `error.type`, are Stable because they come from the core conventions.
- The conventions **moved out of** `open-telemetry/semantic-conventions`: its `docs/gen-ai/README.md` is now a "Moved" notice pointing to `open-telemetry/semantic-conventions-genai`. That repository has no tagged releases and its README lists the schema URL as "TODO"; tooling pins a commit SHA (the Python repo's `versions.env` does the same). Treat "which version of the conventions" as "which commit, and which instrumentation release".
- Contents of the repository: client inference, embeddings, retrieval, memory, agent and workflow spans, tool execution, inference and token metrics, server metrics, events, exceptions, and technology pages for OpenAI, Anthropic, Azure AI Inference, AWS Bedrock and MCP.

## Where the code lives

| Repository                                        | What                                                                |
| ------------------------------------------------- | ------------------------------------------------------------------- |
| `open-telemetry/semantic-conventions-genai`       | The conventions (YAML model, generated docs, reference conformance) |
| `open-telemetry/opentelemetry-python-genai`       | Official Python instrumentations plus `opentelemetry-util-genai`    |
| `open-telemetry/opentelemetry-python-contrib`     | Older home of `opentelemetry-instrumentation-openai-v2` and others  |
| `open-telemetry/opentelemetry-collector-releases` | Collector distributions (core and contrib)                          |

Check what is current at use time:

```bash
curl -fsS https://api.github.com/repos/open-telemetry/semantic-conventions-genai/commits?per_page=1 | jq -r '.[0].commit.committer.date'
curl -fsS https://pypi.org/pypi/opentelemetry-util-genai/json | jq -r .info.version
```

## Opt-in variables

| Variable                                                                                  | Meaning                                                                                                                                                                                                      | Default      |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------ |
| `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`                                      | `NO_CONTENT`, `SPAN_ONLY`, `EVENT_ONLY`, `SPAN_AND_EVENT` (case-insensitive); invalid values warn and mean `NO_CONTENT`                                                                                      | unset = none |
| `OTEL_INSTRUMENTATION_GENAI_EMIT_EVENT`                                                   | `true` or `false` forces `gen_ai.client.inference.operation.details` log events on or off; when unset (the source docstring says `false`), the code emits them exactly when the capture mode includes events | by mode      |
| `OTEL_INSTRUMENTATION_GENAI_COMPLETION_HOOK`                                              | `upload` stores prompts and responses through an fsspec destination instead of or besides inline                                                                                                             | unset        |
| `OTEL_INSTRUMENTATION_GENAI_UPLOAD_BASE_PATH`, `_UPLOAD_FORMAT`, `_UPLOAD_MAX_QUEUE_SIZE` | Settings for the upload hook                                                                                                                                                                                 | see package  |
| `OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental`                                | **Legacy.** Needed by the old `opentelemetry-instrumentation-openai-v2` to switch to the newer names. The new packages removed all code behind this flag: the latest names are the only behavior             | n/a          |

Some pages in the conventions' own docs mention the content variable only as "for example"; the authoritative list of variables is each instrumentation package's README and `opentelemetry-util-genai` environment variables. Older LiteLLM and other integrations also accept `true`/`false` style values; check their docs.

## Content attributes are Opt-In

`gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`, `gen_ai.tool.definitions`, `gen_ai.tool.call.arguments` and `gen_ai.tool.call.result` have requirement level **Opt-In**: instrumentations must not record them unless the user opts in. Everything else (model, token usage, durations, errors, operation name) is on by default.

## What changed in recent cycles

- Inference spans are `gen_ai.client.inference` and their metrics are `gen_ai.client.inference.duration` and `gen_ai.client.inference.usage.*` (input, output, cache read and write, reasoning, per-modality). `gen_ai.client.operation.duration` remains for non-inference operations and "SHOULD NOT be reported for inference operations".
- Older docs and many blog posts use `gen_ai.client.token.usage`, `gen_ai.client.operation.duration`, `gen_ai.system`, `gen_ai.prompt.N.content`; those are legacy and appear in older instrumentation (including OpenLLMetry versions before the switch).
- Provider is `gen_ai.provider.name` (replaced `gen_ai.system`).
- New agent, workflow, tool, retrieval, memory and plan span types and `gen_ai.evaluation.result` events.

Always re-read `references/attributes-and-signals.md` against the commit you target.
