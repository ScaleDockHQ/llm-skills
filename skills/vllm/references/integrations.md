# Integrations: routers, gateways, UIs, coding agents, Kubernetes

> Verified against vLLM v0.31.0 (docs `deployment/**`, `serving/integrations/*`), 2026-10-11

## Rules that apply everywhere

- `--served-model-name` is the ID clients send. Set it explicitly and use the same name in every router.
- `GET /v1/models` does not say whether tools or reasoning are enabled. Declare capabilities by hand in the
  router or client.
- vLLM `--api-key` guards `/v1` only. Prefer loopback plus a gateway that holds keys.
- Cold start is slow. Raise router and probe timeouts above the measured start time.

## LiteLLM (skill `litellm`)

Use the `hosted_vllm/` prefix (upstream calls it necessary) when pointing LiteLLM straight at vLLM:

```yaml
model_list:
  - model_name: qwen-coder
    litellm_params:
      model: hosted_vllm/qwen-coder # prefix plus the --served-model-name
      api_base: http://127.0.0.1:8000/v1
      api_key: os.environ/VLLM_API_KEY # any non-empty placeholder if vLLM has no --api-key
```

Behind llama-swap, point `api_base` at llama-swap's port and use the `openai/<id>` form instead
(see `combos/dgx-spark-dual-ray.md`). Embeddings work through the same prefix.

## llama-swap (skill `llama-swap`)

llama-swap starts one vLLM per model on demand. Its entry needs `proxy`, `checkEndpoint: /health`, a `cmdStop`
for containers (stopping `docker run` needs an explicit stop), a long `healthCheckTimeout`, and
`capabilities.tools: true` set by hand for tool-capable models. A complete DGX Spark wrapper
(`models.d` script plus YAML entry) is in `combos/dgx-spark-dual-ray.md`.

## Open WebUI

`docker run ... -e OPENAI_API_BASE_URL=http://<host>:8000/v1 ...` (upstream `open-webui.md`). With
`--api-key` on vLLM also provide the key through Open WebUI's connection settings or environment, read from a
`0600` file, not typed into shell history.

## Coding agents

- **Claude Code** speaks the Anthropic Messages API, which vLLM implements. Launch with
  `ANTHROPIC_BASE_URL=http://localhost:8000`, `ANTHROPIC_AUTH_TOKEN` (required, any value without `--api-key`),
  and `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL=<served-model-name>`. Serve a model with tool calling:
  `--enable-auto-tool-choice --tool-call-parser <name>`. Older vLLM (0.17.1 and earlier) needs
  `"CLAUDE_CODE_ATTRIBUTION_HEADER": "0"` in the `env` of `~/.claude/settings.json`, because a per-request hash
  in the system prompt defeats prefix caching.
- **Codex CLI**: `~/.codex/config.toml` with `base_url = "http://localhost:8000/v1"` and
  `wire_api = "responses"`; `model` must equal the served model name.
- Other tool-using clients (Continue, Cline, OpenCode, ...) use `/v1/chat/completions` with tool parsers; see
  `features.md` for the parser per model.

## Frameworks (upstream docs under `deployment/frameworks` and `serving/integrations`)

LangChain, LlamaIndex, Haystack, AutoGen, Dify, Chatbox, LobeChat, AnythingLLM, Streamlit, Triton, BentoML,
SkyPilot, dstack, and hosted runners (Modal, RunPod, Nebius, Anyscale, Cerebrium, Crusoe, HF Inference
Endpoints) all have upstream pages. They were not tested by this skill; read the upstream page for the
exact settings.

## Kubernetes

- Upstream guide: `docs/deployment/k8s.md` (Deployment + Service + PVC for the HF cache + `/dev/shm`
  emptyDir with `medium: Memory` + `nvidia.com/gpu` limits). Use `templates/k8s-deployment.yaml`.
- Probe `GET /health`. Give `startupProbe` or large `failureThreshold` for slow starts; otherwise kubelet kills
  healthy starts (symptom: `KeyboardInterrupt: terminated` in the log and `failed startup probe` events).
- Multi-node on K8s: KubeRay (`deployment/integrations/kuberay.md`) or LeaderWorkerSet (`frameworks/lws.md`).
- Higher-level stacks documented upstream: Production Stack (Helm), llm-d, Dynamo, AIBrix, KServe, KubeAI,
  KAITO, Kthena, llmaz, Llama Stack. Pick one only when you need fleet routing, autoscaling or disaggregated
  prefill; a plain Deployment is enough for one model.
- Nginx load balancing across replicas: `docs/deployment/nginx.md`.

## Other skills

- `llm-gateway` for gateway choice, `llm-clients` for pointing tools at an endpoint,
  `llm-observability` for traces and cost, `self-hosted-llms` for the wider server stack.
  Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.
