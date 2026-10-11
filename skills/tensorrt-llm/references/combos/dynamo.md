# TensorRT-LLM with NVIDIA Dynamo

> Verified against TensorRT-LLM v1.2.1 / 1.3.0rc25 and NVIDIA Dynamo v1.5.1 (examples, `container/context.yaml`, TensorRT-LLM backend docs at that tag), 2026-10-11

[NVIDIA Dynamo](https://github.com/ai-dynamo/dynamo) is a datacenter-scale serving layer: a frontend (OpenAI API), router (round robin, random or KV-aware), and workers. Its TensorRT-LLM backend runs TensorRT-LLM engines as Dynamo workers (`python3 -m dynamo.trtllm`) and adds disaggregated prefill/decode, KV-aware routing, an SLA-based planner, request migration and cancellation, multimodal, and multi-node deployment on Kubernetes or Slurm. Use plain `trtllm-serve` for one box; use Dynamo when you need those features. A separate `nvidia-dynamo` skill is planned in a later wave.

## Versions that fit together

| Dynamo | Image                                                | TensorRT-LLM inside                                                | Notes                                                                       |
| ------ | ---------------------------------------------------- | ------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| 1.5.1  | `nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1` | 1.3.0rc25 (pyproject pin and `container/context.yaml` runtime tag) | Latest release at writing (2026-10-07). Image is multi-arch (amd64, arm64). |
| 1.4.0  | `tensorrtllm-runtime:1.4.0`                          | 1.3.0rc22, CUDA 13.1, driver 580+                                  | From the 1.5.1 docs' container matrix (stale there, shows 1.4.0).           |

Dynamo's runtime image layers Dynamo on the upstream `nvcr.io/nvidia/tensorrt-llm/release` image (it does not compile TensorRT-LLM). It requires Python 3.10 or 3.12 (TensorRT-LLM does not support 3.11), Ubuntu 22.04 or 24.04 (arm64 needs 24.04), driver 575.51.03+ (CUDA 12) or 580.00.03+ (CUDA 13). TensorRT-LLM is available through the container only (no wheel selector for this backend). Tags: `1.3.1`, `1.4.0`, `1.4.1`, `1.4.2`, `1.5.0`, `1.5.1` exist on NGC (plus `-efa` variants for AWS).

Use the image's TensorRT-LLM; do not mix a stable 1.2.1 `trtllm-serve` with a Dynamo image of another version across nodes.

## Single machine quick start

```bash
git clone https://github.com/ai-dynamo/dynamo.git && cd dynamo && git checkout v1.5.1
docker compose -f dev/docker-compose.yml up -d        # etcd + NATS; or use --discovery-backend file for one box
export DYNAMO_VERSION=1.5.1
docker run --gpus all -it --network host --ipc host \
  nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:$DYNAMO_VERSION
# inside the container
cd $DYNAMO_HOME/examples/backends/trtllm && ./launch/agg.sh      # Qwen/Qwen3-0.6B by default
```

Override with `MODEL_PATH`, `SERVED_MODEL_NAME`, `AGG_ENGINE_ARGS`. Test with:

```bash
curl localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-0.6B","messages":[{"role":"user","content":"Hi"}],"max_tokens":30}'
```

Known issue (Dynamo docs): `docker run --network host` was reported to hang before readiness on one platform; not shown to be distro-specific.

Launch scripts in `examples/backends/trtllm/launch/`: `agg.sh`, `agg_router.sh` (KV routing), `disagg.sh` (2 GPUs), `disagg_router.sh`, `disagg_same_gpu.sh`, `gpt_oss_disagg.sh`, multimodal and diffusion variants. Each script starts `python3 -m dynamo.frontend` plus workers.

## Process layout (what the scripts run)

```bash
python3 -m dynamo.frontend &                       # OpenAI HTTP on :8000 (DYN_HTTP_PORT or --http-port); add --router-mode kv for KV routing

CUDA_VISIBLE_DEVICES=0 DYN_SYSTEM_PORT=8081 python3 -m dynamo.trtllm \
  --model-path Qwen/Qwen3-0.6B --served-model-name Qwen/Qwen3-0.6B \
  --extra-engine-args ./examples/backends/trtllm/engine_configs/qwen3/prefill.yaml \
  --disaggregation-mode prefill &

CUDA_VISIBLE_DEVICES=1 DYN_SYSTEM_PORT=8082 python3 -m dynamo.trtllm \
  --model-path Qwen/Qwen3-0.6B --served-model-name Qwen/Qwen3-0.6B \
  --extra-engine-args ./examples/backends/trtllm/engine_configs/qwen3/decode.yaml \
  --disaggregation-mode decode &
```

`--extra-engine-args` is the TensorRT-LLM YAML (same LLM API fields as `trtllm-serve --config`). KV-aware aggregated serving adds `--publish-kv-events` to workers and `--router-mode kv` to the frontend. Conditional disaggregation needs KV-aware routing and `--publish-kv-events` on prefill and decode workers. Default thinking mode: `--dyn-default-thinking-mode enabled|disabled` or `DYN_DEFAULT_THINKING_MODE`.

Engine YAML for the Qwen3 example (prefill; the decode file is the same except `disable_overlap_scheduler: false`):

```yaml
tensor_parallel_size: 1
moe_expert_parallel_size: 1
enable_attention_dp: false
max_num_tokens: 8192
trust_remote_code: true
backend: pytorch
enable_chunked_prefill: true
disable_overlap_scheduler: true # prefill only
cuda_graph_config:
  max_batch_size: 16
kv_cache_config:
  free_gpu_memory_fraction: 0.85
cache_transceiver_config:
  backend: DEFAULT # NIXL (UCX) unless TRTLLM_USE_*_KVCACHE says otherwise
  # max_tokens_in_buffer: 65536      # must exceed max input length (see below)
```

`cache_transceiver_config.backend` values (1.3.0rc22 behavior per Dynamo docs): unset = KV transfer disabled; `DEFAULT` = NIXL unless one of `TRTLLM_USE_NIXL_KVCACHE`, `TRTLLM_USE_UCX_KVCACHE`, `TRTLLM_USE_MOONCAKE_KVCACHE`, `TRTLLM_USE_MPI_KVCACHE` is `1`; `UCX`, `NIXL`, `MOONCAKE`, `MPI` force that backend. Transfer methods: NIXL with UCX (default), NIXL with Libfabric, UCX directly. For AWS EFA Dynamo ships a dedicated `-efa` runtime image.

## Kubernetes

Dynamo's operator manages `DynamoGraphDeployment` resources (apiVersion `nvidia.com/v1beta1` in v1.5.1). The repo ships ready deployments under `examples/backends/trtllm/deploy/` (`agg.yaml`, `agg_router.yaml`, `disagg.yaml`, `disagg_router.yaml`, `disagg-multinode.yaml`, `disagg_planner.yaml`) and recipes under `recipes/` (gpt-oss-120b, Qwen3-235B FP8 on Blackwell and Hopper, DeepSeek-R1 wide-EP on GB200, Kimi K2.5 with EAGLE, Nemotron). Shape of `disagg.yaml` (abridged):

```yaml
apiVersion: nvidia.com/v1beta1
kind: DynamoGraphDeployment
metadata: { name: trtllm-disagg }
spec:
  components:
    - name: Frontend
      type: frontend
      replicas: 1
      podTemplate:
        {
          spec:
            {
              containers:
                [
                  {
                    name: main,
                    image: nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1,
                  },
                ],
            },
        }
    - name: decode
      type: decode
      replicas: 1
      podTemplate:
        spec:
          containers:
            - name: main
              image: nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1
              command: [python3, -m, dynamo.trtllm]
              args:
                [
                  --model-path,
                  Qwen/Qwen3-0.6B,
                  --served-model-name,
                  Qwen/Qwen3-0.6B,
                  --extra-engine-args,
                  ./examples/backends/trtllm/engine_configs/qwen3/decode.yaml,
                  --disaggregation-mode,
                  decode,
                ]
              envFrom: [{ secretRef: { name: hf-token-secret } }]
              resources: { limits: { nvidia.com/gpu: "1" } }
              workingDir: /workspace/
  # prefill component: same with prefill.yaml and --disaggregation-mode prefill
```

Install the operator and its CRDs first (Dynamo's Kubernetes quickstart); the `hf-token-secret` Secret holds `HF_TOKEN`, created out of band. Adjust the image tag in YAML with `sed`/`yq` before `kubectl apply`. Pin the same tag everywhere.

## Slurm and multi-node

Dynamo documents multi-node deployment with Slurm in a multinode doc that was not re-read here (`docs/fern/pages/developer-guide/additional-resources/tensorrt-llm-details/multinode-examples.md`). Without Dynamo, see `parallelism-multinode.md`. Cross-engine view: `disaggregated-serving` and `multi-node-inference` skills (planned).

## Observability

Dynamo exposes TensorRT-LLM Prometheus metrics on the worker system port: set `DYN_SYSTEM_PORT` (default disabled, `-1`) and scrape `/metrics`; engine metrics carry the `trtllm_` prefix, Dynamo ones `dynamo_`. The docs (written against an older bundled TensorRT-LLM) say only 5 basic engine metrics were exposed. Worker flag `--publish-events-and-metrics`. OTLP tracing: `--override-engine-args '{"return_perf_metrics": true, "otlp_traces_endpoint": "http://localhost:4317"}'` with `DYN_LOGGING_JSONL=true`, `OTEL_EXPORT_ENABLED=1` (from `disagg.sh --enable-otel`). Optional `DYN_TRTLLM_SERVER_DISABLE_GC=1` mirrors `TRTLLM_SERVER_DISABLE_GC` for benchmarks.

## Pitfalls (from Dynamo docs and TensorRT-LLM docs)

- **KV exhaustion deadlock in disaggregated mode**: if `cache_transceiver_config.max_tokens_in_buffer` is smaller than the maximum input length, workers can hang under sustained load (log: `num_fitting_reqs=0 and fitting_disagg_gen_init_requests is empty, may not have enough kvCache`). Set it above your max ISL (the gpt-oss example uses 65536) and restart.
- **Driver mismatch** shows up as PyTorch "The NVIDIA driver on your system is too old": the image needs a newer driver than the host (580+ for CUDA 13.1 images).
- **Request cancellation**: the TensorRT-LLM matrix says the engine may not be notified of cancellations in some cases, leaving resources allocated (the reference guide's cancellation matrix says supported; the two statements disagree in the docs, test it).
- **`n > 1`** requests need `TLLM_ALLOW_N_GREEDY_DECODING=1` on the worker.
- **Experimental sidecar**: Dynamo can run its worker outside TensorRT-LLM through TensorRT-LLM's gRPC API (experimental, see Dynamo `sidecar.md`).
- **Mixed versions**: use one image tag on all nodes; KV transfer between different TensorRT-LLM builds is not covered by the docs.
- Disaggregation limits: decoder-only models, beam width 1, homogeneous KV layout (TensorRT-LLM docs).

## DGX Spark

Dynamo documents Ampere, Ada, Hopper and Blackwell and arm64 on Ubuntu 24.04; Spark-specific Dynamo recipes were not found in the v1.5.1 tree. Disaggregating across a single GB10 gains little because both phases share the same memory pool. (unverified for Spark; test before relying on it)

## Official links

- Dynamo repo: https://github.com/ai-dynamo/dynamo
- TensorRT-LLM backend docs (in the repo): https://github.com/ai-dynamo/dynamo/tree/v1.5.1/docs/fern/pages/developer-guide/knowledge-base/modular-components/backends/tensorrt-llm
- Examples and deploy YAML: https://github.com/ai-dynamo/dynamo/tree/v1.5.1/examples/backends/trtllm
- TensorRT-LLM disaggregated serving: https://nvidia.github.io/TensorRT-LLM/features/disagg-serving.html
- NGC image: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/ai-dynamo/containers/tensorrtllm-runtime
