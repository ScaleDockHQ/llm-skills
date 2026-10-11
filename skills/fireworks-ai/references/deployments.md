# Fireworks AI on-demand deployments

> Verified against Fireworks docs: Deployments Quickstart, Deployments guide, Autoscaling, Reserved capacity, Deploying Trained Models (LoRA), firectl deployment and model command pages; firectl 1.8.8+ (shapes), 1.7.26+ (`--preemptible`), 2026-10-11

On-demand deployments are dedicated GPUs: no serverless rate limits, a wider model choice, and billing by GPU-second (https://fireworks.ai/pricing). They can run on every model the Model Library marks as deployable, plus your own fine-tuned or uploaded models.

## Create (needs user approval first)

```bash
firectl deployment create accounts/fireworks/models/<MODEL_NAME> \
  --deployment-shape default \
  --min-replica-count 0 --max-replica-count 1 \
  --scale-up-window 30s --scale-down-window 5m --scale-to-zero-window 5m \
  --wait
```

- **Always pass `--deployment-shape`.** A shape is a Fireworks-validated template (hardware and defaults). `default` lets Fireworks pick a validated shape. To optimize cost or throughput, run `firectl deployment-shape-version match --model <model-id>` and pass the full resource name of a `THROUGHPUT` or `MINIMAL` shape (preset types are not aliases). Without a shape, creation is more likely to fail; `--accept-shapeless-risk` is for advanced users only. On `firectl` older than 1.8.8, `default` is treated as a literal name and fails.
- The output prints `Name: accounts/<ACCOUNT>/deployments/<DEPLOYMENT_ID>`. Find it later with `firectl deployment list` or `firectl deployment get <DEPLOYMENT_ID>`.
- Placement defaults to multi-region (GLOBAL, US, CANADA, EUROPE, APAC groupings). See https://docs.fireworks.ai/deployments/regions to restrict regions. To move a deployment, create the replacement, verify it, repoint your app, delete the old one.
- Quota: GPU quota is per placement and per GPU type; check `firectl quota list`.
- `--preemptible` borrows idle reserved GPUs for eval and batch work. It is immutable, may be reclaimed, and is silently ignored on `firectl` older than 1.7.26. Delete the deployment when the eval finishes.

States from the API: `CREATING`, `READY`, `UPDATING`, `DELETING`, `DELETED` (soft-deleted), `FAILED` (read the status).

## Query

```python
from fireworks import Fireworks
client = Fireworks()   # reads FIREWORKS_API_KEY
resp = client.chat.completions.create(
    model="accounts/fireworks/models/gpt-oss-120b#accounts/<ACCOUNT>/deployments/<DEPLOYMENT_ID>",
    messages=[{"role": "user", "content": "Hello"}],
)
```

With the OpenAI SDK or curl, base URL `https://api.fireworks.ai/inference/v1`, and the deployment-qualified model string. The docs show the Fireworks SDK form `<base model>#<deployment name>` and, for OpenAI SDK and curl examples, the bare deployment name; if one form fails, try the other and check https://docs.fireworks.ai/guides/ondemand-deployments.

## Autoscaling and cost guards

| Flag                     | Default (autoscaling doc) | Purpose                                                                    |
| ------------------------ | ------------------------- | -------------------------------------------------------------------------- |
| `--min-replica-count`    | 0                         | 0 enables scale-to-zero                                                    |
| `--max-replica-count`    |                           | Ceiling on cost                                                            |
| `--scale-up-window`      | 30s                       | Wait before scaling up                                                     |
| `--scale-down-window`    | 10m                       | Wait before scaling down                                                   |
| `--scale-to-zero-window` | 1h (min 5m)               | Idle time before zero replicas                                             |
| `--load-targets`         | `default=0.8`             | Thresholds, for example `requests_per_second=5` or `concurrent_requests=5` |

```bash
firectl deployment create accounts/fireworks/models/<MODEL> --deployment-shape default \
  --min-replica-count 0 --max-replica-count 4 --load-targets concurrent_requests=5 --wait
firectl deployment scale <DEPLOYMENT_ID> --replica-count 0     # immediate manual scale
```

- By default deployments scale to zero after 1 hour unused. Deployments with min replicas 0 are automatically deleted after 7 days without traffic. Do not rely on that for cost control.
- Scaling from zero: requests return `503` immediately while a replica starts. Add retry with backoff; see https://docs.fireworks.ai/deployments/autoscaling#scaling-from-zero-behavior.
- A 429 on a deployment usually means saturation, not a TPM cap.
- Use deployment tags to label environment, team or workload: https://docs.fireworks.ai/deployments/deployment-tags.

## Multiple GPUs, speculative decoding, metrics

Multi-GPU per replica comes from a matched shape (`firectl deployment-shape-version match`). Speculative decoding: https://docs.fireworks.ai/deployments/speculative-decoding. Metrics export: https://docs.fireworks.ai/deployments/exporting-metrics. Benchmarking: https://docs.fireworks.ai/deployments/benchmarking.

## Hosting LoRA and fine-tuned models

- A fine-tuned model deploys like any model: `firectl deployment create accounts/<ACCOUNT>/models/<FINE_TUNED_MODEL_ID> --deployment-shape default`.
- Multi-LoRA: deploy the base with addons enabled on a BF16 shape, then `firectl load-lora <FINE_TUNED_MODEL_ID> --deployment <DEPLOYMENT_ID>` (documented as `firectl model load-lora`). Unload with `firectl model unload-lora <id> --deployment <DEPLOYMENT_ID>`. Default on-demand LoRA quota is listed in `firectl quota list`.
- Live merge is recommended for a single adapter. See https://docs.fireworks.ai/fine-tuning/deploying-loras.
- Download weights: `firectl model download <MODEL_ID> /path/`.

## Reserved capacity

Enterprise accounts can buy reservations (typically one year): guaranteed capacity, higher quotas, lower GPU-hour prices. A reservation bills until it ends whether or not it is used; deployments meeting its parameters consume it. Turn down matching deployments or renew near the end, or usage bills at on-demand rates. See https://docs.fireworks.ai/deployments/reservations.

## Sources

- https://docs.fireworks.ai/getting-started/ondemand-quickstart
- https://docs.fireworks.ai/guides/ondemand-deployments
- https://docs.fireworks.ai/deployments/autoscaling
- https://docs.fireworks.ai/deployments/reservations
- https://docs.fireworks.ai/fine-tuning/deploying-loras
