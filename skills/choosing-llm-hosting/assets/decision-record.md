# LLM hosting decision record: <workload or platform name>

- **Status:** proposed | accepted | superseded by <link>
- **Date decided:** YYYY-MM-DD
- **Decided by:** <names / roles>
- **Next review:** YYYY-MM-DD (or trigger: volume ×2, new model release, policy change)

## Context

<One paragraph: what the workload is, who uses it, why a decision is needed now.>

## What already exists (from discovery)

- Hardware: <e.g. laptop with N GB unified memory; node-a with GPU X; none>
- Cloud accounts: <provider / account or project placeholder / region, or none>
- Gateway: <existing endpoint such as https://llm.example.com/v1, or none>
- Provider keys present (names only): <OPENAI_API_KEY, ...>

## Requirements (intake)

| Requirement                   | Value                                                                       |
| ----------------------------- | --------------------------------------------------------------------------- |
| Data classification           | public / internal / confidential / regulated / secret                       |
| Applicable contracts and laws | <NDA, DPA, BAA, GDPR, sector rules>                                         |
| Residency                     | <region or geography, or none>                                              |
| Quality bar                   | <tasks + pass criteria + eval set size>                                     |
| Latency                       | interactive / streaming / batch; target TTFT if interactive                 |
| Volume                        | <tokens/day now, in 12 months; peak vs average>                             |
| Utilization estimate          | <busy hours per day>                                                        |
| Budget                        | <monthly opex ceiling; capex allowed?>                                      |
| Ops capacity                  | <who owns it, on-call?>                                                     |
| Required capabilities         | tools / vision / long context / reasoning / structured output / fine-tuning |

## Options considered

| Tier                     | Candidate(s) | Passes data floor? | Passes eval? | Est. monthly cost | Ops burden | Notes |
| ------------------------ | ------------ | ------------------ | ------------ | ----------------- | ---------- | ----- |
| 1 Local                  |              |                    |              |                   |            |       |
| 2 Owned server           |              |                    |              |                   |            |       |
| 3 Rented GPU VM          |              |                    |              |                   |            |       |
| 4 Serverless GPU         |              |                    |              |                   |            |       |
| 5 Managed open-model API |              |                    |              |                   |            |       |
| 6 Frontier API           |              |                    |              |                   |            |       |
| 7 Hyperscaler platform   |              |                    |              |                   |            |       |

## Evidence

- Eval results: <link to eval report; date; models and versions tested>
- Cost model: <link or inline formula inputs; pricing pages checked on YYYY-MM-DD>
- Data terms checked: <provider pages and date checked; DPA/BAA status>

## Decision

<Chosen tier(s). If hybrid, name the pattern and the routing rule per workload.>

| Alias (what clients call) | Target tier | Model (pinned version) | Fallback | Data classes allowed |
| ------------------------- | ----------- | ---------------------- | -------- | -------------------- |
|                           |             |                        |          |                      |

## Consequences

- Positive: <...>
- Negative / risks: <...>
- Costs to watch: <idle GPUs, egress, reserved capacity, residency uplifts>

## Exit plan

- How we would move off this choice: <alias repoint; target to move to; data export>
- Rollback window: <how long the previous target stays available>

## Hand-off

- Build: <local-llms | self-hosted-llms | cloud-llms>
- Gateway: llm-gateway
- Evals: llm-evals
- Observability: llm-observability
