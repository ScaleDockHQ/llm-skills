# Hugging Face Inference Endpoints

> Verified against huggingface_hub Inference Endpoints guide, HF Inference Endpoints docs (create, access, pause and resume, vLLM engine page), `hf endpoints` CLI, 2026-10-11

Dedicated, autoscaling deployments of Hub models on cloud GPUs, CPUs and accelerators managed by Hugging Face. Billed by the minute while running (see `limits-and-billing.md`). Needs `huggingface_hub` (API available since v0.19.0) and a logged-in token.

## Find hardware and quota

```bash
hf endpoints hardware --accelerator gpu
hf endpoints hardware --namespace my-org     # quota is per namespace
```

Python: `list_inference_endpoints_hardware()` returns valid vendor, region, `instance_type`, `instance_size`, price per hour and quota. The values depend on each other, so pick a listed combination. Never copy the prices; read them from this command.

## Deploy

Catalog (curated recipes of hardware plus engine, experimental):

```bash
hf endpoints catalog ls
hf endpoints catalog deploy --repo openai/gpt-oss-120b [--accelerator gpu] [--name my-endpoint]
hf endpoints catalog deploy --recipe <recipe-id>
```

Custom:

```bash
hf endpoints deploy my-endpoint --repo <org/model> --framework pytorch --task text-generation \
  --accelerator gpu --vendor aws --region us-east-1 --instance-type <type> --instance-size <size>
# vLLM or SGLang engine image on multi-GPU instances
hf endpoints deploy my-endpoint --repo <org/model> --framework custom --accelerator gpu --vendor aws \
  --region us-east-1 --instance-type <type> --instance-size x8 \
  --engine vllm --custom-image vllm/vllm-openai:<pinned-tag> --tensor-parallel-size 8
```

- Access: `authenticated` (token required) is the default in the examples. Avoid public endpoints without a reason.
- Pin the image tag. Set `--tensor-parallel-size` for multi-GPU instances: vLLM and SGLang default to one accelerator, which would waste the rest while still billing for all. Per the vLLM engine page, the endpoint defaults tensor parallel size to the GPU count and data parallel size to 1; choose TP times DP equal to GPUs on the instance.
- Private registries: `--container-registry-username` and password options; read the password from a file, not the command line, where the CLI allows it.

Python equivalents: `create_inference_endpoint(...)`, `create_inference_endpoint_from_catalog(repo_id=...)`.

## Status and wait

```bash
hf endpoints describe my-endpoint        # status such as pending, initializing, running, paused, scaledToZero; url when running
hf endpoints ls --namespace '*'
```

Python: `endpoint.wait(timeout=..., fetch_every=...)` blocks until running (raises `InferenceEndpointTimeoutError` on timeout).

## Call it

LLM endpoints with vLLM, SGLang or TGI expose OpenAI routes: use the endpoint URL with `/v1` appended, your HF token as the bearer, and the model id the server reports.

```bash
URL="$(hf endpoints describe my-endpoint --json | jq -r '.url // empty')"   # check field names with: hf endpoints describe my-endpoint --json | jq 'keys'
curl -sS "$URL/v1/chat/completions" -H "Authorization: Bearer $HF_TOKEN" -H "Content-Type: application/json" \
  -d '{"model":"<model id>","messages":[{"role":"user","content":"hi"}],"max_tokens":32}'
```

The Python `endpoint.client` and `endpoint.async_client` return `InferenceClient` objects once the endpoint is running (before that they raise `InferenceEndpointError`).

## Scale, pause, resume, scale to zero

```bash
hf endpoints update my-endpoint --min-replica 1 --max-replica 3
hf endpoints pause my-endpoint          # stops billing; must be resumed by you
hf endpoints resume my-endpoint
hf endpoints scale-to-zero my-endpoint  # stays addressable, wakes on the first request
```

- **Pause**: sets replicas to zero, billing stops, URL kept, explicit `resume` required.
- **Scale to zero**: automatic after an idle period (15 minutes in the docs), free while zero, but the first requests get HTTP 502 until the replica is ready and requests are not queued. Add retry with backoff (or call `wait`). Scaled-to-zero endpoints still count against your quota.
- Update model, image, hardware or engine flags: `hf endpoints update my-endpoint --repo ... | --instance-size ... | --container-args "..." | --tensor-parallel-size N`. Changing these restarts the endpoint (status goes back to pending).

## Delete

```bash
hf endpoints delete my-endpoint --yes
```

Irreversible: configuration, logs and usage metrics are removed.

## Official links

- huggingface_hub guide: https://huggingface.co/docs/huggingface_hub/guides/inference_endpoints
- Endpoints docs: https://huggingface.co/docs/inference-endpoints
- vLLM engine: https://huggingface.co/docs/inference-endpoints/en/engines/vllm
