# NVIDIA Dynamo features

> Verified against Dynamo v1.5.1, 2026-10-11

Sources: README feature matrix, compatibility page, router and fault-tolerance guides.

| Feature                            |   SGLang    | TensorRT-LLM | vLLM |
| ---------------------------------- | :---------: | :----------: | :--: |
| Disaggregated serving              |     yes     |     yes      | yes  |
| KV-aware routing                   |     yes     |     yes      | yes  |
| SLA-based Planner                  |     yes     |     yes      | yes  |
| KVBM (GPU to CPU to SSD to remote) | in progress |     yes      | yes  |
| Multimodal                         |     yes     |     yes      | yes  |
| Tool calling                       |     yes     |     yes      | yes  |

vLLM has the broadest coverage (LoRA, request migration, image and video multimodal, audio experimental, speculative
decoding). Check the full feature matrix before combining features: interactions exist.

- **KV-aware routing**: score workers by KV overlap and load. Modes: events (default, workers publish cache events),
  prediction (`--no-router-kv-events`), load-only (`--load-aware`). Standalone router and indexer exist; the Gateway API
  EPP path runs the Frontend with `--router-mode direct`. `nvext.cache_salt` namespaces routing (and backend KV reuse on
  vLLM and TensorRT-LLM).
- **KVBM**: multi-tier KV offload. Storage-tier offload to S3/Azure blob and LMCache are documented for Kubernetes.
- **Planner**: SLA-driven autoscaler of prefill and decode pools. `sla` mode reads live TTFT/ITL from Prometheus
  (kube-prometheus-stack required); `throughput` mode can use internal queue signals.
- **Fault tolerance**: canary health checks, in-flight request migration (`--migration-limit`), graceful shutdown,
  request cancellation, load shedding (HTTP 529). Migration requires the request and engine to allow it.
- **Fast start**: ModelExpress streams weights GPU to GPU via NIXL; GPU Memory Service and snapshot options exist for
  recovery. Treat as advanced.
- **Agentic**: per-request `nvext.agent_hints` (priority, expected output length `osl`, speculative prefill), session
  metadata; Anthropic Messages API for Claude Code; LangChain and NeMo Agent Toolkit integrations.
- **LoRA**: dynamic adapters on vLLM (`examples/backends/vllm/deploy/lora/`, adapters from S3-compatible storage).
- **Multimodal**: encode/prefill/decode disaggregation with an embedding cache; video decode via PyNvVideoCodec.
- **Video generation**: FastVideo and SGLang Diffusion backends; vLLM-Omni for omni models.
- **Tools and reasoning**: parsing runs in the frontend (`--enable-streaming-tool-dispatch`,
  `--reasoning-field-name`). v1.5.1 omits absent optional response fields (for example `usage`) instead of `null`.
- **Simulation**: AISimulate/DynoSim and a mocker engine test routing and Planner without GPUs.
