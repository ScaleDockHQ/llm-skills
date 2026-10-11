# Runpod limits, billing and cost controls

> Verified against docs.runpod.io billing and spend-limit documentation, serverless/endpoints/endpoint-configurations, serverless/load-balancing/overview, runpodctl v2.15.0 (user, billing references), 2026-10-11

Do not hardcode prices; they change by GPU, cloud type and region. Read them in the console, `runpodctl gpu list` or the pricing page at the time of the decision.

## Billing model

- Prepaid credits, billed **per second**. Pods and Serverless workers draw from the same balance.
- Pods bill while running. A stopped Pod still bills for its volume disk. Network volumes and cached storage bill while they exist.
- Serverless bills for worker time (starting, running a job, idle timeout) and for active workers while they are on. Time spent downloading a cached model is not billed.
- At a $0 balance Runpod stops Pods, and terminates them if they have no network volume. Keep a buffer.
- A new Pod needs at least one hour of credit for its configuration.
- Savings plans are for GPU compute only and commit you to a term; do not buy one without explicit approval.

## Spend controls to set before traffic

1. **Spend limit**: the default is $80 per hour and grows over time. See it with `runpodctl user` (`spendLimit`). Ask support or the console to lower it if you want a harder ceiling.
2. **Low-balance alert and auto-pay**: configure in console **Billing**. Auto-pay can refill without asking; enable it only with consent.
3. **Serverless `max workers`**: the real cap for an endpoint. `max workers x GPU hourly rate x hours` is your worst-case spend.
4. **Active workers = 0** unless latency demands otherwise. Each active worker bills continuously.
5. **Idle timeout**: lower values save money but cause more cold starts. Default 5 s.
6. **Execution timeout**: default 600 s; set it below any runaway-generation risk and set `max_tokens` in clients.

## Watch cost

```bash
runpodctl user                                    # clientBalance, currentSpendPerHr, spendLimit
runpodctl billing pods                            # pod charges (see --help for bucket and date flags)
runpodctl billing serverless
runpodctl billing network-volume
runpodctl pod list                                # anything running right now
runpodctl serverless list
runpodctl network-volume list
```

`currentSpendPerHr` is the fastest idle check: after teardown it should be near zero (the docs example shows `0.001` with only small storage left).

## Platform limits

| Item                    | Value                                                                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Queue endpoint defaults | active 0, max workers 3, idle 5 s, execution timeout 600 s, job TTL 24 h, FlashBoot on                                                                                            |
| Auto scale-down         | `max workers` falls to 2 after 3 days of no requests and to 0 after 7 days                                                                                                        |
| Result retention        | `/run` 30 minutes, `/runsync` 1 minute                                                                                                                                            |
| Rate limits             | `/runsync` 2000 per 10 s and 400 concurrent; `/run` 1000 per 10 s and 200 concurrent; `/openai/*` 2000 per 10 s and 400 concurrent; `429` when exceeded; scales with worker count |
| Load-balancing endpoint | 2 min waiting for a worker, 5.5 min processing, 30 MB payload                                                                                                                     |
| Network volume size     | 1-4000 GB, grow only, one data center, Secure Cloud only                                                                                                                          |
| Cached models           | one per endpoint, under `/runpod-volume/huggingface-cache/hub/`                                                                                                                   |
| GPU availability        | `stockStatus` in `runpodctl gpu list`; large GPUs and multi-GPU counts can be out of stock, and Serverless may then have fewer workers than `max workers`                         |

Account-level worker quotas exist (new accounts start with a low total-worker limit that grows with spend). The exact numbers were not stated on the pages read; unverified, check the console under Serverless settings or ask support.

## Choosing Pod vs Serverless on cost

| Traffic                                         | Prefer                                  |
| ----------------------------------------------- | --------------------------------------- |
| Constant, many hours a day                      | Pod (or active workers)                 |
| Bursty, long idle gaps, tolerates cold starts   | Serverless with active workers 0        |
| Needs a single stable URL and instant responses | Pod, or Serverless with 1 active worker |
| One-off experiment                              | Pod, stopped or deleted right after     |

Use the `choosing-llm-hosting` skill for the wider comparison, including managed APIs.
