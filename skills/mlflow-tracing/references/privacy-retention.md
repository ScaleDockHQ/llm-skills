# MLflow traces: content, masking, retention, archival, deletion

> Verified against MLflow 3.17.0 docs (genai/tracing/observe-with-traces: masking, archive-traces, delete-traces; self-hosting/architecture/tracking-server; community/usage-tracking), 2026-10-11

## Where content lives

Trace spans (inputs, outputs, attributes) are stored in the SQL backend store; large or multimodal payloads can go to the artifact store. Everyone with access to the server (or database) can read them, and with auth off that is anyone who reaches the port. Decide before real traffic.

## Content switches

- **MLflow SDK:** no "off" switch per se; autolog records inputs and outputs. Reduce with client-side span processors (below), by not autologging sensitive flavors, or sampling (`MLFLOW_TRACE_SAMPLING_RATIO`).
- **OpenTelemetry clients:** content capture is the instrumentation's setting (`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` unset means none for the official packages; see `opentelemetry-genai`). A Collector in front can strip attributes before MLflow.
- **Gateways:** LiteLLM `turn_off_message_logging`; verify with the canary.

## Masking (client side, MLflow SDK)

```python
import re, mlflow
from mlflow.entities.span import Span

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")

def redact(span: Span) -> None:
    text = span.inputs.get("text") if isinstance(span.inputs, dict) else None
    if isinstance(text, str):
        span.set_inputs({"text": EMAIL.sub("[REDACTED]", text)})

mlflow.tracing.configure(span_processors=[redact])
```

Processors run on each span before it leaves the app, so sensitive data never reaches the server. They apply to spans created by the MLflow SDK; spans arriving over raw OTLP are not processed by them, so strip those in the instrumentation or a Collector. Input and output shapes differ per integration (chat messages vs plain strings); inspect real spans and branch on `span.span_type`.

## Retention: archive versus delete

| Mechanism                                                   | What it does                                                                                                                                                                                                                | Reversible |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| **Archival** (`--trace-archival-config`, present in 3.17.0) | Moves span payloads older than a retention period from the SQL store to an artifact location; traces stay readable in UI and API, but searches on `trace.text` and `span.content` stop working and spans cannot be appended | No         |
| **Deletion**                                                | `MlflowClient.delete_traces(experiment_id, max_timestamp_millis=... or trace_ids=[...])` or the UI                                                                                                                          | No         |

Archival configuration (server YAML, picked up without restart within about 5 seconds):

```yaml
# /etc/mlflow/trace-archival.yaml
trace_archival:
  enabled: true
  location: s3://mlflow-trace-archive # a real artifact repository URI
  retention: 30d
  interval_seconds: 300
  max_traces_per_pass: 1000
  long_retention_allowlist: [] # experiment IDs allowed to keep traces longer than the server or workspace policy
```

```bash
export MLFLOW_TRACE_ARCHIVAL_CONFIG=/etc/mlflow/trace-archival.yaml     # or: mlflow server --trace-archival-config /etc/mlflow/trace-archival.yaml
mlflow experiments update --experiment-id 123 --trace-archival-retention 7d     # per-experiment, shorter only unless allowlisted
```

Policy resolves server, then workspace, then experiment; shorter experiment retention always wins. The scheduler skips in-progress traces. Archival reduces database size; it does not remove data. To remove, delete:

```python
from datetime import datetime, timedelta
from mlflow import MlflowClient
cutoff = int((datetime.now() - timedelta(days=30)).timestamp() * 1000)
print(MlflowClient("http://mlflow:5000").delete_traces(experiment_id="1", max_timestamp_millis=cutoff))   # irreversible: ask first, back up the database
```

Schedule that as a cron job or Kubernetes CronJob if your policy is deletion. `delete_traces` does not support traces stored in Databricks Unity Catalog. After large deletes PostgreSQL may need autovacuum or `VACUUM (ANALYZE)`.

## Telemetry

MLflow's own usage telemetry is separate from trace content and is on by default; set `MLFLOW_DISABLE_TELEMETRY=true` or `DO_NOT_TRACK=true` (see `configuration.md`).

## Decision record

- Environment, content policy, who can read the server, auth mode, retention (archive after, delete after), backup schedule, telemetry setting, review date.

## Canary test

- [ ] Send `PRIVACY-CANARY-<date>` and a fake email through each path (SDK, OTLP, gateway).
- [ ] Search the UI and the database (`SELECT count(*) FROM spans WHERE content ILIKE '%PRIVACY-CANARY%'`, adjusting for the schema in your version) for the marker.
- [ ] With content off or masked it must be absent; run again after upgrades.
