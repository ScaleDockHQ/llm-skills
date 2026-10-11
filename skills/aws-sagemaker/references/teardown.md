# SageMaker teardown

> Verified against Amazon SageMaker AI Developer Guide pages realtime-endpoints-delete-resources, async-inference-delete-endpoint, endpoint-auto-scaling-zero-instances, endpoint-auto-scaling-prerequisites, 2026-10-11

Deleting the **endpoint** frees the deployed resources and stops instance charges. It does **not** delete the endpoint config or the model. Deleting a model does not delete the model artifacts in S3, inference code, or the IAM role. List first, ask before deleting anything you did not create, and repeat for every Region you used.

## 1. Find what exists

```bash
aws sagemaker list-endpoints --region "$REGION" --query 'Endpoints[].[EndpointName,EndpointStatus]' --output table
aws sagemaker list-inference-components --region "$REGION" --query 'InferenceComponents[].[InferenceComponentName,EndpointName]' --output table
aws sagemaker list-endpoint-configs --region "$REGION" --query 'EndpointConfigs[].EndpointConfigName' --output text
aws sagemaker list-models --region "$REGION" --query 'Models[].ModelName' --output text
aws application-autoscaling describe-scalable-targets --service-namespace sagemaker --region "$REGION"
```

Record each endpoint's config and model before deleting the endpoint:

```bash
aws sagemaker describe-endpoint --endpoint-name <ep> --query EndpointConfigName --output text
aws sagemaker describe-endpoint-config --endpoint-config-name <cfg> \
  --query 'ProductionVariants[].[ModelName,InstanceType]' --output text
```

## 2. Delete in this order

```bash
# a) Inference components (if any)
aws sagemaker delete-inference-component --inference-component-name <ic> --region "$REGION"

# b) Autoscaling objects and alarms (otherwise they linger or recreate capacity)
aws application-autoscaling deregister-scalable-target --service-namespace sagemaker \
  --resource-id endpoint/<ep>/variant/<variant> --scalable-dimension sagemaker:variant:DesiredInstanceCount
aws application-autoscaling deregister-scalable-target --service-namespace sagemaker \
  --resource-id inference-component/<ic> --scalable-dimension sagemaker:inference-component:DesiredCopyCount
aws cloudwatch delete-alarms --alarm-names <alarm-name>

# c) Endpoint, then its config, then the model
aws sagemaker delete-endpoint --endpoint-name <ep> --region "$REGION"
aws sagemaker delete-endpoint-config --endpoint-config-name <cfg> --region "$REGION"
aws sagemaker delete-model --model-name <model> --region "$REGION"
```

Do not delete an endpoint config that a live, creating or updating endpoint uses (you can lose visibility into its instance type). Deleting an endpoint config does not delete its endpoints. Unverified: `delete-inference-component` flag names; confirm with `aws sagemaker delete-inference-component help`. `deregister-scalable-target` also removes policies on that target.

## 3. Leftovers that still cost or expose

- S3 model artifacts and async inference input and output prefixes.
- ECR repository holding a custom image (async docs list this explicitly).
- Async SNS topics, CloudWatch log groups (`/aws/sagemaker/Endpoints/<name>`) and alarms.
- Interface VPC endpoints or NAT gateways created just for the endpoint.
- Gateway entries and virtual keys that pointed at the endpoint; the HF token secret.
- Studio or notebook apps you started for deployment (not covered here).

## 4. Verify

```bash
aws sagemaker list-endpoints --region "$REGION" --query 'length(Endpoints)'
aws sagemaker list-inference-components --region "$REGION" --query 'length(InferenceComponents)'
aws sagemaker list-endpoint-configs --region "$REGION" --query 'length(EndpointConfigs)'
aws sagemaker list-models --region "$REGION" --query 'length(Models)'
aws application-autoscaling describe-scalable-targets --service-namespace sagemaker --region "$REGION" --query 'length(ScalableTargets)'
```

All zero (or only intended items). Next day, check Cost Explorer filtered to SageMaker for the endpoint's instance-hours dropping to zero.
