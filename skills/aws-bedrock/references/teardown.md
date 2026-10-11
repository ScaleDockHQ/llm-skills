# Bedrock teardown

> Verified against Amazon Bedrock User Guide pages api-keys, model-access, batch-inference-create, model-customization-import-model-job, prov-throughput, inference-profiles-create, 2026-10-11

On-demand Bedrock inference has no running resource: you pay per token. What keeps costing or stays exposed is below. Work through each, list first, delete second, ask before deleting anything you did not create.

## 1. Credentials

```bash
# Long-term API keys (IAM service-specific credentials)
aws iam list-service-specific-credentials --user-name <user> --service-name bedrock.amazonaws.com
aws iam update-service-specific-credential --user-name <user> --service-specific-credential-id <id> --status Inactive
aws iam delete-service-specific-credential --user-name <user> --service-specific-credential-id <id>
aws iam detach-user-policy --user-name <user> --policy-arn arn:aws:iam::aws:policy/AmazonBedrockLimitedAccess
aws iam delete-user --user-name <user>
```

Short-term keys expire (max 12 h); to cut them off sooner invalidate the source session or deny `bedrock:CallWithBearerToken` and `bedrock-mantle:CallWithBearerToken`. Delete any key file (`~/.config/aws-bedrock/api-key`) and unset `AWS_BEARER_TOKEN_BEDROCK`. Remove gateway entries and virtual keys that used them.

## 2. Provisioned Throughput (hourly billing)

```bash
aws bedrock list-provisioned-model-throughputs --region <region>
aws bedrock delete-provisioned-model-throughput --region <region> --provisioned-model-id <id>
```

Commitment terms of 1 or 6 months cannot be deleted before the term ends; billing continues until deletion.

## 3. Batch inference jobs and data

```bash
aws bedrock list-model-invocation-jobs --region <region> --status-equals InProgress
aws bedrock stop-model-invocation-job --region <region> --job-identifier <jobArn>
aws s3 rm s3://<bucket>/out/ --recursive      # only after confirming outputs are not needed
```

Stopping halts further work; completed records are still billed. S3 inputs and outputs keep costing storage until deleted.

## 4. Imported and application resources

```bash
aws bedrock list-imported-models --region <region>
aws bedrock delete-imported-model --region <region> --model-identifier <modelArnOrName>
aws bedrock list-inference-profiles --region <region> --type-equals APPLICATION
aws bedrock delete-inference-profile --region <region> --inference-profile-identifier <arn>
```

Delete the source weights in S3 if no longer needed. Also remove the service roles you created for batch or import.

## 5. Model access

`aws bedrock delete-foundation-model-agreement --model-id <id>` removes access, but the next invocation recreates it. To prevent that, attach a deny policy on `bedrock:InvokeModel` for the model at SCP or IAM level.

## 6. Network and budget

- Delete interface VPC endpoints for `bedrock-runtime` and `bedrock-mantle` (hourly and data charges): `aws ec2 delete-vpc-endpoints --vpc-endpoint-ids <vpce-id>`.
- Keep or remove the AWS Budget deliberately.

## Verify

```bash
aws bedrock list-provisioned-model-throughputs --region <region> --query 'length(provisionedModelSummaries)'
aws bedrock list-model-invocation-jobs --region <region> --query 'length(invocationJobSummaries)'
aws bedrock list-imported-models --region <region> --query 'length(modelSummaries)'
aws iam list-service-specific-credentials --service-name bedrock.amazonaws.com
```

Repeat for every Region you used. Unverified: the exact delete subcommand flag names for imported models and inference profiles (run `aws bedrock <command> help`). Check Cost Explorer the next day for Bedrock and VPC endpoint line items.
