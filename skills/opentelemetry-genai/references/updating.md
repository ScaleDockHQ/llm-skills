# Updating GenAI instrumentation and the Collector

> Verified against opentelemetry-python-genai 1.2b0 CHANGELOGs, semantic-conventions-genai main, OpenTelemetry Collector contrib 0.162.0, 2026-10-11

## What to pin

| Component                  | How to check the newest (read-only)                                                                                         |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Instrumentation packages   | `curl -fsS https://pypi.org/pypi/opentelemetry-instrumentation-genai-openai/json \| jq -r .info.version`                    |
| `opentelemetry-util-genai` | same, package name `opentelemetry-util-genai`                                                                               |
| OpenTelemetry API and SDK  | the instrumentations pin `opentelemetry-api~=1.43` and `opentelemetry-instrumentation>=0.64b0`; upgrade together            |
| Collector contrib          | `curl -fsS https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest \| jq -r .tag_name` |
| Conventions                | commit date of `semantic-conventions-genai` main; there are no tags yet                                                     |

Pin exact versions in the lock file and the container tag. Beta packages (`1.2b0`) can break on any release.

## Routine

1. Read the CHANGELOG of every package you use (`instrumentation/<pkg>/CHANGELOG.md` in `opentelemetry-python-genai`) for the range, and the semconv `changelog.d/` fragments for renames.
2. Upgrade in staging. Diff span attributes and metric names before and after (send one request, print with the `debug` exporter or the backend's JSON view).
3. Update redaction statements and dashboards for renamed attributes; run the canary (`content-and-privacy.md`).
4. Collector: bump the tag, run `validate`, replay a canary, then roll. Keep the previous image tag.
5. Roll back by restoring the previous lock file or image tag; nothing persistent is migrated.

## Renames to expect

- Legacy to current: `gen_ai.system` -> `gen_ai.provider.name`; `gen_ai.client.token.usage` -> `gen_ai.client.inference.usage.*`; chat `gen_ai.client.operation.duration` -> `gen_ai.client.inference.duration`; indexed `gen_ai.prompt.N.*` -> structured `gen_ai.input.messages`.
- Package moves: `opentelemetry-instrumentation-openai-v2` -> `opentelemetry-instrumentation-genai-openai` (import path `opentelemetry.instrumentation.genai.openai`); `OTEL_SEMCONV_STABILITY_OPT_IN` is gone from the new packages.
- Expect more: the status is Development; subscribe to the conventions repository releases or watch its `docs/registry`.
