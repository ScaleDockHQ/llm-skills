# SGLang on NVIDIA DGX Spark (GB10)

> Verified against SGLang v0.5.21 (image `lmsysorg/sglang:v0.5.21-cu130`, Docker Hub tags checked 2026-10-11), NVIDIA dgx-spark-playbooks `nvidia/sglang` (last updated 04/28/2026 per its README) and `nvidia/connect-two-sparks`; the wrapper, llama-swap and dual-node recipes are carried over from this repo's earlier DGX Spark work and were not re-run on hardware in this pass, 2026-10-11

Host setup, memory safety, networking and updates for Spark machines: skill `nvidia-dgx-spark` (install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`). Engine-agnostic stack layout with llama-swap, LiteLLM and a tunnel: skill `self-hosted-llms`.

## When SGLang on a Spark

Pick SGLang when a model's recipe or day-zero support lands there first, for agent workloads with large shared prefixes (RadixAttention), or for strong structured output. It is a cold-start-heavy, one-model-per-process engine like vLLM: run it in an exclusive llama-swap group so it does not share the 128 GB with another resident engine.

## Platform facts that change the defaults

- GB10 is an arm64 iGPU with 128 GB unified memory shared with the OS, page cache and Docker. `nvidia-smi` does not report memory usage here (expected); use `free -h`.
- `--mem-fraction-static` is a fraction of memory shared with everything else. NVIDIA's playbook uses `0.75`; start at 0.7 to 0.8 and lower it if CUDA graph capture OOMs or the box gets sluggish. Do not carry over 0.9 from discrete GPUs.
- A runaway CPU process (build, rsync) competes with the model; when memory runs out the machine can freeze instead of OOM-killing. Install memory safety first (`nvidia-dgx-spark` skill).
- Images must be arm64 (or multi-arch) with CUDA 13. `lmsysorg/sglang:v0.5.21-cu130` is multi-arch (amd64, arm64). An amd64-only image fails with `exec format error`.
- The `lmsysorg/sglang:spark` tag is arm64-only and was last pushed 2025-11-06: do not use it for new work. NVIDIA's playbook uses `latest-cu130`; pin `v0.5.21-cu130` instead (immutable).
- NVFP4 checkpoints need `--quantization modelopt_fp4`; MXFP4 models (gpt-oss) need no flag. The playbook's supported list (Llama 3.1/3.3, Qwen3, Phi-4, gpt-oss, Nemotron-3-Nano-Omni) is in `models-and-formats.md`.
- NVIDIA's DeepSeek-V2-Lite example uses `--attention-backend flashinfer --mem-fraction-static 0.75 --tp 1 --trust-remote-code`.

## Single node: quick start

DGX OS already ships the driver, CUDA, Docker and the NVIDIA Container Toolkit. Verify, do not reinstall.

```bash
docker run --rm --gpus all lmsysorg/sglang:v0.5.21-cu130 nvidia-smi
docker run --rm --gpus all --ipc=host -p 127.0.0.1:30000:30000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
  lmsysorg/sglang:v0.5.21-cu130 \
  python3 -m sglang.launch_server --model-path openai/gpt-oss-120b --served-model-name gpt-oss \
  --host 0.0.0.0 --port 30000 --mem-fraction-static 0.75 --context-length 65536 \
  --tool-call-parser gpt-oss --reasoning-parser gpt-oss
curl -s http://127.0.0.1:30000/health -o /dev/null -w '%{http_code}\n'
```

Pre-download weights first (`hf download openai/gpt-oss-120b`) because the example runs offline (`HF_HUB_OFFLINE=1`). The first start takes several minutes (weights, CUDA graph capture, kernel autotune); persist `~/.cache/huggingface` and consider a volume for `SGLANG_CACHE_DIR`/`~/.cache/flashinfer`.

## Stack wrapper and llama-swap

Wrapper function sourced by `/opt/llm-stack/start-model.sh` (the `models.d/gpt-oss.sh` pattern in `self-hosted-llms`):

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all --ipc=host -p "127.0.0.1:${PORT}:30000" \
    -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
    lmsysorg/sglang:v0.5.21-cu130 \
    python3 -m sglang.launch_server --model-path openai/gpt-oss-120b \
      --served-model-name "$MODEL_ID" --host 0.0.0.0 --port 30000 \
      --mem-fraction-static 0.75 --context-length 65536 --enable-metrics \
      --tool-call-parser gpt-oss --reasoning-parser gpt-oss
}
```

llama-swap entry (see `integrations.md`): `checkEndpoint: /health`, `ttl: 0`, `unloadTimeout: 60`, `capabilities.tools: true` only because a tool-call parser is set. Stack contract: bind `127.0.0.1`, no `--api-key` (LiteLLM holds keys), one model per llama-swap group. Inspect effective args through llama-swap: `curl -s http://127.0.0.1:8080/upstream/gpt-oss/server_info | jq .version` (do not paste `launch_command`).

## Dual DGX Spark (TP=2 across the ConnectX-7 link)

Use two nodes only when the model plus KV does not fit on one, or for tensor parallel; every cold start touches both nodes and every update is done twice.

Prerequisites (NVIDIA playbook `connect-two-sparks`): QSFP cable between the nodes, static addresses on the ConnectX-7 interfaces (the interfaces that show `Up` in `ibdev2netdev`; each physical port has two logical names such as `enp1s0f1np1` and `enP2p1s0f1np1`), same username and paths on both nodes, passwordless SSH both ways. Validate NCCL with NVIDIA's playbook before blaming SGLang. Placeholders below: node-a 10.0.0.1, node-b 10.0.0.2.

Same image on both nodes, verified by ID, not tag:

```bash
ref=lmsysorg/sglang:v0.5.21-cu130
docker image inspect --format '{{.Id}}' "$ref"; ssh node-b "docker image inspect --format '{{.Id}}' $ref"
```

Both nodes run the same command with different `--node-rank`; `--network host` lets the ranks reach each other. Bind the API to loopback because host networking publishes everything:

```bash
# node-a (rank 0, serves the API); wrap in docker run with the flags listed below
python3 -m sglang.launch_server --model-path M --tp-size 2 --nnodes 2 --node-rank 0 \
  --dist-init-addr 10.0.0.1:50000 --host 127.0.0.1 --port "$PORT"

# node-b (rank 1), started over ssh by the head node's wrapper
python3 -m sglang.launch_server --model-path M --tp-size 2 --nnodes 2 --node-rank 1 \
  --dist-init-addr 10.0.0.1:50000 --host 127.0.0.1
```

Docker flags on both nodes: `--gpus all --ipc=host --network host -e NCCL_SOCKET_IFNAME=<cx7-interface> -e GLOO_SOCKET_IFNAME=<cx7-interface>`.

Notes (carried over): start node-b first, then node-a, and stop both on every exit path (the wrapper's `worker_run` over ssh); if startup deadlocks add `--disable-cuda-graph` (in 0.5.21 prefer `--disable-decode-cuda-graph --disable-prefill-cuda-graph`); set NCCL interface variables to the CX7 interface, not the 10 GbE port. `--tp-size 2` here means one GPU per node. Whether PD disaggregation over this link works is untested in this repo.

## Updating on Sparks

Pre-pull the pinned tag on both nodes while serving, compare IDs, restart in a window, rerun the benchmark: `references/updating.md`. Do not build engines from source while serving.

## Pitfalls specific to Spark

- Memory fractions above about 0.8 starve the OS and can freeze the machine.
- Treating `nvidia-smi` memory as truth: it is not reported.
- Mixed images behind one tag on two nodes: hangs at NCCL init or version-mismatch errors.
- Stale `spark` tag: confirm what runs with `curl -s http://127.0.0.1:30000/server_info | jq -r .version`.
- Using `/health_generate` as the llama-swap `checkEndpoint` adds load on every poll.
- `--host 0.0.0.0` plus `--network host` exposes the unauthenticated API on every interface (carried over).
