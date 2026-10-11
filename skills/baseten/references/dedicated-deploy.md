# Baseten dedicated deployments

> Verified against docs.baseten.co examples/deploy-your-first-model, examples/vllm, deployment/resources, development/model/overview, inference/calling-your-model, 2026-10-11

A dedicated deployment runs your model on GPUs you reserve. Three build paths: Engine-Builder (TRT-LLM based, config only), a Python `Model` class, or a custom Docker server (any OpenAI-compatible server such as vLLM or SGLang). Show the user the full config before pushing.

## Custom Docker server with vLLM

```yaml
model_name: qwen-vllm
base_image:
  image: vllm/vllm-openai:v0.29.0 # pin a tag; check the vLLM release you want
docker_server:
  start_command: vllm serve /models/qwen --served-model-name qwen --host 0.0.0.0 --port 8000 --enable-prefix-caching
  readiness_endpoint: /health
  liveness_endpoint: /health
  predict_endpoint: /v1/chat/completions
  server_port: 8000
weights:
  - source: "hf://<org>/<model>@<commit-sha>"
    mount_location: /models/qwen
    auth:
      auth_method: CUSTOM_SECRET
      auth_secret_name: hf_access_token # only for gated repos
resources:
  accelerator: L4 # or use instance_type, see below
secrets:
  hf_access_token: null
runtime:
  predict_concurrency: 32
```

Field names are from the vLLM example page. Confirm against the current page before use because the schema evolves. Flags like `--enable-prefix-caching` belong to vLLM; for engine tuning see `self-hosted-llms`.

## Engine-Builder config

The docs show a `trt_llm.build` block: `base_model: decoder`, `checkpoint_repository` with `source: HF` and `repo`, `max_seq_len`, optional `quantization_type` (for example `fp8`), `tensor_parallel_count`, `num_builder_gpus`, plus `model_metadata.tags: [openai-compatible]`. Copy the current example from https://docs.baseten.co/examples/deploy-your-first-model rather than from here.

## Resources

- `resources.accelerator` plus `cpu` and `memory`, or `resources.instance_type` such as `"L4:4x16"` or `"H100:2"`. `node_count` enables multi-node. The list of types, GPUs and prices is in the resources page: https://docs.baseten.co/deployment/resources. Look prices up there.
- Size VRAM for weights plus KV cache before picking. See `self-hosted-llms` for sizing.

## Push

```bash
baseten model push --dir . --watch
baseten model push --dir . --environment production --watch
truss push . --promote          # truss equivalent
```

- A first build commonly takes 10 to 20 minutes. Image build time is billed.
- Dev deployments are fixed at 0 to 1 replicas and are for iteration, not traffic.
- Read logs: `baseten model deployment logs ...` and `baseten model environment logs ...` (see `--help`).

## Call it

Dedicated models get an ID. Endpoints:

| Purpose                          | URL                                                                                          |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| OpenAI-compatible                | `https://model-<id>.api.baseten.co/environments/production/sync/v1` then `/chat/completions` |
| Raw predict                      | `.../environments/production/predict`                                                        |
| Async                            | `.../async_predict`                                                                          |
| Wake a scaled-to-zero deployment | `POST .../deployment/<deployment-id>/wake`                                                   |

```bash
curl -sS "https://model-$MODEL_ID.api.baseten.co/environments/production/sync/v1/chat/completions" \
  -H "Authorization: Bearer $BASETEN_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"qwen","messages":[{"role":"user","content":"ping"}],"max_tokens":16}'
```

The `model` value must equal the `--served-model-name` of the server, or vLLM returns 404 "The model ... does not exist".

## Limits to know

- Edge request size is capped at 100 MB, async requests default to a smaller cap. Sync requests time out at the documented gateway timeout (see `references/troubleshooting.md`).
- A tier has a maximum number of deployed models. Cleanup old ones.

## Verify

- [ ] Build finished and a replica is healthy.
- [ ] The curl above returns a completion.
- [ ] A load test confirms the concurrency target before real traffic.
- [ ] Scaling bounds and a budget are set (`references/lifecycle-and-teardown.md`).
