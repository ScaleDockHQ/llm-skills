# SageMaker endpoint types, scaling, scale to zero and budgets

> Verified against Amazon SageMaker AI Developer Guide pages endpoint-auto-scaling, endpoint-auto-scaling-zero-instances, async-inference, async-inference-invoke-endpoint, async-inference-autoscale, serverless-endpoints, inference-cost-optimization; AWS Budgets user guide, 2026-10-11

## Pick an endpoint type

| Type                                | Fits                                                                      | Scale to zero                                      | LLM notes                                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Real-time (instance-based)          | Low latency, steady traffic                                               | No, unless it hosts inference components           | Default for LLMs; bills per instance while up                                                      |
| Real-time with inference components | Several models or scale-to-zero on one endpoint                           | Yes (`MinInstanceCount` 0 plus component copies 0) | Cold start of several minutes; calls fail until capacity exists                                    |
| Asynchronous                        | Queued, latency-insensitive, payloads up to 1 GB, processing up to 1 hour | Yes                                                | S3 in and out, optional SNS notifications; an `AsyncInferenceConfig` makes the endpoint async-only |
| Serverless Inference                | Spiky small models                                                        | Yes                                                | **No GPUs**, 1 to 6 GB memory, 10 GB image limit, no VPC config: not suitable for LLMs             |
| Batch transform                     | Offline datasets                                                          | n/a                                                | Pay for the job duration                                                                           |

An instance-based real-time endpoint cannot be converted to serverless (`ValidationError`). Without inference components, a real-time endpoint cannot scale below one instance.

## Autoscaling (real-time)

Flow: register a scalable target, define a policy, apply it. Dimension `sagemaker:variant:DesiredInstanceCount`, resource id `endpoint/<name>/variant/<variant>`. Target-tracking on invocations per instance is the common choice; for LLMs prefer a metric reflecting concurrency or queue depth. Console is the easiest first setup.

## Scale to zero with inference components

Requirements from the docs: the endpoint is `InService`, hosts one or more inference components, and the endpoint config's variant has `ManagedInstanceScaling.MinInstanceCount` set to `0`.

1. Scale in to zero (per component):

```bash
aws application-autoscaling register-scalable-target --service-namespace sagemaker \
  --resource-id inference-component/<ic-name> \
  --scalable-dimension sagemaker:inference-component:DesiredCopyCount \
  --min-capacity 0 --max-capacity <n>
aws application-autoscaling put-scaling-policy --policy-name ic-target --policy-type TargetTrackingScaling \
  --resource-id inference-component/<ic-name> --service-namespace sagemaker \
  --scalable-dimension sagemaker:inference-component:DesiredCopyCount \
  --target-tracking-scaling-policy-configuration file://config.json
```

`config.json`: `PredefinedMetricSpecification.PredefinedMetricType` = `SageMakerInferenceComponentInvocationsPerCopy`, `TargetValue` 1, `ScaleInCooldown` 300, `ScaleOutCooldown` 300.

2. Scale out from zero: a StepScaling policy (`AdjustmentType` `ChangeInCapacity`, `MetricAggregationType` `Maximum`, `Cooldown` 60, one step adding 1 copy) attached to a CloudWatch alarm on metric `NoCapacityInvocationFailures` (namespace `AWS/SageMaker`, dimension `InferenceComponentName`, statistic Sum, period 60, threshold 1, `GreaterThanThreshold`) via `aws cloudwatch put-metric-alarm --alarm-actions <policy-arn>`.

Provisioning takes several minutes and invocations during that time return an error: clients must retry with backoff, or keep one copy warm.

## Asynchronous endpoints

Create like a real-time endpoint but with `AsyncInferenceConfig` in `CreateEndpointConfig`; invoke with `InvokeEndpointAsync` (inline `Body` up to 128,000 bytes, or S3 `InputLocation`; `InvocationTimeoutSeconds` up to 3600, default 15 minutes). Results land in S3. Autoscale with target tracking on custom metric `ApproximateBacklogSizePerInstance` (namespace `AWS/SageMaker`); register the variant with `MinCapacity` 0. Without the optional extra policy (step scaling on `HasBacklogWithoutCapacity`), scale up from zero waits until the backlog exceeds the target.

## Serverless limits (for reference)

Memory 1024 to 6144 MB in 1 GB steps, 5 GB ephemeral disk, per-endpoint max concurrency up to 200, 50 serverless endpoints per Region, region-wide concurrency 500 or 1000 depending on Region. Excluded features include GPUs, VPC config, Marketplace model packages and Model Monitor. See https://docs.aws.amazon.com/sagemaker/latest/dg/serverless-endpoints.html.

## Cost controls

- **Know what bills:** every `InService` instance, async queue endpoints with a non-zero minimum, inference component copies, S3 artifacts, ECR images, CloudWatch logs, NAT or VPC endpoints.
- **AWS Budgets:** cost or usage budgets with email or SNS notifications and optional actions; data refreshes up to three times a day so alerts lag. Create at https://console.aws.amazon.com/billing/home#/budgets.
- **SageMaker Savings Plans** exist for steady usage (commitment in $/hour; see the cost optimization page); do not commit before measuring.
- **Right-size:** check CloudWatch GPU and CPU utilization; consolidate low-utilization endpoints onto one endpoint with inference components; use Inference Recommender to compare instance types.
- **Daily check:** `aws sagemaker list-endpoints --status-equals InService` in every Region you use, plus Cost Explorer filtered to SageMaker.
- Prices: read the pricing page, do not copy numbers.
