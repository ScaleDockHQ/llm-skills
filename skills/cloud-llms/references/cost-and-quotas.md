# Cost and quotas

> Verified against AWS Budgets and Service Quotas docs, Amazon Bedrock quotas page, Google Cloud Billing budgets and quota docs, Azure Cost Management budgets and quota docs, OpenAI and Anthropic rate-limit pages, RunPod Serverless endpoint configuration, LiteLLM v1.105.0 budget docs, 2026-10-11

No prices here: they change. Use the formulas with current quotes from the pricing pages linked in `choosing-llm-hosting` (`references/cost-model.md`) or the providers' consoles.

## Budgets and alerts before traffic

Set all three layers before the first real request.

**1. Cloud account budgets** (billing truth, delayed by hours):

```bash
# AWS: list existing budgets (account ID from: aws sts get-caller-identity --query Account --output text)
aws budgets describe-budgets --account-id <account-id> --query 'Budgets[].[BudgetName,BudgetLimit.Amount,BudgetLimit.Unit]' --output text

# Google Cloud: list budgets on the billing account
gcloud billing budgets list --billing-account=<billing-account-id>

# Azure: budgets live in Cost Management (portal or REST); list consumption budgets for the subscription
az consumption budget list --query '[].{name:name,amount:amount,timeGrain:timeGrain}' -o table
```

Create budgets with alerts at several thresholds (for example 50%, 80%, 100% of forecast and actual) and route alerts to a channel someone reads. Docs: AWS Budgets, Google Cloud budgets, Azure Cost Management budgets (links below).

**2. Provider spend controls:** Anthropic organizations have monthly spend limits shown in the console; OpenAI organization and project limits are managed in the console's limits settings; GPU clouds have account balances or billing alerts in their consoles. Set the lowest limit that does not block normal use.

**3. Gateway budgets:** per provider, per deployment and per key (`gateway-hybrid.md`). Fast to react, but estimates; the cloud bill is authoritative.

## Quotas: request before you need them

| Platform | What is limited | Where to check / request |
| --- | --- | --- |
| OpenAI | RPM, TPM, RPD, TPD per model; usage tier (Build, Launch, Grow) | Console limits page; tier rises with credit purchases |
| Anthropic | Rate limits and spend limits by usage tier | Console Rate limits page; request higher limits |
| Gemini API | Per-model limits by project tier | Rate limits page; billing enabled raises tier |
| AWS Bedrock | Tokens and requests per minute per model and Region; applied values may be below defaults | Service Quotas (`aws service-quotas list-service-quotas --service-code bedrock`) |
| Agent Platform | Per-model quotas, shared pay-as-you-go capacity, provisioned throughput | Console quotas page |
| Microsoft Foundry | TPM per model, region and deployment type | Foundry quota page / Azure quotas |
| EC2 / GCE / Azure GPU VMs | GPU instance or vCPU quotas per region, often zero by default | Service Quotas, Cloud Quotas, Azure quotas |
| RunPod Serverless | Max workers per endpoint, account limits | Endpoint settings, support |

Request increases days to weeks ahead of launch, in every region you plan to use as a fallback, and keep the approval reference in the decision record.

## Cost formulas

```
api_cost      = (input_tokens × price_in + output_tokens × price_out) / 1,000,000
              − cached_input_tokens × (price_in − price_cached_in) / 1,000,000

vm_cost       = gpu_hourly × hours_running + disk_gb_month × disk_price + egress_gb × egress_price

serverless    = per_second × (busy_seconds + cold_start_seconds) + warm_workers × hours × per_hour

cost_per_M    = monthly_capacity_cost / (aggregate_tok_s × 3600 × busy_hours × days / 1,000,000)
```

Measure `aggregate_tok_s` with `scripts/bench.sh` at your real concurrency (`benchmarking-cloud.md`).

## The hidden bill

- **Idle GPUs**: VMs left running, warm serverless workers ("active workers" bill continuously), minimum replicas of 1 on managed endpoints, provisioned throughput at night.
- **Egress**: responses leaving a region or provider, cross-region calls between gateway and backend, model downloads from another region.
- **Storage**: volumes, snapshots and model registries that outlive the instance.
- **Load balancers and public IPs** left behind after teardown.
- **Logs**: verbose request logging into paid log storage.

## Teardown check (next day)

- [ ] Gateway entries removed or pointed elsewhere.
- [ ] No running instances, endpoints, node pools or serverless workers left (`runpodctl pod list`, `runpodctl serverless list`, `vastai show instances`, cloud console instance lists).
- [ ] Volumes, snapshots, buckets of weights deleted or intentionally kept.
- [ ] Load balancers and static IPs released.
- [ ] Provisioned throughput or reservations ended.
- [ ] Keys revoked, identities removed.
- [ ] Billing console shows the daily cost dropping to the expected baseline.

## Official links

- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
- AWS request a quota increase: https://docs.aws.amazon.com/servicequotas/latest/userguide/request-quota-increase.html
- Amazon Bedrock quotas: https://docs.aws.amazon.com/bedrock/latest/userguide/quotas.html
- Google Cloud budgets: https://docs.cloud.google.com/billing/docs/how-to/budgets
- Google Cloud quotas: https://docs.cloud.google.com/docs/quotas/view-manage
- Azure budgets: https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets
- Azure quota increase: https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal
- OpenAI rate limits: https://developers.openai.com/api/docs/guides/rate-limits
- Anthropic rate limits: https://platform.claude.com/docs/en/api/rate-limits
- Gemini API rate limits: https://ai.google.dev/gemini-api/docs/rate-limits
- RunPod endpoint configuration: https://docs.runpod.io/serverless/endpoints/endpoint-configurations
- LiteLLM budgets: https://docs.litellm.ai/docs/proxy/users
