# Together AI dedicated model inference

> Verified against Together docs: Dedicated endpoints Quickstart, Manage endpoints and deployments, Configure autoscaling, Send requests, Pricing, Migrate from v1; `tg` CLI 2.24.0+, 2026-10-11

## Resource model

- **Endpoint**: a stable inference name. String form `<project_slug>/<endpoint_name>`. It carries no model or hardware.
- **Deployment**: binds a model and a **config** (hardware, quantization, speculative decoding) to an endpoint with autoscaling bounds. Deployments run replicas.
- **Traffic split**: weights across an endpoint's deployments. A `READY` deployment receives nothing until it has a non-zero weight (`endpoint_not_configured`, HTTP 400, otherwise).
- Billing is per minute per **ready** replica, by hardware, not per token. Provisioning and cold-start time are not billed; a stopped or zero-replica deployment costs nothing. Rates are on https://docs.together.ai/docs/dedicated-endpoints/pricing and https://www.together.ai/pricing. Some hardware is contact-sales only.
- v1 dedicated endpoints are legacy. See the migration section.

## Deploy (needs user approval first)

```bash
# find a supported model and its deployment profiles (configs)
tg beta models configs <model_id>

# create endpoint + deployment + 100% traffic in one step
tg beta endpoints deploy <model> \
  --endpoint my-endpoint \
  --min-replicas 1 --max-replicas 1 \
  --inactive-timeout 60
```

- Add `--config <cr_...>` when the model has several profiles; without it the CLI errors and lists them. A single profile is chosen automatically.
- `--min-replicas 0` alone creates the deployment stopped. A running deployment needs min at least 1.
- Placement: `--placement <pp_...>` (profile) or `--placement.regions a,b` with `--placement.constraint required|preferred`. `--placement.hipaa` restricts to HIPAA-attested clusters and is always strict. Placement cannot change after creation.
- First provisioning of a small model typically takes 5 to 10 minutes; larger models take longer. A deployment that is not `READY` within six hours becomes `FAILED`.

Poll:

```bash
tg beta endpoints get my-endpoint          # state and ready/desired replicas, newest 10 deployments
tg beta endpoints get dep_abc123 --json | jq '.status'
```

States: `PROVISIONING`, `SCALING`, `READY`, `DEGRADED` (transient, read `status.message`), `STOPPING`, `STOPPED` (not billing), `FAILED` (terminal; create a new deployment).

## Send requests

Inference goes to a different host than the management API. No CLI exists for inference.

```bash
curl -s https://api-inference.together.ai/v1/chat/completions \
  -H "Authorization: Bearer $TOGETHER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"your-project-slug/my-endpoint","messages":[{"role":"user","content":"Hi"}],"max_tokens":64}'
```

```python
from together import Together
client = Together(base_url="https://api-inference.together.ai/v1")  # reads TOGETHER_API_KEY
```

Function calling, structured outputs and streaming work as on serverless when the underlying model supports them. That base URL serves inference only, not the files or fine-tuning APIs, so use a separate client for those.

## Scale and autoscale

```bash
tg beta endpoints update dep_abc123 --min-replicas 1 --max-replicas 4 \
  --scaling-metric inflight_requests --scaling-target 8
```

- `min == max` fixes the size and disables autoscaling. Both `0` stops the deployment. `min 0` with a positive `max` is rejected.
- Metrics: `inflight_requests` (default, target 8), `active_sessions`, `gpu_utilization`, `token_utilization`, `cache_hit_rate`, `throughput_per_replica`, `ttft`, `decoding_speed`, `e2e_latency`. Percentile via `--scaling-percentile p50|p90|p95|p99` for the latency metrics (default p95).
- `throughput_per_replica`, `ttft` and `decoding_speed` are recorded only for streaming requests. Send `"stream": true` when scaling on them.
- Defaults: scale-up has no stabilization delay, scale-down waits five minutes (`--scale-up-window`, `--scale-down-window`). Evaluation runs about every 60 seconds.
- Cold start: new replicas take time to become ready, so keep `--min-replicas` high enough for your latency target.

## Idle shutdown (cost guard)

`--inactive-timeout <minutes>` (30 to 1440) stops the deployment when no inference request arrives for that long: bounds drop to 0, hardware is released, billing stops. It is off unless set. `0` disables. The clock starts when the deployment first becomes ready. A stopped deployment does not restart by itself; raise both bounds to 1 or more. Deployments with a timeout cannot join a rollout until it is set to 0.

## Stop, restart

```bash
tg beta endpoints update dep_abc123 --min-replicas 0 --max-replicas 0   # both must be 0
tg beta endpoints update dep_abc123 --min-replicas 1 --max-replicas 2   # restart (STOPPED only)
```

## Traffic features

Weights, rollouts, A/B tests and shadow experiments are covered at https://docs.together.ai/docs/dedicated-endpoints/route-traffic. A rollout or experiment membership blocks stop and delete in the console until completed or cancelled.

## Custom and fine-tuned models

Uploads must be fine-tuned variants of a base model Together already serves. LoRA adapter deployment was not available at the v2 launch; check https://docs.together.ai/docs/dedicated-endpoints/adapter. A completed Together fine-tune is already a private model in your project; see `batch-and-finetuning.md`.

## Migrating from v1

Creating or restarting v1 endpoints is disabled (`endpoints_v1_create_access_disabled`, HTTP 403). Running v1 endpoints keep serving until further notice. To migrate:

1. `tg beta models configs <model_id>` to pick a config.
2. `tg beta endpoints deploy <model_id> --endpoint <name> --config <cr_...> --min-replicas N --max-replicas M`.
3. Change your app's `model` to the new endpoint string, test, then retire v1 with `tg endpoints stop <id>` (the old v1 CLI).

Both endpoints bill during cutover; retire v1 promptly. Use `together>=2.24.0`.

## Sources

- https://docs.together.ai/docs/dedicated-endpoints/quickstart
- https://docs.together.ai/docs/dedicated-endpoints/manage
- https://docs.together.ai/docs/dedicated-endpoints/scaling
- https://docs.together.ai/docs/dedicated-endpoints/requests
- https://docs.together.ai/docs/dedicated-endpoints/pricing
- https://docs.together.ai/docs/dedicated-endpoints/migrate-from-v1
