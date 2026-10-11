# NVIDIA Dynamo integrations

> Verified against Dynamo v1.5.1, 2026-10-11

- **LiteLLM / gateways**: the frontend is an OpenAI-compatible endpoint; register it as an `openai/<model>` upstream
  with `api_base: http://<frontend>:8000/v1`. Add auth, budgets and fallbacks at the gateway (`litellm`, `llm-gateway`
  skills). Declare tool and reasoning capability in the gateway: `/v1/models` does not report it.
- **Gateway API Inference Extension (GAIE)**: a Kubernetes Gateway calls the Dynamo Endpoint Picker Plugin (EPP), then
  forwards to the worker's Frontend sidecar in `--router-mode direct`. Use for multi-deployment, gateway-level auth,
  rate limits and observability. EPP metrics: `dynamo_epp_*` on `DYN_EPP_METRICS_PORT` (9090). Examples under
  `examples/backends/vllm/deploy/gaie/`. Dynamo-native routing (client to Frontend to Router) needs no gateway.
- **Claude Code / Anthropic clients**: `--enable-anthropic-api` on the frontend.
- **Agent frameworks**: LangChain (NVIDIA AI endpoints integration) and NeMo Agent Toolkit have Dynamo integrations.
- **Open WebUI and other OpenAI clients**: point at `http://<frontend>:8000/v1`.
- **Kubernetes ecosystem**: Grove and KAI Scheduler (gang and topology-aware scheduling), LeaderWorkerSet, Volcano,
  LMCache and storage-tier KV offload, Fluid/EFS/Lustre model caches, KEDA/HPA autoscaling with Prometheus, FluxCD.
- **Hosting**: AWS EKS and ECS, GKE, AKS guides in the repo docs.
- **Related skills**: `nvidia-nim` for packaged single-model containers, `triton-inference-server` for general serving.
