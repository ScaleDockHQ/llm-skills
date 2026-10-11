# Crusoe: limits, quotas and billing

> Verified against Crusoe Cloud docs (Managed Inference rate limits, quotas, billing behaviour), 2026-10-11

Prices change. Read them in the console or on https://crusoe.ai before quoting; this skill stores none.

## Managed Inference

- Rate limits are per project and per model, as TPM and RPM. Exceeding returns 429; 503 can mean overload. Read `x-ratelimit-*` headers and back off with jitter.
- Exact numbers: unverified here (secondary sources only). Check the Managed Inference limits page in the docs.
- Serverless bills per token. Self-serve deployments bill per GPU-hour from creation until deleted.

## Compute

- Quotas: console, Admin, Usage, Quotas; also available through the REST API quota endpoints. Check before creating GPU VMs or node pools.
- Stopped on-demand VMs do not bill and do not count toward quota.
- Persistent and shared disks bill when detached. Ephemeral disks are wiped on stop.
- CMK: node costs plus a cluster fee documented in the docs.

## Habits

1. Show type, count, location and billing rule before creating.
2. Delete idle deployments; replicas bill while the deployment exists.
3. List disks, IPs and clusters weekly while work is ongoing.
