# Vast.ai billing, limits and security

> Verified against docs.vast.ai guides on billing and instance types, guides/instances/storage/volumes, guides/reference/faq/security, guides/serverless/pricing, cli/permissions, docs.vast.ai/llms.txt, vastai CLI 1.8.3, 2026-10-11

Do not hardcode prices: they are set per host and change constantly. Read them from `vastai search offers` at decision time.

## What costs money

| Resource           | When it bills                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| GPU time           | From the `running` state until stopped or destroyed                                              |
| Container storage  | From creation, continuing while the instance is **stopped**; deleted on destroy                  |
| Local volumes      | From creation until deleted (not billed while the host is offline)                               |
| Bandwidth          | Separate from `dph_total`; billed on download and upload volume, so check offer bandwidth prices |
| Serverless workers | GPU while Ready or Loading; storage only while cold (`serverless.md`)                            |

**Only destroying an instance (or destroying a Serverless endpoint) stops all billing.** A stopped instance keeps charging for storage and may lose its GPU to another renter.

## Instance types

| Type          | Behavior                                                                   | Use for                     |
| ------------- | -------------------------------------------------------------------------- | --------------------------- |
| On-demand     | Fixed price, runs until you stop it                                        | Default for serving and dev |
| Reserved      | Up to 50% discount for a committed term; on-demand can convert to reserved | Long, predictable use       |
| Interruptible | You bid; may be paused when outbid                                         | Restartable batch work only |

The type cannot be changed after rental except on-demand to reserved. Expired instances may be deleted 48 hours after expiry.

## Credits and balance

- Prepaid credits through Stripe or crypto. Autobilling is card-only. No refunds on spent credits.
- At $0 balance instances are stopped. Without a saved card they are destroyed, so keep a balance buffer or a card on file.
- There is no per-account spend cap in the CLI. Control spend by limiting `--max_workers` on Serverless, destroying instances on a schedule, and using scoped keys so a leak cannot start more.
- Watch spend with `vastai show instances` (each row has a total hourly cost), `vastai show user` (credit balance), the console billing page, and `vastai show invoices-v1` (see `--help`).

## Platform limits

| Item                         | Value                                                                                                                      |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Open ports per instance      | 64                                                                                                                         |
| `--onstart-cmd` length       | 16 KB                                                                                                                      |
| Container storage            | Fixed at creation, minimum 10 GB by default                                                                                |
| Volumes                      | Local to one machine; cannot be resized or moved; Docker instances only                                                    |
| CLI retries                  | `--retry` default 3, for `429` only                                                                                        |
| Serverless endpoint defaults | min workers 5 and max 16 in the console (CLI help says 5 and 20); target utilization 0.9; max queue 30 s                   |
| Docker-in-Docker             | Not supported                                                                                                              |
| API rate limits              | Documented per endpoint on the Vast API rate limits page; exact numbers not captured here, so rely on `429` plus `--retry` |

## Security notes

- Instances run in unprivileged Docker containers with separate namespaces, network and filesystem. **Hosts can still technically access files on their machines**, so avoid putting credentials, private datasets or unencrypted sensitive data on any instance.
- Provider quality varies: Secure Cloud providers are vetted datacenters (ISO 27001, Tier 3/4). Enable the Secure Cloud filter, or use `verified=true` as a minimum.
- Encrypt sensitive data before upload and use application-level encryption. Do not store credentials on instances; use short-lived, scoped keys.
- Use SSH keys only. Connections to the web API, SSH and Jupyter are encrypted; vLLM on a mapped direct port is not, so use an SSH tunnel, Tailscale or a tunnel service for anything sensitive.
- A leaked key: delete it in the console, create a new one, update consumers, check billing, and contact support if usage looks wrong.
- Use separate keys per application, and `misc`-only keys for clients that only call a Serverless proxy.

## Instance vs Serverless on cost

| Traffic                                        | Prefer                                                             |
| ---------------------------------------------- | ------------------------------------------------------------------ |
| Constant load, or interactive dev              | One on-demand instance (destroy after)                             |
| Spiky load, can tolerate minutes of cold start | Serverless with low `min_workers` and an inactivity timeout        |
| Restartable batch work                         | Interruptible instance                                             |
| Sensitive data or strict uptime                | Secure Cloud datacenter offers, or another provider (`cloud-llms`) |

Use the `choosing-llm-hosting` skill for the wider comparison.
