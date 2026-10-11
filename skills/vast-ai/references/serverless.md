# Vast.ai Serverless: endpoints, workergroups and the OpenAI proxy

> Verified against docs.vast.ai guides/serverless (quickstart, setting-up-endpoints, pricing), cli/reference (create-endpoint, create-workergroup, delete-endpoint), vastai CLI and vastai-sdk 1.8.3, docs.vast.ai/llms.txt, 2026-10-11

Vast Serverless autoscales pools of rented GPU workers behind a routing endpoint. It is cheaper but less polished than hosted APIs, and workers are rented marketplace machines. Test with a small cap first.

## Concepts

- **Endpoint**: the scaling controller and routing name.
- **Workergroup**: the recipe for workers (template or launch args, plus the GPU search filter). One endpoint can have several workergroups.
- **Template**: for LLMs use **vLLM (Serverless)**, which defaults to `Qwen/Qwen3-8B` and exposes OpenAI-compatible routes. It reads `MODEL_NAME`, `VLLM_ARGS` and `HF_TOKEN`.

## Create (approval first)

Workers bill like rented instances once they run, so state the GPU filter, `max_workers`, `min_workers` and `cold` settings, and get a yes.

Console: **Serverless -> + Endpoint** (or the quickstart modal; "Advanced setup" gives full parameters), then pick the vLLM (Serverless) template and a GPU.

CLI (see `vastai create endpoint --help` and `vastai create workergroup --help`):

```bash
vastai create endpoint --endpoint_name "my-llm" --target_util 0.9 --cold_mult 2.0   # plus worker-count and timeout flags: see --help
vastai create workergroup --endpoint_name "my-llm" --template_hash <vllm-serverless-template-hash>
vastai show endpoints
vastai show workergroups
```

The docs examples confirm `--endpoint_name`, `--target_util`, `--cold_mult` (endpoint) and `--template_hash`, `--endpoint_name` (workergroup). The workergroup reference also describes a template id, an endpoint id, a GPU RAM estimate, a search-parameter string, a launch-args string and a flag that disables default search params; confirm their spellings with `vastai create workergroup --help`. The endpoint options for minimum load, cold load, cold workers, max workers, queue times and inactivity timeout exist, but their exact flag spellings were not visible in the fetched reference. Read them from `vastai create endpoint --help` before use, or set them in the console.

### Endpoint parameters (console defaults)

| Parameter          | Default           | Meaning                                                   |
| ------------------ | ----------------- | --------------------------------------------------------- |
| Minimum workers    | 5                 | Total workers (active plus inactive) kept by the engine   |
| Max workers        | 16                | Hard cap; **your spend ceiling** (the CLI help lists 20)  |
| Minimum load       | 1                 | Keeps at least one worker active                          |
| Target utilization | 0.9               | Active capacity vs expected load; lower leaves headroom   |
| Cold multiplier    | 3 (CLI help: 2.5) | Inactive capacity as a multiple of active load            |
| Minimum cold load  | 0                 | Cold capacity floor                                       |
| Max queue time     | 30 s              | Per-worker expected queue before routing holds            |
| Target queue time  | 10 s              | Triggers aggressive scale-up                              |
| Inactivity timeout | not set           | Seconds of no traffic before scale to zero active workers |

The defaults keep several workers (and storage) alive. Lower **Minimum workers** and **Max workers** for a test, and set an **Inactivity timeout** so it can go cold.

### Worker states and billing

| Worker state                                | Billing        |
| ------------------------------------------- | -------------- |
| Ready, Loading                              | GPU billed     |
| Creating                                    | No GPU billing |
| Inactive (cold, "Stopped" in the dashboard) | Storage only   |

| Endpoint state     | Billing                         |
| ------------------ | ------------------------------- |
| Active             | Workers per above               |
| Suspended, Stopped | Some storage still bills        |
| Destroyed          | **Only this stops all billing** |

First deploy takes about 3 to 5 minutes (instance start, model download, load into VRAM, health checks); large models take longer. Watch the worker logs (eye icon in the dashboard). A worker stuck in **Loading** usually means a gated model without `HF_TOKEN`; set `HF_TOKEN` as an account env var.

## Calling the endpoint

### OpenAI-compatible proxy

```bash
export VAST_OPENAI_URL="https://openai.vast.ai/<ENDPOINT_NAME>"   # documented base; OpenAI SDK users may need a /v1 suffix (see litellm-and-clients.md)
export OPENAI_API_KEY="$(cat ~/.config/vastai/vast_api_key)"        # the Vast API key
curl -s "$VAST_OPENAI_URL/v1/chat/completions" -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"any","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq -r '.choices[0].message.content'
```

Proxy limits: only `/v1/chat/completions` and `/v1/completions` (streaming works); the `model` field is ignored (the worker's model answers); no vision, audio, image generation or embeddings; `parallel_tool_calls` is unsupported. Use a scoped key (`misc` permission) instead of a full-access key. A Vast API key as the bearer means whoever holds it can spend your credits.

### Python SDK (routing with cost hints)

```python
import os
from vastai import Serverless

client = Serverless(api_key=os.environ["VAST_API_KEY"])   # package vastai-sdk; check its README for the current constructor
endpoint = client.get_endpoint("my-llm")                   # method names: verify in the SDK docs for your version
payload = {"model": "Qwen/Qwen3-8B", "prompt": "Hello", "max_tokens": 64}
resp = endpoint.request("/v1/completions", payload, cost=64)   # cost = expected work units (max tokens for LLMs)
```

The SDK holds and retries requests until workers are ready. For plain HTTP clients, expect the first request after idle to wait for a cold worker.

## Scale and tune

- Raise or lower **Max workers** and **Minimum workers** first. Use **Target utilization** (lower means more headroom) and **Cold multiplier** to trade cost for cold-start speed.
- Edit live endpoints in the dashboard (pencil icon); changes apply immediately.
- Keep a fallback in your gateway for a worker pool that is empty or loading.
