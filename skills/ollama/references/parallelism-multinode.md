# Ollama: parallelism, multi-GPU and scaling out

> Verified against Ollama v0.40.3, 2026-10-11

Docs: faq, gpu; envconfig/config.go

Ollama's documented scope is one host. The v0.40.3 docs describe no multi-node or distributed inference, no tensor/pipeline parallel configuration and no continuous-batching tuning knobs beyond the ones below. For those, use a different engine (see "When to switch").

## How the scheduler works

- **Two levels of concurrency.** Several models can be loaded at once if memory allows (`OLLAMA_MAX_LOADED_MODELS`, default 3 x GPUs, or 3 on CPU), and each loaded model serves several requests in parallel (`OLLAMA_NUM_PARALLEL`, default 1).
- **Parallel slots multiply context.** A 2K context with 4 parallel requests allocates an 8K context. Required memory scales with `OLLAMA_NUM_PARALLEL` x `OLLAMA_CONTEXT_LENGTH`. Raise parallelism only after checking `ollama ps` still reads `100% GPU`.
- **Insufficient memory queues, it does not fail.** If a new model does not fit beside the loaded ones, requests wait until an idle model unloads. On GPU a new model must fit completely in VRAM to be loaded alongside another. Queued requests run in order; beyond `OLLAMA_MAX_QUEUE` (512) the server answers 503.
- **Behind a proxy with a timeout, queueing looks like a hang.** Size limits so loads fit, or preload.
- **Windows with Radeon** currently defaults to one loaded model because of VRAM reporting limits; you can raise it but must not exceed VRAM (FAQ note).

## Multi-GPU

- If the model fits on one GPU, Ollama loads it on one GPU (least PCIe traffic, usually fastest). If not, it is spread across all available GPUs.
- `OLLAMA_SCHED_SPREAD=1` always spreads across all GPUs. Documented only as "always schedule across all GPUs"; the speed trade-off is unmeasured here, so benchmark before adopting.
- Restrict GPUs: `CUDA_VISIBLE_DEVICES=<uuid,uuid>` (UUIDs from `nvidia-smi -L`; numeric order can vary), `ROCR_VISIBLE_DEVICES` / `HIP_VISIBLE_DEVICES` for AMD, `GGML_VK_VISIBLE_DEVICES` for Vulkan. An invalid ID (`-1`) forces CPU.
- Mixed AMD generations: `HSA_OVERRIDE_GFX_VERSION_0=10.3.0`, `HSA_OVERRIDE_GFX_VERSION_1=11.0.0` set targets per device.
- Several AMD GPUs on Linux can produce gibberish; see AMD's multi-GPU known issues guide linked in `troubleshooting.md`.
- Reserve VRAM for other processes with `OLLAMA_GPU_OVERHEAD` (bytes per GPU).

## Several Ollama instances on one host

Useful to pin each instance to GPUs or to give an outer scheduler (llama-swap) full control:

```bash
# Instance A on GPU 0, instance B on GPU 1, shared read-only-ish model store
CUDA_VISIBLE_DEVICES=GPU-aaaa OLLAMA_HOST=127.0.0.1:11434 OLLAMA_NOPRUNE=1 ollama serve
CUDA_VISIBLE_DEVICES=GPU-bbbb OLLAMA_HOST=127.0.0.1:11435 OLLAMA_NOPRUNE=1 ollama serve
```

- Give each instance a distinct `OLLAMA_HOST` port (or container port mapping).
- Set `OLLAMA_NOPRUNE=1` on every instance that shares a store, otherwise startup pruning of unused blobs can delete what another instance is using.
- Do not point two writers at one store while pulling or creating models.
- In Docker: one container per GPU set with `--gpus '"device=0"'`, same bind-mounted `/root/.ollama`.

## Several machines

No clustering. Put a load balancer or a gateway (`litellm`, `llm-gateway`) in front of independent Ollama servers; each has its own models and its own queue. Health-check with `GET /api/version`; route by model with `GET /api/tags`. Remember every instance is unauthenticated, so keep them on a private network.

## When to switch engines

| Need                                                                               | Use instead                                                                    |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| High concurrency, continuous batching, prefix caching, tensor parallel, multi-node | `vllm` or `sglang` (`multi-node-inference` for several machines)               |
| NVIDIA-only peak throughput                                                        | `tensorrt-llm`                                                                 |
| Exact llama.cpp flags (`--n-cpu-moe`, split modes, RPC), newest architectures      | `llama-cpp` (`llama-server`)                                                   |
| LoRA serving                                                                       | `vllm`, `llama-cpp`, or merge the adapter and import (Ollama rejects adapters) |
| Model swapping across engines with TTLs                                            | `llama-swap` in front of Ollama (see `combos/llama-swap.md`)                   |

Install any of them with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.
