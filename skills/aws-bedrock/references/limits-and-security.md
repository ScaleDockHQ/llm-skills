# Bedrock quotas, budgets, VPC endpoints and data path

> Verified against Amazon Bedrock User Guide pages quotas, quotas-runtime, vpc-interface-endpoints, cross-region-inference, troubleshooting-api-error-codes; AWS Budgets user guide (budgets-managing-costs); AWS CLI v2.37.12 service-quotas list-service-quotas, 2026-10-11

## Quotas

Inference is limited by per-model token quotas. Applied values can be lower than the published defaults depending on Region, account age, usage and payment history, so always read your own:

```bash
aws service-quotas list-service-quotas --service-code bedrock --region <region> \
  --query "Quotas[?contains(QuotaName,'<model-name>')].[QuotaName,QuotaCode,Value,Adjustable]" --output text
```

`bedrock-runtime` per-model quotas (shared across InvokeModel, Converse, Responses and Chat Completions, despite the "InvokeModel" in the name):

- Cross-Region InvokeModel tokens per minute for the model (input plus output combined).
- On-demand InvokeModel tokens per minute for the model (single Region).
- Cross-Model Max Tokens Per Day per account and Region.
- InvokeModel requests per minute for the model. Enforced only for some models; some models have no RPM quota.

Output tokens count with a model-specific burndown rate, and `max_tokens` affects deductions: set it tight. `bedrock-mantle` has separate input and output tokens-per-minute quotas that are tracked separately even for the same model. Batch inference, custom inference profiles and Provisioned Throughput have their own quotas.

### Request an increase

Use Service Quotas (adjustable quotas only). For any model you can request cross-Region TPM, on-demand TPM and daily tokens together by requesting the cross-Region TPM increase; support then offers the other two. Increases are not automatic and priority goes to customers whose traffic already consumes its quota. No increases for Legacy or Deprecated models.

### Cope with throttling

Retry with exponential backoff and jitter, spread load with a cross-Region profile (geographic if residency applies), cap `max_tokens`, and for steady load consider Reserved Tier (through your AWS account team, model-dependent) or Provisioned Throughput.

## Budgets and cost visibility

- **AWS Budgets** gives cost and usage budgets with email or SNS notifications and optional actions (for example applying an IAM policy that denies provisioning). Data refreshes up to three times a day, so alerts lag: it warns, it does not hard-stop. Create at `https://console.aws.amazon.com/billing/home#/budgets`.
- **Attribution**: application inference profiles with cost allocation tags on `bedrock-runtime`; Projects and Workspaces on `bedrock-mantle`; otherwise IAM principal.
- **Gateway budgets** (`llm-gateway`) enforce per-key spend before AWS bills arrive.
- Read prices from https://aws.amazon.com/bedrock/pricing/; do not copy numbers into configs.

## Private networking: interface VPC endpoints (PrivateLink)

Service names (replace `region`): `com.amazonaws.region.bedrock` (control plane), `.bedrock-runtime`, `.bedrock-mantle`, `.bedrock-agent`, `.bedrock-agent-runtime`, plus `.bedrock-fips` and `.bedrock-runtime-fips` (available in us-east-1, us-east-2, us-west-2, ca-central-1, us-gov-east-1, us-gov-west-1).

- With **Private DNS** enabled, default hostnames (`bedrock-runtime.region.amazonaws.com`, `bedrock-mantle.region.api.aws`) resolve to the endpoint; no code change.
- Without it, pass the endpoint URL explicitly:

```bash
aws bedrock-runtime converse --model-id <id> --messages '[{"role":"user","content":[{"text":"Hi"}]}]' \
  --endpoint-url https://<vpce-id>.bedrock-runtime.<region>.vpce.amazonaws.com
```

- Attach an **endpoint policy** to limit principals, actions and resources. The default allows full access. Runtime actions: `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`; mantle: `bedrock-mantle:CreateInference`.
- Using endpoints in-VPC also avoids NAT or internet-gateway egress charges.
- Batch jobs and import jobs accept a `vpcConfig` (API only for batch).
- Interface endpoints, NAT gateways and NLBs drop connections idle more than 350 seconds; enable TCP keep-alive (`troubleshooting.md`).

## Data path checklist

- [ ] Region of the endpoint and any cross-Region profile destinations known.
- [ ] Global profiles avoided for regulated data; SCPs allow the needed destination Regions.
- [ ] All calls logged in CloudTrail (API keys are passed as headers and are not logged).
- [ ] Invocation logging destinations (if enabled) have retention set and restricted access.
- [ ] Contract coverage (DPA, BAA) checked for the chosen model and Region; see `choosing-llm-hosting`.
- Bedrock docs' data protection page: https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html (not re-read for this skill; confirm specifics there).
