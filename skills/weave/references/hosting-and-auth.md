# Weave: hosting options and authentication

> Verified against weave 0.53.12 (PyPI), W&B docs on docs.coreweave.com (self-managed Weave, hosting overview, OTel guide), 2026-10-11

Weave's SDK is Apache-2.0 on GitHub; the trace backend is part of the W&B platform. W&B documentation now lives on docs.coreweave.com.

| Option             | Data location              | Endpoint                                                                  | Notes                                   |
| ------------------ | -------------------------- | ------------------------------------------------------------------------- | --------------------------------------- |
| Multi-tenant Cloud | W&B-hosted                 | `https://trace.wandb.ai` (OTLP: `/otel/v1/traces`)                        | Fastest start; data leaves your network |
| Dedicated Cloud    | W&B-managed, single tenant | `https://<subdomain>.wandb.io/traces/otel/v1/traces`                      | Managed by W&B                          |
| Self-Managed       | Your Kubernetes            | `https://<subdomain>.wandb.io/traces/otel/v1/traces` style on your domain | You operate it                          |

There is no standalone single-container Weave server in the docs. Self-managed Weave runs inside W&B Self-Managed (installed by the W&B Kubernetes Operator) and needs a Weave-enabled license from W&B, a Kubernetes cluster (1.29+), the Altinity ClickHouse Operator with ClickHouse Keeper and a ClickHouse cluster, S3-compatible storage, and a multi-node cluster (three nodes recommended). Port requirements between namespaces and ClickHouse nodes are in the upstream guide. Treat its configs as templates and size with W&B, not from the prerequisites list. If you want a simple self-hosted tracing server, evaluate `langfuse` instead.

## Authentication

```bash
pip install 'weave==<pinned>'
wandb login                                  # interactive; stores the key in ~/.netrc
# or non-interactive, from a 0600 file, never echoed:
export WANDB_API_KEY="$(cat ~/.config/wandb/api-key)"
export WANDB_BASE_URL=https://<subdomain>.wandb.io     # Dedicated or Self-Managed only
```

Use a service account key for CI and shared hosts. Check presence by name only (`env | cut -d= -f1 | grep WANDB`).

## Project naming

`weave.init("<entity>/<project>")`; a missing project is created; no entity means the default entity. Plan entities and projects per environment (dev, staging, prod) so content and retention can differ.

## Undo

Remove the `weave.init` call or set `WEAVE_DISABLED=true`; delete projects and data in the W&B UI (deletion is the platform's, not the SDK's). Retention and deletion controls for traces are not verified here; ask the platform admin.

## Official links

- Self-managed Weave: https://docs.coreweave.com/products/wandb/weave/guides/platform/weave-self-managed
- W&B Self-Managed overview: https://docs.coreweave.com/products/wandb/platform/hosting/self-managed
- Repository: https://github.com/wandb/weave
