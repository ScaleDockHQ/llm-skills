# Deploying an LLM on SageMaker AI

> Verified against Amazon SageMaker AI Developer Guide pages realtime-endpoints-deploy-models, realtime-endpoints-test-endpoints, jumpstart-foundation-models-use-python-sdk, large-model-inference-container-docs; Deep Java Library LMI docs (overview, starting guide, chat completions schema), 2026-10-11

## Hosting objects

Three objects make a classic endpoint: **Model** (container image plus artifacts), **EndpointConfig** (production variants with instance type and count), **Endpoint**. An **inference component** is an optional extra object that deploys a model onto an endpoint with its own copy count and resource needs; it is what enables scale to zero and multiple models per endpoint. The endpoint name must be unique within a Region and account.

## Option A: JumpStart

JumpStart offers catalog models (some pre-benchmarked for cost or performance in Studio). Programmatically use the SageMaker Python SDK (`ModelBuilder` with a JumpStart model id; proprietary models need an AWS Marketplace subscription and a model package). Some models need explicit EULA acceptance. Look up model ids in the JumpStart "Available foundation models" list; do not guess. See https://docs.aws.amazon.com/sagemaker/latest/dg/jumpstart-foundation-models-use-python-sdk.html.

## Option B: LMI container (vLLM) with `HF_MODEL_ID`

AWS LMI (Large Model Inference) containers are Docker images (`djl-inference` family) that bundle the DJL model server with vLLM or TensorRT-LLM. Features per the docs: continuous batching, token streaming, quantization (AWQ, GPTQ, FP8), tensor parallelism, LoRA adapters, text embedding, speculative decoding.

Most models need only environment variables:

| Variable                     | Meaning                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------- |
| `HF_MODEL_ID`                | Hub id, `s3://` URI, or `/opt/ml/model` when using uncompressed model artifacts |
| `HF_REVISION`                | Pin the Hub commit or branch                                                    |
| `HF_TOKEN`                   | Token for gated models                                                          |
| `HF_MODEL_TRUST_REMOTE_CODE` | `true` only after you audited custom code (default false)                       |
| `TENSOR_PARALLEL_DEGREE`     | GPUs to shard over; default `max`                                               |
| `MAX_BATCH_SIZE`             | Default 256                                                                     |
| `MAX_CONCURRENT_REQUESTS`    | Default 1000; at least `MAX_BATCH_SIZE`; excess requests queue                  |

Advanced settings use `serving.properties` (`option.model_id`, `option.tensor_parallel_degree`, `option.max_rolling_batch_size`, `job_queue_size` and so on); see the LMI advanced deployment guide at https://docs.djl.ai/master/docs/serving/serving/docs/lmi/index.html. Engine flags themselves belong to `vllm`.

**Image URI:** the LMI docs show images like `763104351884.dkr.ecr.<region>.amazonaws.com/djl-inference:<djl>-lmi<N>.0.0-cu<NNN>` (backend `vLLM`: `djl-lmi`; TensorRT-LLM: `djl-tensorrtllm`). Tags in the docs examples differ between pages and age quickly; take the current tag from the SageMaker Deep Learning Containers repository (https://github.com/aws/deep-learning-containers) and pin it. Unverified: exact current tag.

### CLI deploy (no inference component)

```bash
aws sagemaker create-model --model-name my-llm --region "$REGION" \
  --execution-role-arn <role-arn> \
  --primary-container '{"Image":"<lmi-image-uri>","Environment":{"HF_MODEL_ID":"<org/model>","HF_REVISION":"<commit>","TENSOR_PARALLEL_DEGREE":"max"}}'
aws sagemaker create-endpoint-config --endpoint-config-name my-llm-cfg --region "$REGION" \
  --production-variants '[{"VariantName":"AllTraffic","ModelName":"my-llm","InstanceType":"<ml.g*/p* type>","InitialInstanceCount":1,"ContainerStartupHealthCheckTimeoutInSeconds":900,"ModelDataDownloadTimeoutInSeconds":900}]'
aws sagemaker create-endpoint --endpoint-name my-llm --endpoint-config-name my-llm-cfg --region "$REGION"
aws sagemaker wait endpoint-in-service --endpoint-name my-llm --region "$REGION"
```

The docs show the core `create-model`, `create-endpoint-config`, `create-endpoint` flow; the container `Environment` key and the timeout fields come from the API shapes (unverified in the pages read): confirm with `aws sagemaker create-model help`. Pass the gated-model token from a secret manager, not as a literal in a shared script. Ask before running `create-endpoint`: billing starts.

### CLI deploy with an inference component (needed for scale to zero)

```bash
aws sagemaker create-endpoint-config --endpoint-config-name my-ic-cfg \
  --execution-role-arn <role-arn> --production-variants file://production-variants.json
aws sagemaker create-endpoint --endpoint-name my-ic-endpoint --endpoint-config-name my-ic-cfg
aws sagemaker create-inference-component --inference-component-name my-ic \
  --endpoint-name my-ic-endpoint --variant-name AllTraffic \
  --specification file://specification.json --runtime-config '{"CopyCount": 1}'
```

`production-variants.json` per the docs: a variant with `VariantName`, `InstanceType`, `InitialInstanceCount` and `ManagedInstanceScaling` (`Status` ENABLED, `MinInstanceCount`, `MaxInstanceCount`) and no `ModelName` when the model lives in the component. `specification.json`: `Container` (`Image`, `ArtifactUrl`) or `ModelName`, plus `ComputeResourceRequirements` (`NumberOfCpuCoresRequired`, `MinMemoryRequiredInMb`; for GPU hosts also accelerator requirements, unverified field name `NumberOfAcceleratorDevicesRequired`).

### Python SDK v3

```python
from sagemaker.serve import ModelBuilder
mb = ModelBuilder(image_uri="<lmi-image-uri>", s3_model_data_url="s3://...",
                  role_arn="<role-arn>", instance_type="<instance-type>")
endpoint = mb.deploy(endpoint_name="my-llm", instance_type="<instance-type>", initial_instance_count=1)
```

For the older `DJLModel` flow shown in the LMI starting guide (`from sagemaker.djl_inference import DJLModel`), match your installed SDK version. Pass a token via `env` read from the environment, never hardcoded.

## Invoke

Real-time, via CLI (no streaming support in the CLI):

```bash
aws sagemaker-runtime invoke-endpoint --endpoint-name my-llm --region "$REGION" \
  --content-type application/json \
  --body '{"messages":[{"role":"user","content":"Hello"}],"max_tokens":128}' \
  --cli-binary-format raw-in-base64-out out.json && jq . out.json
```

LMI treats a request containing `messages` as an OpenAI-style chat request on `/invocations`, so the chat completions schema works on the same endpoint as the standard `inputs`/`parameters` schema. The model must have a chat template. `"stream": true` returns JSON lines; streaming needs an SDK (`InvokeEndpointWithResponseStream`), not the CLI. Tools and vision work only on the vLLM backend.

For a component-based endpoint add `--inference-component-name my-ic`. If `InvokeEndpoint` is attempted when no instances are running you get an error until capacity is provisioned (several minutes).

Async: `invoke-endpoint-async` with an S3 `InputLocation` or inline `Body` up to 128,000 bytes; see `scaling-and-cost.md`.
