---
name: nvidia-nim
description: Run and operate NVIDIA NIM for LLMs and VLMs, the prebuilt vLLM or SGLang containers from nvcr.io/nim (model-specific or model-free). Use to pull NIM images, choose model profiles, set NIM_* env vars, enable tool calling or LoRA, deploy with Docker, Helm or the NIM Operator, run air-gapped, multi-node or behind a gateway, and fix CUDA driver, OOM or timeout errors. Not for plain vLLM, Triton or Dynamo.
license: MIT
compatibility: Linux x86_64 or arm64 with an NVIDIA GPU, driver 580+, Docker 24+ with the NVIDIA Container Toolkit 1.14+, or Kubernetes 1.26+ with Helm 3. Needs bash, curl and jq. An NGC API key is only needed for gated or private images and models. Pulls, installs and cluster changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA NIM for LLMs and VLMs

Gets a NIM container serving an OpenAI-compatible API: a prebuilt image that wraps vLLM (or SGLang),
picks a validated model profile for your GPUs and downloads the weights. Verified against NIM LLM
2.0.13 (2026-10-11).

**Scope:** NIM for LLMs and VLMs only. The engine underneath is documented by `vllm` and `sglang`.
Datacenter orchestration is `nvidia-dynamo`; the KServe-style multi-framework server is
`triton-inference-server`. Other NIM families (embeddings, speech, and so on) are separate products with
their own docs.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv 2>/dev/null
nvidia-ctk --version 2>/dev/null; docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -o nvidia
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^nvcr.io/nim/' || true
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep 'nvcr.io/nim/' || true

# A running NIM
curl -s -m 3 -o /dev/null -w 'ready %{http_code}\n' http://127.0.0.1:8000/v1/health/ready
curl -s -m 3 http://127.0.0.1:8000/v1/models | jq '.data[].id'
curl -s -m 3 http://127.0.0.1:8000/v1/version
curl -s -m 3 http://127.0.0.1:8000/v1/metadata | jq 'keys'

# Which profiles fit this machine (replace the image; runs and exits)
docker run --rm --gpus=all <nim-image> list-model-profiles

# Kubernetes
helm list -A 2>/dev/null | grep -i nim
kubectl get nimcache,nimservice -A 2>/dev/null
```

## Decision flow

1. **Model-specific or model-free?** A model-specific image (`nvcr.io/nim/<org>/<model>:<tag>`) ships a
   curated manifest of profiles for that model. The model-free image (`nvcr.io/nim/nvidia/model-free-nim`)
   serves any architecture its backend supports from `hf://`, `ngc://`, `modelscope://`, S3 or a local
   directory. See `references/models-and-formats.md`.
2. **Check the fit.** Run `list-model-profiles`. Profiles are grouped as runnable, low-memory (with a hint
   such as `--max-model-len`) and incompatible. Do not guess the profile ID; copy it from the output.
3. **Start with Docker** (`references/install.md`), one GPU or one node, defaults, JSON logs off.
4. **Persist the cache.** Mount a host directory on `NIM_CACHE_PATH` so restarts do not redownload.
5. **Tune only after it serves**: `NIM_MAX_MODEL_LEN`, tensor parallel size, backend flags passed after
   `nim-serve` (`references/serve-config.md`, `references/performance-tuning.md`).
6. **Production on Kubernetes**: the `nim-llm` Helm chart or the NIM Operator (`NIMCache` plus
   `NIMService`). See `references/parallelism-multinode.md` and `references/install.md`.
7. **Put a gateway in front.** NIM documents no API-key setting for `/v1`; do not expose it directly
   (`references/integrations.md`).

## Quick start (one GPU)

```bash
# Optional login; most current public images pull without it. Key from a 0600 file, never echoed.
[ -n "${NGC_API_KEY:-}" ] && printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin

mkdir -p "$HOME/.cache/nim"
docker run -d --name nim --gpus all --shm-size=16g \
  -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/nim:/opt/nim/.cache" \
  -e NGC_API_KEY \
  nvcr.io/nim/meta/llama-3.1-8b-instruct:2.0.13
# first start downloads weights; wait for readiness
until curl -sf -m 3 http://127.0.0.1:8000/v1/health/ready >/dev/null; do sleep 10; done
curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[0].id'
```

Use the id from `/v1/models` as `model` in requests. Pull the exact image and tag for your model from the
Support Matrix, not from this example. `-e NGC_API_KEY` forwards the host variable without writing it on
the command line. Check the cache ownership if the container cannot write it (see troubleshooting).

## Rules

- **Pin the tag**; never `latest`. Match the Helm chart, image and Operator to the same release family.
- **Never print `NGC_API_KEY` or `HF_TOKEN`.** Forward with `-e NAME`, or use Kubernetes Secrets.
- **Bind to `127.0.0.1`** unless a gateway fronts it. There is no built-in API key.
- **Do not hand-build profile IDs.** Take the full ID or description from `list-model-profiles`.
- **Backend must match the image**: a vLLM image loads `vllm-*` profiles, an SGLang image `sglang-*`.
- **Use `--dry-run`** (`nim-serve --dry-run`) to preview the resolved configuration.
- **Multi-node: set `model.jsonLogging=false`**; the JSON formatter breaks Ray workers.
- **Persist and size the cache** for all profiles you may pull; air-gapped hosts need `download-to-cache`.

## Facts that surprise people

- Passing arguments after the image name forwards them to the backend (vLLM). `nim-serve` is the default
  action; other actions are `list-model-profiles`, `download-to-cache`, `download-model`,
  `create-model-store`, `nim-serve-ray`, `mirror` and `show-build-info`.
- `/v1/metrics` is plain vLLM Prometheus metrics, so existing vLLM dashboards work unchanged.
- Health lives at `/v1/health/live` and `/v1/health/ready`, not `/health`. `NIM_HEALTH_PORT` can move it.
- `NIM_LOG_LEVEL` defaults to `WARNING`; the backend has its own `VLLM_LOGGING_LEVEL`.
- Tool calling is off until you pass `--enable-auto-tool-choice` and a matching `--tool-call-parser`.
- NIM does not talk to MCP servers; the client converts MCP tools to OpenAI `tools`.
- A remote `NIM_MODEL_PATH` needs network and credentials on first start; mount the same cache later to
  reuse the generated manifest offline.
- Setting `NIM_PASSTHROUGH_ARGS` in Kubernetes replaces, not appends to, an image-provided value.
- Public images mostly pull keylessly, but Production Branch, pre-2.0.10, private and gated artifacts
  still need NGC credentials.
- Multi-node uses Ray plus vLLM or SGLang, and needs LeaderWorkerSet on Kubernetes.

## Workflows

**Serve a Hugging Face model with the model-free image**

1. Confirm the architecture is supported by the backend in the image; NIM adds no architecture support.
2. `docker run ... -e HF_TOKEN -e NIM_MODEL_PATH=hf://<org>/<model> <model-free-image>:<tag>`.
3. Read the served name from `/v1/models` (derived from the URI unless `NIM_SERVED_MODEL_NAME` is set).

**Enable tool calling**: append `nim-serve --enable-auto-tool-choice --tool-call-parser <parser>` to the
container args, then send `tools` on `/v1/chat/completions` (`references/features.md`).

**Air-gapped**: run `download-to-cache` (optionally with `-p <profile>`) on a connected host, move the
cache and the mirrored image, then start with the same `NIM_CACHE_PATH`. See `references/install.md`.

**Add LoRA**: set `NIM_PEFT_SOURCE` to a directory of adapters, one subdirectory each with
`adapter_config.json` and `adapter_model.safetensors`; pick a `-lora` profile (`references/features.md`).

**It will not start**: logs first (`docker logs nim`, raise `NIM_LOG_LEVEL=INFO`), then
`references/troubleshooting.md`.

## Reference index

- `references/install.md`: prerequisites, images, login, air-gap, Helm, NIM Operator.
- `references/serve-config.md`: `NIM_*` variables, CLI actions, passthrough arguments, TLS and CORS.
- `references/models-and-formats.md`: profiles, memory classes, model-free sources, derived names.
- `references/parallelism-multinode.md`: TP and PP, Ray, LeaderWorkerSet, NVL72 notes.
- `references/features.md`: tool calling, LoRA, speculative decoding, multimodal, structured output.
- `references/api.md`: endpoints, health, metadata, Anthropic and Responses APIs.
- `references/performance-tuning.md`: memory math, context length, benchmarking, tuning order.
- `references/integrations.md`: gateways, LiteLLM, SDKs, agents, cloud and Kubernetes ecosystem.
- `references/observability.md`: logs, metrics, scrape config, tracing headers.
- `references/updating.md`: upgrade procedure and cache handling.
- `references/troubleshooting.md`: symptom to cause to fix.
- `templates/`: `docker-compose.yml`, `helm-values.yaml`, `nim-operator.yaml`.

## Companion skills

From the same repo; install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `vllm`, `sglang`: the backends inside the image.
- `nvidia-dynamo`, `triton-inference-server`: the other NVIDIA serving products.
- `litellm`, `llm-gateway`: auth, keys and routing in front of NIM.
- `llm-observability`: traces and cost.
- `choosing-hardware`, `choosing-inference-engine`: sizing and engine choice.
