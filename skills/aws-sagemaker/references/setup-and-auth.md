# SageMaker setup, roles, quotas and discovery

> Verified against Amazon SageMaker AI Developer Guide pages realtime-endpoints-deploy-models, endpoint-auto-scaling-prerequisites, What is SageMaker AI (rename note), AWS CLI v2.37.12 sagemaker list-endpoints and service-quotas list-service-quotas references, 2026-10-11

## Naming

Amazon SageMaker became **Amazon SageMaker AI** on 2024-12-03. `sagemaker` API namespaces, CLI commands, `AmazonSageMaker*` managed policies, service endpoints and console and doc URLs are unchanged. "Amazon SageMaker" now also names a wider unified data and AI platform (Unified Studio, Lakehouse); the hosting features in this skill are SageMaker AI.

## Identity and roles

Two separate roles:

1. **Execution role** passed as `ExecutionRoleArn` at `create-model` or `create-endpoint-config`. SageMaker assumes it to read model artifacts from S3 and images from ECR and to write logs. The docs' deploy flow needs the S3 bucket to be in the same Region as the model. `AmazonSageMakerFullAccess` is the broad managed option; scope down for production.
2. **Caller role** (you, CI, the gateway) with `sagemaker:InvokeEndpoint` (and `sagemaker:InvokeEndpointAsync` for async) on the endpoint ARN. Custom policies that let Studio create resources must also allow tagging, or you get `AccessDenied`.

Autoscaling needs: `sagemaker:DescribeEndpoint`, `sagemaker:DescribeEndpointConfig`, `sagemaker:UpdateEndpointWeightsAndCapacities`, `application-autoscaling:*`, `cloudwatch:PutMetricAlarm`, `cloudwatch:DescribeAlarms`, `cloudwatch:DeleteAlarms`, and `iam:CreateServiceLinkedRole` for `AWSServiceRoleForApplicationAutoScaling_SageMakerEndpoint` (created automatically if allowed). `AmazonSageMakerFullAccess` covers these.

Use temporary credentials (SSO, instance role, IRSA); keep any secrets such as `HF_TOKEN` in Secrets Manager or a `0600` file, never printed.

## Before you deploy

Locate and note (from the AWS deploy guide):

- Region of the S3 bucket holding model artifacts.
- S3 URI of the artifacts (for HF-hub models via LMI, the Hub id replaces this).
- The execution role ARN.
- The ECR image URI (custom image) or the framework and version of a built-in image.

## Quota check

GPU instance types have per-type, per-Region endpoint-usage quotas and are often zero in new accounts. Read applied values and request increases through Service Quotas (adjustable quotas only):

```bash
aws service-quotas list-service-quotas --service-code sagemaker --region "$REGION" \
  --query "Quotas[?contains(QuotaName,'<instance-type>')].[QuotaName,QuotaCode,Value,Adjustable]" --output text
```

Quota names follow the pattern "`<instance-type>` for endpoint usage" in the console; unverified: check the Service Quotas console for exact wording. Serverless endpoints have their own limits (see `scaling-and-cost.md`).

## Discovery commands (read-only)

```bash
aws sagemaker list-endpoints --region "$REGION" --status-equals InService
aws sagemaker describe-endpoint --endpoint-name <name> --region "$REGION" \
  --query '{Status:EndpointStatus,Config:EndpointConfigName,Failure:FailureReason}'
aws sagemaker describe-endpoint-config --endpoint-config-name <cfg> --region "$REGION" \
  --query 'ProductionVariants[].[VariantName,InstanceType,InitialInstanceCount,ModelName]'
aws sagemaker list-inference-components --region "$REGION"
aws sagemaker list-endpoint-configs --region "$REGION"
aws sagemaker list-models --region "$REGION"
```

`list-endpoints` accepts `--status-equals` with `OutOfService`, `Creating`, `Updating`, `SystemUpdating`, `RollingBack`, `InService`, `Deleting`, `Failed`, `UpdateRollbackFailed`; name filters are 63 characters max with pattern `[a-zA-Z0-9-]+`. A `Failed` endpoint can only be deleted.

## Tagging

Tag endpoints, configs and models (`--tags Key=project,Value=<name>`) so you can find and delete them later and attribute cost.
