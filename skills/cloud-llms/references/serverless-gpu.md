# Serverless GPU: RunPod Serverless and Modal

> Verified against runpod-workers/worker-vllm v2.29.0 README, runpodctl v2.15.0 README, Modal "Run OpenAI-compatible LLM inference with vLLM" example and cold-start guide, 2026-10-11

You hand the platform a container (or Python function on Modal); it runs on GPUs when requests arrive and scales down, optionally to zero. Choose it for custom models with spiky traffic, batch jobs and demos; avoid it for sparse interactive traffic (cold starts) and steady all-day load.

Depth: install the `runpod` skill (`npx skills add ScaleDockHQ/llms-skills --skill runpod`), the `modal` skill (`npx skills add ScaleDockHQ/llms-skills --skill modal`), and for managed dedicated deployments the `baseten` skill (`npx skills add ScaleDockHQ/llms-skills --skill baseten`).

## How it plugs into this stack

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

- RunPod load-balancing endpoints (`https://<endpoint-id>.api.runpod.ai/v1/...`) have no queue: requests during a cold start fail, so the gateway needs retries.
- Gateway timeouts must exceed the worst-case cold start, or the gateway should fall back quickly. Decide which.
- Scale to zero only on aliases with a fallback or tolerant clients. Keeping workers warm is priced like an always-on VM (`cost-and-quotas.md`).
- Pin the vLLM version tag; cache weights so new workers do not re-download.
- Read worker logs on startup failures instead of watching restarts.
- Modal Servers do not queue: with no running container they return 503 until one starts, so set `num_retries` and a long `timeout` on the gateway entry. Modal web functions are public unless `requires_proxy_auth=True`; `modal app stop` is permanent.

## Official links

- RunPod vLLM worker: https://github.com/runpod-workers/worker-vllm
- Modal vLLM example: https://modal.com/docs/examples/vllm_inference
