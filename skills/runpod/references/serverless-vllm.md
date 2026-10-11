# Runpod Serverless: vLLM endpoints

> Verified against runpod-workers/worker-vllm v2.29.0 (vLLM 0.31.0) README, docs.runpod.io serverless/overview, serverless/endpoints/endpoint-configurations, serverless/load-balancing/overview, serverless/vllm/get-started, serverless/vllm/vllm-requests, runpodctl v2.15.0 (serverless, hub, template references), 2026-10-11

## Which endpoint type

| Type           | URL                                 | Behavior                                                                                                                                            | Use for                                                 |
| -------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Queue-based    | `https://api.runpod.ai/v2/<id>/...` | Jobs queue, workers scale on queue delay or request count, `/run`, `/runsync`, `/status`, `/stream`, `/cancel`, `/retry`, `/purge-queue`, `/health` | Default for LLMs; worker-vllm; OpenAI-compatible routes |
| Load balancing | `https://<id>.api.runpod.ai/<path>` | No queue, requests go straight to a worker's HTTP server                                                                                            | Own FastAPI or `vllm serve` server, lowest latency      |

## Option A: worker-vllm (recommended)

Image: `runpod/worker-v1-vllm:<version>`. Pin a release tag from https://github.com/runpod-workers/worker-vllm/releases (latest verified: `v2.29.0`, bundling vLLM `0.31.0`). Do not deploy `:latest`.

Create it from the Hub, the console (**Serverless -> New Endpoint -> vLLM**) or the CLI:

```bash
runpodctl hub --help                                        # hub subcommands (listing ids for --hub-id); not verified here
runpodctl template create --serverless --name vllm-qwen \
  --image runpod/worker-v1-vllm:<version> \
  --env '{"MODEL_NAME":"Qwen/Qwen3-8B","MAX_MODEL_LEN":"8192"}'
runpodctl serverless create --name vllm-qwen --template-id <template-id> \
  --gpu-id "NVIDIA GeForce RTX 4090" --workers-min 0 --workers-max 2
```

Verified `serverless create` flags: `--template-id`, `--hub-id`, `--gpu-id`, `--name`, `--env`, `--model-reference`, `--workers-min`, `--workers-max`. A Serverless template binds to one endpoint, so create one template per endpoint. `serverless update` is verified only for `--workers-max`; use `--help` for others. Set `--workers-min 0` and a low `--workers-max` to cap spend.

### worker-vllm environment variables

Most `vllm serve` flags map to an uppercase variable (`--max-model-len` -> `MAX_MODEL_LEN`). Common ones:

| Variable                                         | Purpose                                            | Default          |
| ------------------------------------------------ | -------------------------------------------------- | ---------------- |
| `MODEL_NAME`                                     | Hugging Face repo id or path                       | none, required   |
| `HF_TOKEN`                                       | Token for gated models (use a Runpod secret)       | unset            |
| `MAX_MODEL_LEN`                                  | Context length; too large causes a startup failure | model default    |
| `GPU_MEMORY_UTILIZATION`                         | VRAM fraction                                      | `0.9`            |
| `MAX_CONCURRENCY`                                | Concurrent requests per worker                     | `30`             |
| `OPENAI_SERVED_MODEL_NAME_OVERRIDE`              | The `model` name clients send                      | `MODEL_NAME`     |
| `ENABLE_AUTO_TOOL_CHOICE` and `TOOL_CALL_PARSER` | Tool calling (see `tool-calling-parsers` skill)    | off              |
| `CUSTOM_CHAT_TEMPLATE`                           | Override the chat template                         | unset            |
| `VLLM_EXTRA_ARGS`                                | Free-form extra `vllm serve` args                  | unset            |
| `VLLM_CONFIG_FILE`                               | Path to a vLLM YAML config                         | unset            |
| `BASE_PATH`                                      | Model and cache root                               | `/runpod-volume` |

For quantized checkpoints set the quantization variable and a matching model; the engine rules live in the `vllm` and `model-quantization` skills.

If the model cannot start for a reason retries will not fix (out of memory, gated model without `HF_TOKEN`, `MAX_MODEL_LEN` larger than the KV cache allows), the worker answers jobs with a JSON `startup_error` instead of crash-looping. Read it in `runpodctl serverless logs <id>` or in the job output.

## Option B: vLLM as a load-balancing endpoint

Use the stock `vllm/vllm-openai:<pinned-version>` image on a load-balancing endpoint:

- Environment: `PORT=8000`, `HF_TOKEN` (secret), plus `--model` through the container command or template.
- Expose `8000/http`.
- Health: workers must answer `GET /ping` (`200` ready, `204` still initializing). Override with `PORT_HEALTH` and `HEALTH_CHECK_PATH` when the server uses another path (vLLM serves `/health`).
- Call it at `https://<ENDPOINT_ID>.api.runpod.ai/v1/chat/completions` with `Authorization: Bearer $RUNPOD_API_KEY`.
- No queue: while no worker is ready you get `no workers available`; clients must retry with backoff. Limits: 2 minutes to get a worker, 5.5 minutes of processing per request, 30 MB payload.
- If `PORT` does not match the exposed port, workers stay alive for about 8 minutes and answer `502`.

## Endpoint settings that decide cost

| Setting              | Default                    | Meaning                                                         |
| -------------------- | -------------------------- | --------------------------------------------------------------- |
| Active (min) workers | 0                          | Always-on workers, billed while they run; 0 means scale to zero |
| Max workers          | 3                          | Hard cap on concurrent workers; the main spend cap              |
| Idle timeout         | 5 s                        | How long a worker stays up after finishing work                 |
| Execution timeout    | 600 s                      | Per-job limit                                                   |
| Job TTL              | 24 h                       | Queue retention                                                 |
| FlashBoot            | on                         | Faster cold starts for recently used workers                    |
| Scaler               | queue delay, 4 s threshold | Alternative: request count                                      |

Runpod lowers `max workers` automatically after a long idle stretch: to 2 after 3 days with no requests and to 0 after 7 days, so a forgotten endpoint costs nothing but also fails after a week. Raise the cap again before relying on it. Unhealthy workers also reduce the cap.

## Cached models

Set the endpoint's **Model** (CLI: `--model-reference`) to a Hugging Face repo so Runpod places weights on hosts ahead of time; the download time is not billed. One cached model per endpoint, stored under `/runpod-volume/huggingface-cache/hub/`. Use it for faster cold starts instead of baking weights into images. Gated models still need a token.

## Scale and monitor

```bash
runpodctl serverless list
runpodctl serverless get <id>
runpodctl serverless health <id>                       # workers ready/running/idle and queue depth
runpodctl serverless logs <id> [--worker <worker-id>]
runpodctl serverless update <id> --workers-max 4
```

Invoke from the CLI for a smoke test: `runpodctl serverless run <id> --input '{"input":{"prompt":"hi"}}' --wait` (`--input-file`, `--no-wait` and `runpodctl serverless status <id> <job-id>` also exist). Calling `/openai/v1/...` is the normal path for LLM traffic; see `litellm-and-clients.md`.

## Flash and Public Endpoints

- **Flash** (`pip install runpod-flash`, `flash login`, `@Endpoint(...)` decorator, `flash undeploy`) deploys Python functions to Serverless without writing a Dockerfile. Verify its current CLI with the Runpod docs before use.
- **Public Endpoints** are prebuilt hosted models called at `https://api.runpod.ai/v2/<model-name>/runsync`. Billing is per call or output unit, not per worker. Use them when you do not need to host a model yourself.
