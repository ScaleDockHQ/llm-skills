# Serverless GPU: RunPod Serverless and Modal

> Verified against runpod-workers/worker-vllm v2.29.0 README, RunPod Serverless endpoint configuration docs, runpodctl v2.15.0 README, Modal "Run OpenAI-compatible LLM inference with vLLM" example and cold-start guide, vLLM v0.31.0 Modal page, 2026-10-11

## What it is and when to choose it

You hand the platform a container (or a Python function on Modal); it runs on GPUs when requests arrive and scales down, optionally to zero, when they stop. You pay for active time plus any workers you keep warm.

Choose it for custom or fine-tuned models with spiky or low average traffic, async and batch jobs, and demos. Avoid it for interactive traffic that is sparse (users will hit cold starts) or for steady all-day load (a VM is cheaper).

## Install / setup

### RunPod Serverless with the vLLM worker

The official worker `runpod-workers/worker-vllm` wraps vLLM behind RunPod's queue-based Serverless API.

1. Create a Serverless endpoint from the pre-built worker image (the README's "Option 1", recommended), or build an image with the model baked in ("Option 2").
2. Configure with environment variables; the main ones:

| Variable                            | Meaning                                                      |
| ----------------------------------- | ------------------------------------------------------------ |
| `MODEL_NAME`                        | Hugging Face repo ID or local path of the weights            |
| `HF_TOKEN`                          | Token for gated or private models (store as a RunPod secret) |
| `MAX_MODEL_LEN`                     | Maximum context length (`--max-model-len`)                   |
| `GPU_MEMORY_UTILIZATION`            | Fraction of GPU memory for vLLM (default 0.9)                |
| `OPENAI_SERVED_MODEL_NAME_OVERRIDE` | Model name exposed on the API (`--served-model-name`)        |
| `MAX_CONCURRENCY`                   | Maximum concurrent requests per worker (default 30)          |

3. Endpoint scaling settings: **active workers** (always on; removes cold starts but bills continuously), **max workers**, **idle timeout** (how long an idle worker stays up), **FlashBoot** (faster cold starts by retaining state), and cached models.
4. Attach a network volume if you want the model cache to persist between workers (the worker's default `BASE_PATH` is `/runpod-volume`).

Alternative: a **load balancing** endpoint runs the official `vllm/vllm-openai:<version>` image as-is with direct HTTP (no job queue). Requests that arrive before any worker is ready return an error instead of waiting, so clients must retry through cold starts.

```bash
runpodctl serverless list            # existing endpoints
runpodctl serverless health <id>     # worker and job counts
runpodctl serverless logs <id>       # worker logs
```

### Modal

Modal is Python-native: the app, image and GPU are declared in a Python file and deployed with `modal deploy`. Templating it here would mean shipping Python, so use Modal's official, maintained example instead:

- Example: https://modal.com/docs/examples/vllm_inference ("Run OpenAI-compatible LLM inference with vLLM"), source in https://github.com/modal-labs/modal-examples.
- It runs `vllm serve` inside a Modal web server function, exposing OpenAI-compatible routes on a Modal URL.
- Knobs used in that example include `scaledown_window` (how long a container stays up with no requests); Modal's cold-start guide covers keeping containers warm and GPU memory snapshots.

## Minimal working config

Gateway entries:

```yaml
model_list:
  # RunPod Serverless, queue-based vLLM worker
  - model_name: custom-model
    litellm_params:
      model: openai/<served-model-name>
      api_base: https://api.runpod.ai/v2/<endpoint-id>/openai/v1
      api_key: os.environ/RUNPOD_API_KEY
  # Modal web endpoint running vLLM
  - model_name: custom-model-modal
    litellm_params:
      model: openai/<served-model-name>
      api_base: https://<your-modal-app-url>/v1
      api_key: os.environ/MODAL_VLLM_API_KEY
```

The Modal URL and its auth depend on how the app is written; follow the example's client section.

## How it plugs into the stack

- RunPod queue endpoint: OpenAI-compatible routes under `https://api.runpod.ai/v2/<endpoint-id>/openai/v1` (Chat Completions, models, Responses), and the Anthropic Messages API at `.../openai/v1/messages`. Auth with the RunPod API key.
- RunPod load-balancing endpoint: `https://<endpoint-id>.api.runpod.ai/v1/...` straight to vLLM.
- Modal: whatever routes vLLM serves, on the app's URL.
- Health: platform worker status (`runpodctl serverless health`); vLLM `/health` where the route is exposed.

## Operating

- **Cold starts** = container start + weight download or load + engine warm-up (CUDA graph capture, compilation). Shrink them with cached weights (network volume, baked image, platform model caching), smaller or quantized models, and FlashBoot or GPU snapshots.
- **Keeping warm** (active workers, minimum containers) trades cost for latency. Price it as an always-on VM (`cost-and-quotas.md`).
- **Gateway timeouts** must exceed worst-case cold start, or the gateway should fall back to another deployment quickly. Decide which.
- **Startup failures**: the worker README notes that some failures cannot be fixed by restarting (model does not fit, `MAX_MODEL_LEN` larger than the KV cache, rejected flag, gated model without `HF_TOKEN`); read worker logs instead of watching silent restarts.

## Tuning knobs worth knowing

- RunPod: active workers, max workers, idle timeout, FlashBoot, GPU type priority, `MAX_CONCURRENCY`, `MAX_MODEL_LEN`, `GPU_MEMORY_UTILIZATION`.
- Modal: `scaledown_window`, minimum containers, GPU type, concurrency per container, snapshots.

## Known pitfalls

- Scale to zero on an interactive alias with no fallback: the first user after a quiet period waits for the cold start.
- Load-balancing endpoints have no queue: requests during cold start fail rather than wait.
- Weights not cached: every new worker downloads the model.
- Pinning `latest` images; pin the vLLM version tag.

## Official links

- RunPod vLLM worker: https://github.com/runpod-workers/worker-vllm
- RunPod Serverless vLLM overview: https://docs.runpod.io/serverless/vllm/overview
- RunPod endpoint configuration: https://docs.runpod.io/serverless/endpoints/endpoint-configurations
- RunPod load balancing endpoints: https://docs.runpod.io/serverless/load-balancing/overview
- runpodctl: https://github.com/runpod/runpodctl
- Modal vLLM example: https://modal.com/docs/examples/vllm_inference
- Modal cold starts: https://modal.com/docs/guide/cold-start
- Modal examples repo: https://github.com/modal-labs/modal-examples
- vLLM on Modal: https://docs.vllm.ai/en/latest/deployment/frameworks/modal/
