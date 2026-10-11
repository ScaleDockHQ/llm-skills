# Features

> Verified against production-stack chart vllm-stack 0.1.13 and router (tutorials, helm templates, src/vllm_router), 2026-10-11

All keys live under `servingEngineSpec.modelSpec[]` unless noted. Tutorial values files are in
`tutorials/assets/` of the repo at the `vllm-stack-0.1.13` tag.

## LMCache CPU offload (tutorial 05)

```yaml
- name: mistral
  repository: lmcache/vllm-openai
  tag: v0.5.5 # pin a tag you tested
  modelURL: mistralai/Mistral-7B-Instruct-v0.2
  requestMemory: 40Gi # host RAM must cover the buffer
  lmcacheConfig: { enabled: true, cpuOffloadingBufferSize: "20" } # GB
```

Remote shared cache (tutorial 06): enable `cacheserverSpec` and point engines at it; storage backends are covered
by skill `kv-cache-offloading`.

## Several models (tutorial 04)

Add more `modelSpec` entries with unique `name`; the router routes by the `model` field in the request.

## LoRA (tutorial 09)

`enableLoRA: true`, `vllmConfig.maxLoras`, and either `loraAdapters:` (top level, managed by the lora controller:
`loraController`, `enableLoraController: true`) or the operator's `LoraAdapter` CRD. Adapter sources: Hugging Face,
local, S3, with `credentials` as a Secret reference.

## Tool calling (tutorial 13)

`enableTool: true`, `toolCallParser: "llama3_json"` (pick the parser for your model with skill `vllm`), and a
`chatTemplate` path when the model needs one (the tutorial mounts `/templates/tool_chat_template_llama3.1_json.jinja`).

## API key (tutorial 11)

Set `servingEngineSpec.vllmApiKey` as `{secretName, secretKey}`; the engines read `VLLM_API_KEY`. Clients then send
`Authorization: Bearer <key>` to the router, which forwards it to engines. The router itself has `routerSpec.vllmApiKey`.

## Sleep mode (tutorial 19)

Engines with `--enable-sleep-mode` plus `VLLM_SERVER_DEV_MODE=1` can be put to sleep and woken through the router
(`POST /sleep`, `POST /wake_up`, `GET /is_sleeping`); the router skips sleeping engines. Use it to time-share GPUs
between models.

## Pipeline parallel with Ray (tutorial 15)

`raySpec` in a modelSpec deploys a Ray cluster (`ray-cluster.yaml`) instead of a Deployment; needs the KubeRay
operator (`tutorials/00-b-install-kuberay-operator.md`). Per-model KEDA is not rendered for `raySpec` models.

## Other

- **Embeddings and rerank:** `vllmConfig.runner: pooling` and `convert: embed|classify|score`.
- **Whisper transcription** (tutorial 23), **semantic router** (24), **V100 / legacy GPUs** (25).
- **Distributed tracing** (12): `routerSpec.otel` plus engine OTEL env vars.
- **Ingress / Gateway API** (22): `routerSpec.ingress` or `routerSpec.route`. **Inference Extension** (21): the stack
  can sit behind a Gateway API Inference Extension picker (skill `gateway-api-inference-extension`).
- **Shared model storage:** `sharedPvcStorage` (RWX) so replicas share one download.
- **Extra manifests:** `extraObjects` renders arbitrary YAML with the release.

## Sources

- <https://github.com/vllm-project/production-stack/tree/vllm-stack-0.1.13/tutorials>
