# SageMaker with LiteLLM and OpenAI-style clients

> Verified against LiteLLM docs providers/aws_sagemaker (routes, auth parameters, inference components, streaming note), Deep Java Library LMI chat completions schema, Amazon SageMaker AI Developer Guide page realtime-endpoints-test-endpoints, 2026-10-11

SageMaker endpoints are not OpenAI base-URL endpoints: invocations are SigV4-signed to `https://runtime.sagemaker.<region>.amazonaws.com/endpoints/<name>/invocations`, so clients need an AWS SDK, or you put LiteLLM in front. Unverified: the exact runtime URL path; the SDKs build it for you, prefer them over hand-built requests.

## LiteLLM routes

| Prefix                        | Payload                                         | Use when                                                           |
| ----------------------------- | ----------------------------------------------- | ------------------------------------------------------------------ |
| `sagemaker/<endpoint>`        | Hugging Face TGI-style (`inputs`, `parameters`) | Classic JumpStart or HF containers                                 |
| `sagemaker_chat/<endpoint>`   | Messages API (OpenAI chat shape)                | LMI or vLLM containers with a chat template (recommended for LLMs) |
| `sagemaker_nova/<endpoint>`   | OpenAI-compatible, for Nova models on SageMaker | Custom Nova                                                        |
| `sagemaker/openai/<endpoint>` | OpenAI embeddings shape                         | Embedding containers                                               |

```yaml
model_list:
  - model_name: my-llm
    litellm_params:
      model: sagemaker_chat/my-llm # the endpoint name
      aws_region_name: us-east-1 # credentials from the AWS chain (role or profile)
  - model_name: my-llm-ic
    litellm_params:
      model: sagemaker_chat/my-ic-endpoint
      model_id: my-ic # inference component name, for component-based endpoints
      aws_region_name: us-east-1
```

Auth parameters documented by LiteLLM: `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`, `aws_region_name`, `aws_session_name`, `aws_profile_name`, `aws_role_name`, `aws_web_identity_token`. Prefer a role over static keys; if you must, reference with `os.environ/NAME`.

Notes from LiteLLM docs:

- `temperature=0` is rounded up to `0.1` by default because SageMaker fails most requests at 0; set `aws_sagemaker_allow_zero_temp: true` if your model accepts 0.
- The `sagemaker/` route fakes streaming by chunking the full response. Use `sagemaker_chat/` for real streaming where the container supports it (unverified for your container: test).
- For HF chat templates on `sagemaker/` pass `hf_model_name`.
- Scale-to-zero endpoints cold start in minutes: set a long gateway `timeout`, `num_retries`, and a fallback alias to another provider.

## boto3 invoke

```python
import json, boto3
rt = boto3.client("sagemaker-runtime", region_name="us-east-1")
r = rt.invoke_endpoint(
    EndpointName="my-llm",
    # InferenceComponentName="my-ic",          # for component-based endpoints
    ContentType="application/json",
    Body=json.dumps({"messages": [{"role": "user", "content": "Hello"}], "max_tokens": 128}),
)
print(json.loads(r["Body"].read()))
```

Streaming uses `invoke_endpoint_with_response_stream`; bidirectional streaming has its own SDK per the docs. Async uses `invoke_endpoint_async`.

## Behind an OpenAI-compatible client

Point the app at the gateway (`base_url=http://<gateway>/v1`, gateway virtual key). The app never holds AWS credentials; the gateway role needs `sagemaker:InvokeEndpoint` on the endpoint ARN. Use `llm-gateway` for keys, budgets and fallbacks.
