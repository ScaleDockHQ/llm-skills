# Hardware: NVIDIA DGX Spark

> Verified against NVIDIA DGX Spark user guide and dgx-spark-playbooks (main), 2026-10-11

## What it is and when to choose it

DGX Spark is a small arm64 workstation built around the GB10 Grace Blackwell superchip: 20 Arm cores
(10 Cortex-X925 + 10 Cortex-A725), 128 GB of LPDDR5x **unified** memory shared by CPU and GPU
(about 273 GB/s), 1 or 4 TB NVMe, 10 GbE and a ConnectX-7 NIC with two QSFP ports (200GbE when two
Sparks are cabled directly). It runs DGX OS (Ubuntu based) with CUDA 13 and compute capability
sm_121.

Choose it when you want large models (that would need several discrete GPUs) on a quiet box, and
accept that decode speed is bound by memory bandwidth, not compute. Two Sparks give 256 GB for
models that need tensor or pipeline parallel across nodes.

## Install (DGX Spark/arm64 and generic x86)

DGX OS ships with the NVIDIA driver, CUDA, Docker and the NVIDIA Container Toolkit. Verify, do not
reinstall: `nvidia-smi`, `docker run --rm --gpus all <cuda-image> nvidia-smi`. For generic x86
hosts see `hardware-generic.md` and `host-setup.md`.

Container images must be arm64 (or multi-arch) and built for CUDA 13 / sm_121. Prefer NGC images
(`nvcr.io/nvidia/vllm`, `nvcr.io/nvidia/tensorrt-llm/release`) or upstream tags that state GB10 or
CUDA 13 support (`ghcr.io/ggml-org/llama.cpp:server-cuda13`, `lmsysorg/sglang:spark`,
`ghcr.io/mostlygeek/llama-swap:unified-cuda13`). An amd64-only image fails with `exec format error`.

## Unified memory: what changes

- `nvidia-smi` shows `Memory-Usage: Not Supported`. That is expected on this iGPU; per-process
  usage is still listed. Use `free -h` and `/proc/meminfo` for the real picture.
- `cudaMemGetInfo` can report less than is allocatable because the kernel can reclaim pages to
  swap. Engines that size their KV cache from it may under- or over-shoot. Prefer explicit sizes.
- Engine memory fractions (vLLM `--gpu-memory-utilization`, SGLang `--mem-fraction-static`,
  TensorRT-LLM `--kv_cache_free_gpu_memory_fraction`) are fractions of memory **shared with the OS,
  page cache, Docker, and every other process**. Leave real headroom.
- A runaway CPU process (compiler, download, rsync) competes with the model directly. When memory
  runs out, the box can freeze hard instead of OOM-killing. Install `memory-safety.md` first.

## Memory budgeting

Per node, before loading:

```text
weights (file size of the quantized checkpoint)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_seqs
+ runtime overhead (CUDA graphs, activations, engine buffers: measure, start with several GB)
+ OS + services headroom (desktop, Docker, LiteLLM, page cache pressure: keep a large margin)
<= 128 GB
```

Read `layers`, `num_key_value_heads` and `head_dim` (or `hidden_size / num_attention_heads`) from
the model's `config.json`. FP8 KV cache halves the KV term (a numerics change: see
`optimization.md`). Measure the real peak with `free -m` sampled during a long-context request,
not the number the engine prints at startup.

Co-resident models (a non-exclusive llama-swap group) must fit **together**, at their peaks.

## Single node versus dual node

- One node: simplest, no NCCL, no image drift. Prefer it whenever the model plus KV fits.
- Two nodes: needed when it does not fit, or for tensor parallel. Costs: every cold start touches
  both nodes, every update is done twice, the inter-node link adds latency per token.

### Connecting two Sparks

Follow NVIDIA's playbook ([Connect two Sparks](https://build.nvidia.com/spark/connect-two-sparks)):
cable one QSFP port to the other node, give the ConnectX-7 interfaces static addresses
(placeholders here: node-a 10.0.0.1, node-b 10.0.0.2), use the same username on both, and set up
passwordless SSH both ways. `ibdev2netdev` maps RDMA devices to interface names.

Then for the stack:

- Same service user, UID, paths (`/opt/llm-stack`, HF cache) on both nodes.
- Engines select the link by interface: set `NCCL_SOCKET_IFNAME` / `GLOO_SOCKET_IFNAME` to the
  ConnectX-7 interface (see `assets/models.d/example-vllm.sh`).
- The head node's wrapper starts the worker on node-b first and stops it on every exit path.
- Validate with NVIDIA's NCCL playbook before blaming the engine.

### Image drift between nodes

Pulling `:latest` (or rebuilding) on node-a and not on node-b leaves two different images with
the same tag. Multi-node startup then fails in confusing ways (version mismatch errors, hangs at
NCCL init, worker crash). Tags lie; compare IDs:

```bash
ref=vllm/vllm-openai:latest
docker image inspect --format '{{.Id}}' "$ref"
ssh node-b "docker image inspect --format '{{.Id}}' $ref"
```

For a locally built image, move it with `docker save "$ref" | ssh node-b docker load`.
`assets/common.sh` (`check_image_ids`) refuses to start when IDs differ.

## Known pitfalls

- Treating `nvidia-smi` memory as truth: it is not reported on this platform.
- Memory fractions tuned on a discrete GPU (0.90+) starve the OS on unified memory.
- Building engines from source while serving: the build can take the box down. Stop serving first.
- Different images on node-a and node-b behind the same tag.
- Assuming the 10 GbE port is the inter-node link: NCCL must be pointed at the ConnectX-7 interface.

## Official links

- [DGX Spark user guide](https://docs.nvidia.com/dgx/dgx-spark/index.html)
- [DGX Spark known issues](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)
- [DGX Spark playbooks](https://github.com/NVIDIA/dgx-spark-playbooks)
- [Connect two Sparks](https://build.nvidia.com/spark/connect-two-sparks)
