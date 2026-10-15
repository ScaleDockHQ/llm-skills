# Hardware: generic NVIDIA Linux hosts

> Verified against NVIDIA Container Toolkit 1.20.1 install guide, NVIDIA CUDA Compatibility docs, llama-swap v263 config docs, vLLM v0.31.0, SGLang v0.5.21 and llama.cpp server docs, 2026-10-11

Use this file for any NVIDIA Linux box that is not a DGX Spark: x86_64 workstations and servers,
arm64 servers, single or multi-GPU. For DGX Spark (GB10, unified memory) use `hardware-dgx-spark.md`.
Host preparation (driver, Docker, toolkit) is in `host-setup.md`.

## Discover the hardware

```bash
nvidia-smi                                   # driver version, max CUDA version, GPUs, VRAM
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv
nvidia-smi topo -m                           # GPU-to-GPU links (NV#, PIX, PHB, SYS)
uname -m                                     # x86_64 or aarch64: pick matching images
free -h; nproc; df -h
```

Run it on every node. Record the GPU count, VRAM per GPU, interconnect and architecture.

## Discrete VRAM vs unified memory

|                       | Discrete GPU (this file)              | Unified memory (DGX Spark)                    |
| --------------------- | ------------------------------------- | --------------------------------------------- |
| Model memory          | VRAM per GPU, fixed                   | Shared pool with the OS and every process     |
| `nvidia-smi` memory   | Reported per GPU                      | "Not Supported" is expected                   |
| Failure on overcommit | CUDA OOM in the engine; host survives | Host-wide OOM; can take down the node         |
| Engine memory knob    | Fraction of _that GPU's_ VRAM         | Fraction of the _shared_ pool                 |
| Downloads/builds      | Use host RAM, rarely hurt serving     | Compete with serving (see `memory-safety.md`) |

On discrete GPUs, `--gpu-memory-utilization` (vLLM) and `--mem-fraction-static` (SGLang) apply per
GPU. Host RAM still matters: weight loading, CPU offload, and llama.cpp layers left on the CPU.

## VRAM budgeting

Budget = weights + KV cache + overhead, per GPU, before you pick a model or a context length.

1. **Weights**: roughly parameters x bytes per parameter (BF16 = 2, FP8 = 1, 4-bit about 0.5 plus
   scales). Check the actual safetensors/GGUF size on disk; it is the better number.
2. **KV cache** per token: `2 x layers x kv_heads x head_dim x bytes_per_element`. Multiply by
   context length x concurrent sequences. Read `num_hidden_layers`, `num_key_value_heads` and
   `head_dim` from the model's `config.json`. FP8 KV halves it vs BF16 (see `optimization.md`).
3. **Overhead**: CUDA context, activations, CUDA graphs, framework buffers. Leave headroom; measure
   it on first start rather than guessing.

With tensor parallel, weights and KV cache split across GPUs; overhead is paid per GPU.

Knobs that shrink the budget:

| Engine    | Context            | Concurrency              | Memory cap                            |
| --------- | ------------------ | ------------------------ | ------------------------------------- |
| vLLM      | `--max-model-len`  | `--max-num-seqs`         | `--gpu-memory-utilization`            |
| SGLang    | `--context-length` | `--max-running-requests` | `--mem-fraction-static`               |
| TRT-LLM   | engine build       | `--max_batch_size`       | `--kv_cache_free_gpu_memory_fraction` |
| llama.cpp | `-c`               | `-np`                    | `-ngl` (layers on GPU)                |

vLLM and SGLang pre-allocate the KV pool up to their memory cap. Two engines on one GPU must have
caps that sum below 1.0 with headroom, or the second one fails to start.

## Multi-GPU

### Pin a model to GPUs with llama-swap `env`

Each llama-swap model entry accepts `env` (list of `NAME=value` strings). Use it to give each model
its own GPUs so co-resident models do not fight over one card:

```yaml
models:
  qwen-coder:
    env:
      - "CUDA_VISIBLE_DEVICES=0,1"
    cmd: /opt/llm-stack/start-model.sh run qwen-coder ${PORT}
  small-gguf:
    env:
      - "CUDA_VISIBLE_DEVICES=2"
    cmd: /opt/llm-stack/start-model.sh run small-gguf ${PORT}
```

The variable reaches the wrapper process, not the container. When the wrapper uses `docker run`,
translate it: pass `--gpus '"device=0,1"'` (or `-e CUDA_VISIBLE_DEVICES`) from the wrapper. Indices
follow `nvidia-smi` order; confirm inside the container with `nvidia-smi -L`.

### Parallelism inside one box

- **Tensor parallel** splits each layer across GPUs. Use it when the model does not fit one GPU or
  you want lower latency. vLLM `--tensor-parallel-size N`, SGLang `--tp-size N`, TRT-LLM
  `--tp_size N`. N usually must divide the attention head count; powers of two are safe.
- **Pipeline parallel** (vLLM `--pipeline-parallel-size`) splits layers into stages. Less traffic
  between GPUs than TP; useful over slow links.
- **Data parallel** (vLLM `--data-parallel-size`, SGLang `--dp-size`) runs replicas for throughput
  when one copy fits a GPU.
- **llama.cpp** splits with `-sm/--split-mode` and `-ts/--tensor-split`; select GPUs with `-dev`.

### Interconnect: PCIe vs NVLink

Tensor parallel all-reduces every layer, so it is sensitive to GPU-to-GPU bandwidth. Check
`nvidia-smi topo -m`: `NV#` means NVLink; `PIX`/`PXB`/`PHB` are PCIe paths; `SYS` crosses CPU
sockets (slowest). On PCIe-only boxes prefer TP within GPUs that share a switch, consider pipeline
or data parallel instead, and measure both with `scripts/bench.sh` before choosing. Multi-node
serving is a separate setup; see `adding-a-server.md`.

## Driver/CUDA compatibility vs container images

Images bundle a CUDA runtime; the host provides only the driver. The driver must be new enough for
the image's CUDA version.

1. Read the host side: `nvidia-smi` header shows `Driver Version` and `CUDA Version` (the newest
   CUDA that driver supports).
2. Read the image side: the image tag or docs (e.g. `cu129`, `cuda13.0`), or run the image's own
   `nvidia-smi`/`nvcc --version` if it ships them.
3. Test before serving: `docker run --rm --runtime=nvidia --gpus all <image> nvidia-smi`.

NVIDIA's CUDA Compatibility docs describe minor version compatibility (same CUDA major family on a
sufficiently new driver, with some feature limitations) and forward compatibility via the
`cuda-compat-<major>-<minor>` package, "subject to platform and GPU support". Prefer upgrading the
host driver over relying on forward compatibility; consult the docs for your GPU before using it.

Symptoms of a mismatch: `CUDA driver version is insufficient`, `no kernel image is available for
execution on the device` (image not built for your GPU architecture), or the engine silently
falling back to CPU. Also confirm arm64 hosts use images published for `linux/arm64`.

## Rented cloud GPU VMs

The same stack runs on a rented GPU VM, but provisioning, persistent disks, egress, cost control
and stop/start are cloud-specific. Use the companion skill:

```bash
npx skills add ScaleDockHQ/llm-skills --skill cloud-llms
```

Keep the loopback-only port map from this skill on the VM and expose only via
`exposure-cloudflare.md` or `exposure-tailscale.md`; never open engine ports in the cloud firewall.

## Official links

- NVIDIA Container Toolkit install: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
- CUDA compatibility: https://docs.nvidia.com/deploy/cuda-compatibility/
- llama-swap config reference: https://github.com/mostlygeek/llama-swap/blob/main/config.example.yaml
- vLLM parallelism: https://docs.vllm.ai/en/latest/serving/parallelism_scaling.html
