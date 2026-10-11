# Bedrock batch inference, Custom Model Import and Provisioned Throughput

> Verified against Amazon Bedrock User Guide pages batch-inference, batch-inference-data, batch-inference-create, model-customization-import-model, model-customization-import-model-job, prov-throughput, quotas-runtime, 2026-10-11

## Batch inference

Asynchronous: upload JSONL to S3, submit a job, read output from S3. Not supported for provisioned models. Batch does **not** support tool calling or structured output (`response_format`). Quotas apply (minimum and maximum records, records per file, file size, total job size); look them up in Service Quotas. EventBridge can notify on job state changes.

### Input format

Each line: `{"recordId": "...", "modelInput": {...}}`. For invocation type `InvokeModel` (default) `modelInput` matches that model's `InvokeModel` body; for `Converse` it matches the Converse request:

```json
{
  "recordId": "CALL0000001",
  "modelInput": {
    "messages": [{ "role": "user", "content": [{ "text": "Summarize: ..." }] }],
    "inferenceConfig": { "maxTokens": 1024 }
  }
}
```

Output order is not guaranteed to match input order; `recordId` is added if omitted. If prompts reference S3 objects (video, images), keep everything in the same bucket and folder and point `inputDataConfig` at the folder, not just the `.jsonl` file. S3 paths are case-sensitive.

### Create a job (API: CreateModelInvocationJob)

Required: `jobName`, `roleArn` (service role with S3 and model permissions), `modelId`, `inputDataConfig`, `outputDataConfig`. Optional: `modelInvocationType` (`Converse` or `InvokeModel`), `timeoutDurationInHours`, `tags`, `vpcConfig` (API only), `clientRequestToken`. Cross-account S3 input or output requires the API, not the console.

```bash
aws bedrock create-model-invocation-job --region <region> \
  --job-name my-batch-001 --role-arn <service-role-arn> --model-id <model-or-profile-id> \
  --model-invocation-type Converse --timeout-duration-in-hours 24 \
  --input-data-config 's3InputDataConfig={s3Uri=s3://<bucket>/in/}' \
  --output-data-config 's3OutputDataConfig={s3Uri=s3://<bucket>/out/}'
aws bedrock get-model-invocation-job --region <region> --job-identifier <jobArn>
aws bedrock list-model-invocation-jobs --region <region>
aws bedrock stop-model-invocation-job --region <region> --job-identifier <jobArn>
```

The shorthand structures above follow the API field names; confirm with `aws bedrock create-model-invocation-job help`. Unverified: the exact CLI flag names for get/stop (check `help`). Ask before submitting: it bills per token.

## Custom Model Import

Import open-architecture weights you customized elsewhere (for example in SageMaker) and call them with on-demand `InvokeModel` / `InvokeModelWithResponseStream`.

- Regions: `eu-central-1`, `us-east-1`, `us-east-2`, `us-west-2`. GPT-OSS architecture only in `us-east-1`.
- Supported architectures include Mistral, Mixtral, Flan, Llama 2/3/3.1/3.2/3.3 and Mllama, GPTBigCode, Qwen2/2.5/2-VL/2.5-VL/3 (Qwen3 only `Qwen3ForCausalLM` and `Qwen3MoeForCausalLM`; Converse not supported for Qwen3), GPT-OSS 20B and 120B.
- Limits: weights under 200 GB for text models and under 100 GB for multimodal; context length under 128K; transformers 4.51.3; no embedding models.
- Not usable with batch inference or CloudFormation.
- Files in Hugging Face format in S3: `.safetensors` weights, `config.json`, tokenizer files (`tokenizer_config.json`, `tokenizer.json`, `tokenizer.model`).
- API: `CreateModelImportJob` (required `roleArn`, `importedModelName`, `jobName`, `modelDataSource`; optional VPC, KMS key, tags). Then `GetModelImportJob`, `ListImportedModels`, `GetImportedModel`, `DeleteImportedModel`. You can also import directly from a SageMaker AI model.
- The imported model ARN is the `modelId` for invocation. Check the docs page "Calculate the cost of running a custom model" for the billing model.

If you need an OpenAI-compatible server, custom containers or scale-to-zero control, use `aws-sagemaker` instead.

## Provisioned Throughput

Reserved Model Units (MUs) at a fixed hourly cost. Required for models customized through Bedrock customization per the docs (imported models can use on-demand throughput). Commitment: none (deletable any time), 1 month or 6 months (cannot delete until term ends). **Billing continues until you delete it.** Not available for models in Legacy state, and not available through inference profiles. MU sizing and increases go through your AWS account manager. Use only when measured steady load justifies it, and ask before purchase.

```bash
aws bedrock list-provisioned-model-throughputs --region <region>
```
