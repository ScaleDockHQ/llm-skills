---
name: triton-inference-server
description: Serve models with NVIDIA Triton Inference Server (tritonserver, nvcr.io/nvidia/tritonserver, model repository, config.pbtxt, dynamic batching, perf_analyzer) across TensorRT, ONNX, PyTorch, Python, vLLM and TensorRT-LLM backends, with KServe HTTP/gRPC, an OpenAI frontend and Prometheus. Use for install, model repo layout, instance groups, ensembles, metrics, Kubernetes, upgrades, failed to load or UNAVAILABLE errors. Not for LLM-only stacks (vllm, nvidia-dynamo), NIM (nvidia-nim) or KServe.
license: MIT
compatibility: Linux x86_64 or arm64 with Docker and the NVIDIA Container Toolkit (GPU) or CPU-only, bash, curl and jq. Installs, services, exposure and model-control APIs need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Triton Inference Server

Gets a Triton server running from a model repository, correctly configured (batching, instances, backends),
measured, observable and updatable. Verified against Triton v2.73.0 (NGC container 26.09, 2026-10-11).

**Scope:** Triton only: install, repository, serve, tune, scale, update, troubleshoot. Triton serves any model type
(vision, tabular, ensembles, LLMs via backends). For an LLM-only deployment the engine itself is usually simpler
(`vllm`, `sglang`, `tensorrt-llm`); for multi-node LLM orchestration see `nvidia-dynamo`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep -i tritonserver || true
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -i triton || true
command -v tritonserver && tritonserver --version 2>&1 | head -2
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv 2>/dev/null
ss -ltn 2>/dev/null | grep -E ':(8000|8001|8002)\b' || true

# Running server
curl -s -m 3 -o /dev/null -w 'ready %{http_code}\n' localhost:8000/v2/health/ready
curl -s -m 3 localhost:8000/v2 | jq '{name,version,extensions}'
curl -s -m 3 -X POST localhost:8000/v2/repository/index | jq -r '.[] | [.name,.version,.state,.reason] | @tsv'
curl -s -m 3 localhost:8000/v2/models/<model>/config | jq '{backend,platform,max_batch_size,instance_group}'
curl -s -m 3 localhost:8002/metrics | grep -E '^nv_inference_(request_success|request_failure|pending)' | head
```

## Decision flow

1. **Is Triton the right tool?** Mixed model types, ensembles, dynamic batching, one KServe-style API: yes.
   One LLM: use the engine (or its OpenAI server) directly.
2. **Pick the image**: `nvcr.io/nvidia/tritonserver:<YY.MM>-py3` (TensorRT, ONNX Runtime, PyTorch, OpenVINO,
   Python backends), `-vllm-python-py3` or `-trtllm-python-py3` for LLM backends, `-py3-sdk` for clients and
   `perf_analyzer`. Pin the tag (`references/install.md`). Check which tags exist: the 26.09 release has no
   TensorRT-LLM container.
3. **Build the model repository** (`references/models-and-formats.md`): `<repo>/<model>/[config.pbtxt]` plus `<version>/<file>`.
   Start with explicit configs; auto-complete covers most TensorRT, ONNX and OpenVINO models only.
4. **Choose the model-control mode** (`none`, `explicit`, `poll`) in `references/serve-config.md`. Dynamic loading
   can execute arbitrary code: treat it as admin-only.
5. **Start and verify**: `/v2/health/ready`, repository index shows READY, one inference request.
6. **Tune** with `perf_analyzer`: concurrency sweep, then dynamic batching and instance groups
   (`references/performance-tuning.md`).
7. **LLMs**: vLLM or TensorRT-LLM backend, `generate` endpoint, or the OpenAI frontend (`references/features.md`).
8. **Persist and scale**: `templates/` and `references/parallelism-multinode.md`; observe via `references/observability.md`.
9. **Break or upgrade**: `references/troubleshooting.md`, `references/updating.md`.

## Quick start

```bash
git clone -b r26.09 https://github.com/triton-inference-server/server.git
cd server/docs/examples && ./fetch_models.sh
docker run --gpus=1 --rm -p 127.0.0.1:8000:8000 -p 127.0.0.1:8001:8001 -p 127.0.0.1:8002:8002 \
  -v "$PWD/model_repository:/models" nvcr.io/nvidia/tritonserver:26.09-py3 \
  tritonserver --model-repository=/models --model-control-mode explicit --load-model densenet_onnx
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/v2/health/ready   # 200 when ready
docker run -it --rm --net=host nvcr.io/nvidia/tritonserver:26.09-py3-sdk \
  /workspace/install/bin/image_client -m densenet_onnx -c 3 -s INCEPTION /workspace/images/mug.jpg
```

Publishing ports on `127.0.0.1` keeps the server private; the upstream example uses `--net=host`, which exposes
8000/8001/8002 on every interface.

## Rules

- **Ask before changing the system.** Installs, services, exposure, and enabling model load/unload APIs need approval.
- **Never expose Triton to untrusted networks.** It has no built-in authentication; run it behind a gateway or mesh
  on a private network. Ports: HTTP 8000, gRPC 8001, metrics 8002.
- **Model repositories are code.** Some backends run code from the repository with the server's privileges and there
  is no sandbox. Restrict write access, keep dynamic updates (`explicit`, `poll`) off unless needed, run non-root.
- **Secrets never touch output.** Cloud-storage credentials (`AWS_*`, `GOOGLE_APPLICATION_CREDENTIALS`, Azure) and
  `HF_TOKEN` come from the environment or `0600` files, forwarded with `-e NAME`.
- **Pin the container tag** (`YY.MM`) and keep client and server on the same release; never `latest`.
- **Verify upstream.** Flags change between releases: run `tritonserver --help` in the pinned image.
- **Write `config.pbtxt` explicitly** for production; auto-complete costs start time and does not support PyTorch
  models. `--disable-auto-complete-config` enforces this.
- **Measure before and after** every tuning change, with the release recorded.

## Facts that surprise people (v2.73.0)

- Release numbers: server 2.73.0 = container 26.09. Tags follow `YY.MM`; flavors differ (`py3`, `vllm-python-py3`,
  `trtllm-python-py3`, `py3-sdk`). The 26.09 release ships no TensorRT-LLM backend image (latest listed: 26.07).
- With `max_batch_size > 1` and no scheduler block, the dynamic batcher is enabled automatically; `max_batch_size: 0`
  means no batching and `dims` are the full shape.
- `/v2/health/ready` returns 200 only when the server and (by default) its models are ready.
- Model control mode `none` loads everything at start, `explicit` only `--load-model` entries (runtime load and
  unload via API), `poll` watches the repository (`--repository-poll-secs`; load API returns errors; not
  recommended for production).
- vLLM backend with tensor parallelism > 1 needs `"distributed_executor_backend":"ray"` in `model.json`.
- Metrics need DCGM access: GPU metrics fail with MIG or a separate DCGM agent; `--allow-gpu-metrics false`
  avoids an NVSwitch shutdown segfault.
- `generate` is a raw completion endpoint with no chat template.

## Workflows

### Serve a model

- [ ] Discovery; pick and pin the image (`references/install.md`); pull it.
- [ ] Lay out the repository and config (`references/models-and-formats.md`, `templates/config.pbtxt`).
- [ ] Start with the intended control mode; wait for READY; test with `perf_analyzer` or a client.
- [ ] Persist with `templates/docker-compose.yml` or `templates/k8s-deployment.yaml`.

### Tune throughput

- [ ] Baseline `perf_analyzer -m <model> --concurrency-range 1:8`; record p95.
- [ ] Add `dynamic_batching` and `instance_group` (count per GPU); re-measure; keep what helps.

### Serve an LLM

- [ ] vLLM backend (`-vllm-python-py3`) or TensorRT-LLM LLM API backend; `references/features.md`.
- [ ] Or the OpenAI-compatible frontend on port 9000 for chat/completions clients.

### Upgrade or debug

- [ ] `references/updating.md`; `references/troubleshooting.md` with the exact load error text.

## Reference index

- `references/install.md`: images, tags, flavors, CPU-only, source builds, Kubernetes/Helm examples.
- `references/serve-config.md`: `tritonserver` flags, ports, control modes, cloud repositories, env vars.
- `references/models-and-formats.md`: repository layout, backends, config.pbtxt, versions, auto-complete.
- `references/parallelism-multinode.md`: instance groups, multi-GPU, rate limiter, ensembles and BLS, scaling out.
- `references/features.md`: dynamic and sequence batching, decoupled models, response cache, LLM backends, OpenAI frontend.
- `references/api.md`: KServe v2 HTTP/gRPC, extensions, generate, clients.
- `references/performance-tuning.md`: perf_analyzer, Model Analyzer, tuning order.
- `references/integrations.md`: Kubernetes, SageMaker, gateways, Prometheus/Grafana, other NVIDIA skills.
- `references/observability.md`: metrics, tracing, logging.
- `references/updating.md`: upgrade procedure.
- `references/troubleshooting.md`: error to cause to fix.
- `templates/`: `config.pbtxt`, `docker-compose.yml`, `k8s-deployment.yaml`.

## Companion skills

- `vllm`, `tensorrt-llm`: engines behind the LLM backends. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `nvidia-dynamo`: multi-node LLM orchestration. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dynamo`.
- `nvidia-nim`: packaged model microservices. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-nim`.
- `choosing-inference-engine`: engine selection. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `litellm` and `llm-gateway`: auth and routing. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llm-observability`, `dcgm-exporter`: metrics and GPU telemetry. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
