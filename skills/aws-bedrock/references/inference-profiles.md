# Bedrock inference profiles, cross-Region inference and model lifecycle

> Verified against Amazon Bedrock User Guide pages cross-region-inference, inference-profiles-support, inference-profiles-use, inference-profiles-create, model-lifecycle, 2026-10-11

## Two kinds of profile

- **Cross-Region (system-defined) profiles** route a request from your source Region to a destination Region. Two flavors: **geographic** (US, EU, APAC and so on, IDs carry a prefix such as `us.`, `eu.`, `au.`) and **global** (any supported commercial Region, prefix `global.`).
- **Application inference profiles** wrap one model (one Region) or a cross-Region profile (multiple Regions) so you can tag and track usage and cost.

Use the profile **ID or ARN** in the `modelId` field of InvokeModel, Converse and their streaming variants. For system-defined profiles either ID or ARN works.

## Geographic vs global

|                 | Geographic                                    | Global                                         |
| --------------- | --------------------------------------------- | ---------------------------------------------- |
| Data residency  | Stays within the geography                    | Any supported commercial Region                |
| Cost            | Standard pricing                              | Approximately 10% savings per the docs         |
| SCP requirement | Allow every destination Region in the profile | Allow `aws:RequestedRegion` of `"unspecified"` |
| Best for        | Regulated data                                | Cost and throughput                            |

There is no extra routing charge; price follows the Region you call from. Traffic stays on the AWS network and is encrypted in transit. Destination lists of geographic profiles never change, but AWS can add new profiles with new Regions. Global destinations can grow.

Cross-Region inference can route to Regions you have not opted into, and prompts and outputs may be stored in opt-in Regions for abuse detection.

## Check where a profile can route

Do this from every source Region you will use. Do not trust the ID prefix alone.

```bash
aws bedrock list-inference-profiles --region <source-region> --type-equals SYSTEM_DEFINED \
  --query "inferenceProfileSummaries[?status=='ACTIVE'].[inferenceProfileId,inferenceProfileName]" --output table
aws bedrock get-inference-profile --region <source-region> \
  --inference-profile-identifier <profile-id> --query 'models[].modelArn'
```

Each model ARN's Region in the response is a destination. Some profiles route differently depending on the source Region. CloudTrail logs cross-Region calls in the source Region; look at `additionalEventData.inferenceRegion`.

If an SCP blocks any destination Region in the profile, the request fails even if others are allowed. Allow `bedrock:InvokeModel*` (and `bedrock:CreateModelInvocationJob` for batch) in all destinations.

Inference profiles do not support Provisioned Throughput.

## Application inference profiles (cost tracking)

Create with the `CreateInferenceProfile` API (required: `inferenceProfileName`, `modelSource`; optional `description`, `tags`, `clientRequestToken`):

```bash
aws bedrock create-inference-profile --region <region> \
  --inference-profile-name team-a-sonnet \
  --model-source copyFrom=<foundation-model-arn-or-system-profile-arn> \
  --tags key=cost-center,value=team-a
```

The `--model-source` shorthand syntax is from the API shape (`copyFrom`); confirm with `aws bedrock create-inference-profile help`. The response returns an `inferenceProfileArn` to use as the model ID. Activate the tag as a cost allocation tag in Billing to see spend by tag. Application profiles are not accepted for the Responses API on `bedrock-runtime`. Not all models (for example embeddings) support them.

## Model lifecycle

Models launched on or after 2026-09-07 follow the new lifecycle page: **Active**, **Legacy**, **EOL**. The status is in the `modelLifecycle` field from `GetFoundationModel` and `ListFoundationModels`. Check the model card for the EOL-no-sooner-than date and the Legacy period (6 months or 45 days).

- Legacy: usable but scheduled for retirement; new customers cannot adopt it; existing customers may lose access after 15 days of inactivity; no new Provisioned Throughput and no new fine-tuning on it.
- EOL: removed from all Regions; requests fail. Migration is not automatic.
- Quota increases are not granted for models in Legacy or Deprecated status.

Only Bedrock's model-card dates apply, not the provider's own dates. Models launched earlier follow a separate "Model lifecycle (Legacy)" page.

```bash
aws bedrock list-foundation-models --region <region> \
  --query 'modelSummaries[].[modelId,modelLifecycle.status]' --output text
```
