# OpenLLMetry: updating

> Verified against OpenLLMetry traceloop-sdk 0.62.4 (PyPI, GitHub CHANGELOG and releases), 2026-10-11

## What to pin

`traceloop-sdk` is one package that depends on every instrumentation package (about 30 `opentelemetry-instrumentation-*` packages from the same repo) and on `opentelemetry-api` and the OTLP exporters (`>=1.38.0,<2`). Pin the SDK and let the resolver choose the instrumentations; lock the whole set:

```bash
pip index versions traceloop-sdk | head -2                  # newest versions, read-only
pip show traceloop-sdk | sed -n 1,3p                        # installed
pip install "traceloop-sdk==0.62.4"                         # pin, then commit the lock file
pip check
```

Requires Python 3.10 to 3.x (`<4`). JavaScript: `npm view @traceloop/node-server-sdk version` (0.27.0 at the stamp date).

## Upgrade routine

1. Read the CHANGELOG at https://github.com/traceloop/openllmetry/blob/main/CHANGELOG.md for the range. The project releases often, and instrumentation fixes ship as `fix(<provider>)` entries.
2. Upgrade in a staging service with the canary from `privacy.md` and one request per provider you use.
3. Compare span attributes before and after. The project is moving message attributes towards the OpenTelemetry GenAI conventions (`gen_ai.input.messages`, `gen_ai.output.messages`, in "development" status upstream), and redaction callbacks keyed on attribute names break when names change. See `opentelemetry-genai`.
4. Confirm the backend still renders the spans (Phoenix and MLflow translate attributes at ingest, Langfuse maps OTel attributes; mapper versions matter).
5. Roll out, keep the previous lock file for rollback.

## Things that changed recently and bite

- Telemetry: no package collects usage telemetry since v0.49.2.
- Content default is still on (`TRACELOOP_TRACE_CONTENT=true`): re-check new services.
- `use_attributes` controls attributes versus log events for messages; the default and the span shape differ across versions, so retest redaction.
- Dependency overlap: other OTel packages in the same environment must satisfy `opentelemetry-api>=1.38`; `pip check` flags conflicts.
- Instrumentation upper bounds: a new major of a provider SDK may be ahead of the instrumentation; when spans disappear after upgrading the provider SDK, pin the SDK back or upgrade `traceloop-sdk`.

## Rollback

Reinstall the previous lock file; no server state is involved because the library is stateless.
