---
name: ray-serve
description: Serve LLMs on a Ray cluster with Ray Serve LLM (ray.serve.llm, LLMConfig, build_openai_app, `serve run|deploy|status`, rayproject/ray-llm) and run it on Kubernetes with KubeRay (RayService, RayCluster). Use for vLLM replicas with autoscaling, tensor/pipeline/data parallel, prefill/decode, prefix- or KV-aware routing, multi-LoRA, Prometheus metrics, zero-downtime upgrades, head-node fault tolerance. Fixes pending replicas, gated model 401, slow downloads, NIXL libcudart. Not for plain vLLM (vllm), llm-d, or KEDA.
license: MIT
compatibility: Linux with NVIDIA GPUs (Python 3.12 images), Docker or a Kubernetes cluster with the GPU operator, bash, curl, jq, kubectl and helm for KubeRay. Installs, cluster changes and exposure need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Ray Serve (LLM)

Gets an OpenAI-compatible LLM endpoint running on Ray Serve, scaled across replicas and nodes, observable, and
upgradable, on a plain Ray cluster or on Kubernetes through KubeRay. Verified against Ray 2.59.0 and KubeRay
v1.7.1 (2026-10-11).

**Scope:** Ray Serve LLM (`ray.serve.llm`) with vLLM as the engine, plus the KubeRay operator that runs it.
Engine flags themselves belong to the `vllm` skill; llm-d, the inference gateway and autoscaling by KEDA are
sibling skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
# Local Ray
command -v ray serve && ray --version
python3 -c "import ray, vllm; print(ray.__version__, vllm.__version__)" 2>&1 | tail -1
ray status 2>&1 | head -30                       # nodes, GPUs, pending demands
serve status 2>&1 | head -40                     # applications and replica states
curl -s -m 3 http://127.0.0.1:8265/api/version   # dashboard / jobs API
curl -s -m 3 http://127.0.0.1:8000/v1/models | jq '.data[].id'

# Hardware
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv 2>/dev/null

# Kubernetes
kubectl get crd | grep -E 'ray.io' ; helm list -A | grep -i kuberay
kubectl get rayservice,raycluster -A 2>/dev/null
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
```

## Decision flow

1. **One model, one box, no Ray needed?** Use the `vllm` skill. Ray Serve earns its place when you want
   several replicas with request-level autoscaling, cross-node TP/PP, DP attention for MoE, custom routing,
   or you already run Ray.
2. **No Ray yet** -> `references/install.md`: `pip install "ray[llm]"` or the `rayproject/ray-llm` image.
3. **Write one `LLMConfig` per model** (`references/serve-config.md`, `templates/serve-config.yaml`):
   `model_loading_config`, `accelerator_type`, `engine_kwargs`, `deployment_config.autoscaling_config`.
4. **Model larger than one GPU?** `engine_kwargs.tensor_parallel_size` (and `pipeline_parallel_size` across
   nodes), placement groups: `references/parallelism-multinode.md`.
5. **Kubernetes?** Install KubeRay and apply a `RayService`: `references/kubernetes-kuberay.md`,
   `templates/rayservice-llm.yaml`.
6. **Traffic shape**: shared prompts -> prefix/KV-aware routing; many adapters -> multi-LoRA; separate
   prefill and decode -> `build_pd_openai_app`: `references/features.md`.
7. **Scale and tune**: `target_ongoing_requests`, `max_ongoing_requests`, delays, scale to zero:
   `references/scaling-and-tuning.md`.
8. **Observe**: `references/observability.md`. **Upgrade**: `references/updating.md`.
9. **Broken**: `references/troubleshooting.md`.

## Quick start (single node)

```bash
pip install "ray[llm]"
cat > config.yaml <<'YAML'
applications:
- name: llm_app
  route_prefix: "/"
  import_path: ray.serve.llm:build_openai_app
  args:
    llm_configs:
    - model_loading_config:
        model_id: qwen-0.5b
        model_source: Qwen/Qwen2.5-0.5B-Instruct
      accelerator_type: A10G        # set to the GPU you have (see references/serve-config.md)
      deployment_config:
        autoscaling_config: {min_replicas: 1, max_replicas: 2}
YAML
serve run config.yaml      # foreground; Ctrl-C stops it
curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen-0.5b","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq '.choices[0].message'
```

The `Authorization` header is not checked by Ray Serve (the docs use `Bearer fake-key`); protect the endpoint
with a gateway or network policy. Use `serve deploy config.yaml` to hand the config to a running cluster, and
`serve status` to follow it.

## Rules

- **Ask before changing the system.** Installs, Helm releases, CRDs, RayService applies, Services or Ingresses
  and scale changes need approval and an undo path (`references/updating.md`).
- **Secrets never touch output.** `HF_TOKEN` goes into a Kubernetes Secret (`secretKeyRef`) or `runtime_env`
  read from the environment, never typed into a YAML you show. Create Secrets from `0600` files.
- **No auth in Serve.** `/v1` has no API key check. Keep it on ClusterIP or loopback and put LiteLLM,
  an Ingress with auth or a gateway in front. The Ray dashboard (8265) can run jobs: never expose it.
- **Pin versions.** Image `rayproject/ray-llm:<ray>-py312-cu130` (check tags), matching `rayVersion` and
  the KubeRay operator; never `latest` or `nightly`. Each Ray release is tested with one vLLM version
  (`references/install.md`).
- **Set `accelerator_type`** so replicas land on the right GPU, and make Kubernetes GPU limits match
  `tensor_parallel_size * pipeline_parallel_size` per replica.
- **Bake weights or mirror them.** Per-replica Hugging Face downloads make scale-up slow; use a cloud mirror
  (`model_source: {bucket_uri: ...}`), a shared volume or the image.
- **Head node: zero GPUs.** Set `num-cpus: "0"` and `num-gpus: "0"` on the head so no model replica runs there.
- **Measure** after every autoscaling or routing change, with versions recorded.

## Facts that surprise people (Ray 2.59.0)

- Only `model_loading_config` is required in `LLMConfig`; `llm_engine` supports `"vLLM"`; SGLang goes through
  `server_cls` (alpha integration).
- `engine_kwargs` are vLLM engine arguments in snake_case (`max_model_len`, `gpu_memory_utilization`);
  `disable_log_stats=True` is rejected while `log_engine_metrics` is on (the default).
- Serve defaults are small: `max_ongoing_requests` 5 and `target_ongoing_requests` 2 for ordinary deployments,
  so raise them for LLM replicas (KubeRay sample uses 128 and 64). `downscale_delay_s` defaults to 600.
- `num_replicas: "auto"` enables Serve autoscaling; replica scale needs the Ray autoscaler (KubeRay worker
  group `minReplicas`/`maxReplicas`) to add GPU nodes.
- Prefix-aware routing needs `enable_prefix_caching: true` in `engine_kwargs`; it is alpha, as is `KVAwareRouter`.
- Data-parallel deployments force `STRICT_PACK`; GPUs needed = `num_replicas * data_parallel_size *
  tensor_parallel_size`.
- Multi-LoRA: `max_loras` must equal `max_num_adapters_per_replica`; query as `<model_id>:<adapter_folder>`.
- The Ray/vLLM compatibility table lags: it listed 2.58.0 with vLLM 0.26.0 and nightly with 0.27.0, with no
  2.59.0 row, when verified. Check `pip show vllm` inside the image.

## Workflows

### Serve a model on a Ray cluster

- [ ] Run discovery; install (`references/install.md`).
- [ ] Write the config (`templates/serve-config.yaml`); `serve run` first, `serve deploy` after.
- [ ] `serve status` shows `RUNNING`; run a chat completion and a streamed one.
- [ ] Load test at the real concurrency; adjust `max_ongoing_requests` (`references/scaling-and-tuning.md`).

### Deploy on Kubernetes with KubeRay

- [ ] Confirm GPU nodes and the NVIDIA GPU operator (skill `nvidia-gpu-operator`).
- [ ] Install the operator by Helm, pinned to the chart version.
- [ ] Apply `templates/rayservice-llm.yaml` after setting image tag, GPUs and the Secret.
- [ ] `kubectl get rayservice`, then `port-forward svc/<name>-serve-svc 8000` and test.
- [ ] Add GCS fault tolerance and an upgrade strategy before production.

### Scale replicas and nodes

- [ ] Replica level: `autoscaling_config`. Node level: KubeRay worker group min/max (and the Ray autoscaler).
- [ ] Optional queue/GPU-driven pod scaling outside Ray: skill `keda` (applies to vLLM pods, not Ray Serve replicas).

### Debug a failure

- [ ] Capture `serve status`, `ray status`, and the replica log tail, then match `references/troubleshooting.md`.

## Reference index

- `references/install.md`: pip, `ray-llm` images, vLLM compatibility, KubeRay Helm.
- `references/serve-config.md`: `LLMConfig` fields, `deployment_config`, YAML, `serve` CLI.
- `references/parallelism-multinode.md`: TP/PP, placement groups, data parallel attention, expert parallel.
- `references/features.md`: routers, prefill/decode, multi-LoRA, direct streaming, SGLang, cloud mirrors.
- `references/scaling-and-tuning.md`: autoscaling knobs, scale to zero, cold start.
- `references/kubernetes-kuberay.md`: RayService, worker groups, GPU scheduling, upgrades, GCS fault tolerance.
- `references/observability.md`: metrics, dashboards, logs, health.
- `references/updating.md`: Ray and KubeRay upgrades, rollback.
- `references/troubleshooting.md`: symptom to cause to fix.
- `references/combos/litellm-gateway.md`: put LiteLLM in front for keys and budgets.
- `references/combos/keda-vllm-pods.md`: when KEDA fits and when it does not.
- `templates/`: `serve-config.yaml`, `rayservice-llm.yaml`.

## Companion skills

- `vllm`: engine flags, parsers, quantization. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `nvidia-gpu-operator`: GPU drivers and device plugin on Kubernetes. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-gpu-operator`.
- `keda`: event-driven pod autoscaling on queue and vLLM metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill keda`.
- `gateway-api-inference-extension`: model-aware load balancing for plain vLLM pods. Install: `npx skills add ScaleDockHQ/llms-skills --skill gateway-api-inference-extension`.
- `litellm` and `llm-gateway`: keys, routing, fallbacks. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `multi-node-inference`, `disaggregated-serving`, `prefix-aware-routing`: technique-level guidance. Install: `npx skills add ScaleDockHQ/llms-skills --skill multi-node-inference`.
- `multi-lora-serving`: adapter strategy across engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill multi-lora-serving`.
