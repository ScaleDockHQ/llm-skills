# SGLang: integrations

> Verified against SGLang v0.5.21 (docs: basic_usage/{openai_api,anthropic_api,ollama_api,aws_sagemaker}, get-started/install; llama-swap and LiteLLM entries carried over from this repo's `self-hosted-llms` engine notes, not re-checked against those projects' current docs), 2026-10-11

## llama-swap (several models, one endpoint)

SGLang is one model per process with a slow cold start, so run it as an exclusive llama-swap group (it should not share GPU memory with another resident engine). Skill: `llama-swap` (install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`); host layout in `self-hosted-llms`.

```yaml
models:
  gpt-oss:
    cmd: /opt/llm-stack/start-model.sh run gpt-oss ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop gpt-oss
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    ttl: 0
    unloadTimeout: 60
    capabilities:
      tools: true # set by hand; only claim it when --tool-call-parser is passed
```

The wrapper maps `${PORT}` on 127.0.0.1 to container port 30000. Use `/health` (not `/health_generate`) as `checkEndpoint`. The raw engine stays reachable through llama-swap's upstream route, for example `curl -s http://127.0.0.1:8080/upstream/gpt-oss/server_info`. Docker wrapper example in `combos/dgx-spark.md`.

## LiteLLM gateway

```yaml
model_list:
  - model_name: gpt-oss
    litellm_params:
      model: openai/gpt-oss # openai/ prefix = generic OpenAI-compatible backend
      api_base: http://127.0.0.1:8080/v1 # llama-swap, or http://127.0.0.1:30000/v1 for SGLang directly
      api_key: os.environ/LLAMA_SWAP_API_KEY
```

Keep SGLang itself keyless on loopback and let LiteLLM own keys, or set `--api-key` and pass it as `api_key: os.environ/SGLANG_API_KEY`. The `model` after `openai/` must equal `--served-model-name`. Skill: `litellm`.

## Claude Code and Anthropic-SDK clients

SGLang serves `POST /v1/messages` with no extra flag. Per upstream:

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:30000"
export ANTHROPIC_AUTH_TOKEN="dummy"            # any non-empty string unless --api-key is set (then the real key, from a 0600 file)
export CLAUDE_CODE_ATTRIBUTION_HEADER=0        # required for prefix-cache reuse
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export ANTHROPIC_DEFAULT_SONNET_MODEL="<served-model-name>"   # also HAIKU / OPUS
```

Launch the server with `--tool-call-parser` (and `--reasoning-parser` for thinking models) so `tool_use` blocks are structured. Append `[1m]` to the client-side model name only for models with 1M context. Context defaults to the model's own; cap with `--context-length`.

## Ollama clients

`OLLAMA_HOST=http://127.0.0.1:30000 ollama run "<exact --model name>"`; endpoints `/api/tags`, `/api/chat`, `/api/generate`, `/api/show`. Useful for tools that only speak Ollama.

## OpenAI SDK, LangChain, LlamaIndex, Open WebUI and similar

Point the client at `http://127.0.0.1:30000/v1` with any key (or the real key if `--api-key` is set). Streaming, `tools`, `response_format`, embeddings and vision work through the OpenAI schema. Reasoning text arrives in `reasoning_content` when `--reasoning-parser` is set and the request asks for it (see `features.md`); clients that ignore that field will show only the answer.

## Router / model gateway (SGLang's own)

`sglang-router` (`python -m sglang_router.launch_router`) does cache-aware DP routing, PD routing, gRPC workers and an OpenAI/MCP proxy; see `parallelism-multinode.md`. For auth, rate limits and budgets use LiteLLM in front.

## Containers and platforms

- Docker Compose: `templates/docker-compose.yml`. systemd: `templates/sglang.service`. Kubernetes: `templates/k8s-deployment.yaml` (upstream `docker/k8s-sglang-service.yaml`; OME operator for fleets).
- SkyPilot: `image_id: docker:lmsysorg/sglang:<pinned tag>`, `ports: 30000`; `sky launch -c sglang --env HF_TOKEN sglang.yaml`; `sky status --endpoint 30000 sglang`.
- AWS SageMaker: container from `docker/sagemaker.Dockerfile` + `docker/serve`; `SM_SGLANG_*` env vars become flags, e.g. `SM_SGLANG_MODEL_PATH=Qwen/Qwen3-0.6B`, `SM_SGLANG_REASONING_PARSER=qwen3`; default port 8080; AWS also publishes SGLang Deep Learning Containers.
- Tunnels and remote access: keep SGLang on loopback and expose the gateway through `cloudflare-tunnel` or `tailscale` skills, never the engine port directly.

## RL and training loops

SGLang is used as a rollout engine (weight update endpoints, `--enable-memory-saver`, `release_memory_occupation`/`resume_memory_occupation`, `--rl-on-policy-target`, checkpoint-engine). These are admin-class operations; see the upstream `sglang_for_rl` and `post_training_integration` pages. Out of scope here.
