# Nebius: limits, quotas and billing

> Verified against Nebius docs (Compute quotas, capacity reservations, Token Factory rate limits and billing, quota-allowance CLI), 2026-10-11

Prices change. Read them from https://nebius.com/prices and the console before quoting; this skill does not store prices.

## Token Factory

- Rate limits are dynamic, per project. 429 is the signal. Read `x-ratelimit-*` response headers and back off.
- Billing is card-based with automatic top-up; new accounts get a small trial credit (amount: check the console). Running out of balance blocks requests.
- Dedicated endpoints: per GPU-hour while the minimum replicas are reserved. Idle replicas still bill.
- Batch: `completion_window` 24h. Batch pricing differs from real-time: check the pricing page.
- Fine-tuning jobs bill per the pricing page; ask before starting.

## Compute and mk8s

- Quotas: VM counts and per-GPU-model GPU totals, per region. VMs count toward quota even when stopped. `nebius quotas quota-allowance list --parent-id $PROJECT_ID`.
- Increase via your Nebius manager or support.
- Reservations (capacity block groups) keep GPUs yours when VMs stop; arranged through your manager.
- Unattached disks, filesystems and public IPs may bill: list and delete what you do not use (`teardown.md`).

## Cost control habits

1. Show platform, preset, count, region and billing rule before creating.
2. Prefer serverless Token Factory for spiky traffic; dedicated or VMs for steady load.
3. Delete idle VMs; do not rely on stop to free quota.
4. Review the console Billing page weekly while resources exist.
