# ComfyUI: performance and memory

> Verified against ComfyUI v0.39.0 (comfy/cli_args.py help strings, server.py `/free`, README), 2026-10-11

All behaviour below comes from the v0.39.0 argument help text. Memory management changes quickly between releases (dynamic VRAM, cache modes); re-read `python main.py --help` after an update.

## What the README claims

ComfyUI "can run even the biggest open source models on as low as 4GB vram + 8GB ram" using asynchronous weight streaming (README). Treat that as the floor for working at all, not a speed promise: measure your model on your hardware.

## VRAM placement (mutually exclusive group)

| Flag         | Help text, paraphrased                                                                 |
| ------------ | -------------------------------------------------------------------------------------- |
| `--gpu-only` | keep and run everything (including text encoders) on the GPU                           |
| `--highvram` | by default models are unloaded to CPU memory after use; this keeps them in GPU memory  |
| `--lowvram`  | does nothing when dynamic VRAM is on; otherwise makes the text encoders run on the CPU |
| `--novram`   | "when lowvram isn't enough"                                                            |
| `--cpu`      | everything on the CPU (slow)                                                           |

Without any of these the default memory manager runs. **Dynamic VRAM** is enabled unless you pass `--highvram`, `--gpu-only`, `--novram`, `--cpu` or `--disable-dynamic-vram` (`enables_dynamic_vram()` in `cli_args.py`); `--enable-dynamic-vram` turns it on where it is not the default. So on a current release the old advice "use `--lowvram` on small GPUs" mostly does nothing. Try the default first.

## Sharing the GPU with other processes

| Flag                                       | Use                                                                                                                                        |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `--reserve-vram GB`                        | VRAM to leave for the OS and other software; "by default some amount is reserved depending on your OS". Set it when an LLM shares the card |
| `--vram-headroom GB`                       | extra headroom DynamicVRAM keeps free "even counting VRAM from other apps"                                                                 |
| `--disable-smart-memory`                   | aggressively offload to RAM instead of keeping models in VRAM                                                                              |
| `--cuda-device 0` / `CUDA_VISIBLE_DEVICES` | pin the instance to a GPU                                                                                                                  |
| `--disable-nvml-pressure`                  | DynamicVRAM uses CUDA instead of NVML for memory pressure (try if NVML misreads a shared or virtualised GPU)                               |

A practical rule for GPU plus LLM hosts: do not run both at peak. Either keep them in separate swap groups (llama-swap, `combos/llama-swap-litellm.md`) or reserve explicitly and test with the LLM at its real context length. On unified memory (DGX Spark) the pool is shared, so one overrun can kill the LLM process too; budget with `self-hosted-genmedia`'s memory-planning reference.

## Releasing memory without a restart

```bash
curl -fsS -X POST http://127.0.0.1:8188/free -H 'Content-Type: application/json' \
  -d '{"unload_models": true, "free_memory": true}'
# or: comfy free   (comfy-cli; --free-memory also resets the executor cache)
```

The flags are consumed by the prompt worker between jobs. Stopping the process (llama-swap TTL or unload) frees everything.

## RAM and node caching (mutually exclusive group)

| Flag                    | Meaning                                                                                                                                                                                                                                  |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--cache-ram [GB [GB]]` | RAM-pressure caching, **the default mode**. First value is the active-cache headroom threshold, second the inactive-cache and pin threshold. Defaults: active 10% of system RAM (min 2 GB, max 10 GB), inactive 100% of RAM (max 128 GB) |
| `--cache-classic`       | the old, aggressive caching                                                                                                                                                                                                              |
| `--cache-lru N`         | keep up to N node results; may use more RAM or VRAM                                                                                                                                                                                      |
| `--cache-none`          | lowest memory, but executes every node on every run                                                                                                                                                                                      |
| `--high-ram`            | implies classic caching; helps where paging is preferred over reloading models                                                                                                                                                           |

Other memory knobs: `--disable-pinned-memory`, `--disable-mmap` (do not mmap safetensors), `--mmap-torch-files`, `--async-offload [N]` (default 2 streams, on by default on NVIDIA) and `--disable-async-offload`, `--fast-disk` (disk-backed dynamic loading over unpinned RAM; can help with fast NVMe) and `--disable-fast-disk`.

## Precision

`--force-fp16`, `--force-fp32`, `--fp16-unet`, `--bf16-unet`, `--fp8_e4m3fn-unet`, `--fp8_e5m2-unet` and similar per-component flags (`--fp16-vae`, `--bf16-vae`, `--fp32-vae`, `--fp16-text-enc`, `--bf16-text-enc`, `--fp8_e4m3fn-text-enc`) override dtypes. Help text warns `--fp16-vae` "might cause black images". `--cpu-vae` moves only the VAE to the CPU, a common fix for decode out-of-memory errors.

## Speed flags (use deliberately)

- `--fast [feature ...]`: "untested and potentially quality deteriorating"; with no arguments it enables all of `fp16_accumulation`, `fp8_matrix_mult`, `cublas_ops`, `autotune`. Naming features enables only those. The help says using it "might crash your comfyui". Do not enable it on a production endpoint without a before/after quality check.
- Attention: `--use-pytorch-cross-attention`, `--use-sage-attention`, `--use-flash-attention`, `--use-split-cross-attention`, `--use-quad-cross-attention`, `--use-ck-attention` (mutually exclusive). `--disable-xformers` disables xformers.
- `--deterministic` uses slower deterministic algorithms; it does not guarantee identical images.
- `--disable-cuda-graphs`, `--disable-comfy-compiler` and `--assert-graph-breaks` control the model compiler.
- ROCm only (README): `PYTORCH_TUNABLEOP_ENABLED=1` may speed things up at the cost of a very slow first run.

## How to measure

```bash
# Before and after: VRAM and RAM via the API
curl -fsS http://127.0.0.1:8188/system_stats | jq '{ram_free:.system.ram_free, vram:[.devices[]|{name,vram_total,vram_free}]}'
nvidia-smi --query-gpu=memory.used,memory.total --format=csv -l 2     # watch while a job runs
time scripts/comfy-run.sh workflow_api.json                            # end to end, includes model load on the first run
```

Run the same job twice: the first includes the model load, the second shows steady state and cached nodes. Record both when you budget memory next to LLMs.
