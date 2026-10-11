# Containers and engines on Instinct

> Verified against ROCm 10.1.0 compatibility matrix, vLLM docs (docs.vllm.ai installation, AMD ROCm section), Docker Hub tags `vllm/vllm-openai-rocm` and `rocm/vllm`, 2026-10-11

Engine flags live in the product skills. This page covers what is specific to running them on Instinct.

## Run flags

```bash
docker run --rm --group-add=video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --device /dev/kfd --device /dev/dri --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN \
  vllm/vllm-openai-rocm:v0.31.0 --model Qwen/Qwen3-0.6B --max-model-len 16384
```

- `--device /dev/kfd --device /dev/dri` is the minimum GPU exposure. `--group-add=video` (add `--group-add=render` if your render node is group-owned) gives the container user access.
- `--ipc=host` (or a large `--shm-size`) is needed for tensor parallelism. `--cap-add=SYS_PTRACE --security-opt seccomp=unconfined` follow the vLLM docs; drop them if your policy forbids them and the engine still starts.
- To restrict GPUs use `HIP_VISIBLE_DEVICES` (ROCm's counterpart of `CUDA_VISIBLE_DEVICES`) or pass only specific `/dev/dri/renderD*` nodes.
- Pass `HF_TOKEN` as `-e HF_TOKEN` with no value so it is forwarded from your environment and never printed.
- Bind to `127.0.0.1` unless a gateway fronts it.

Check inside the container before loading a model:

```bash
docker run --rm --device /dev/kfd --device /dev/dri --group-add=video --entrypoint rocminfo vllm/vllm-openai-rocm:v0.31.0 | grep -E 'Name:\s+gfx' | sort -u
```

## Images and wheels

| Engine           | Source                                                                                                                              | Notes                                                                                                                                                                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM             | `vllm/vllm-openai-rocm:v0.31.0` (and `:latest`, `:nightly`) on Docker Hub                                                           | The vLLM project's official ROCm image. Entry point is `vllm serve`. Tags with a `-base` suffix exist.                                                                                                                                 |
| vLLM (AMD-built) | `rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0`                                                                | Tag matches the ROCm 10.1.0 validated stack (PyTorch 2.13.0, vLLM 0.29.0); pushed 2026-10-05. The vLLM install page calls the `rocm/vllm` images deprecated, so prefer the official image unless you need AMD's exact validated stack. |
| vLLM wheels      | `https://wheels.vllm.ai/rocm/`                                                                                                      | Python 3.12 only; other Python versions silently fall back to the CUDA wheel and fail with `libcudart.so: cannot open shared object file`. Pin the exact version and variant index from the vLLM install page.                         |
| SGLang           | see the `sglang` skill                                                                                                              | AMD validated SGLang 0.5.18 with ROCm 10.1.0.                                                                                                                                                                                          |
| llama.cpp        | release asset `llama-<tag>-bin-ubuntu-rocm-10.0-x64`, image `ghcr.io/ggml-org/llama.cpp:server-rocm`, or build with `-DGGML_HIP=ON` | See the `llama-cpp` skill. The vLLM and llama.cpp docs differ on which ROCm version they target; check the engine startup log.                                                                                                         |

vLLM docs state: ROCm 6.3 or above, MI350 needs ROCm 7.0 or above; the engine bundles its own PyTorch, so do not replace it. Pre-built wheels exist for specific ROCm variants (for example `rocm700`, `rocm721`); the index lists which variants a vLLM release has.

## Engine checks on Instinct

- Read the startup log for the attention backend line before tuning. vLLM's ROCm backends include `TRITON_ATTN`, `ROCM_ATTN`, `ROCM_AITER_FA` and MLA variants; AITER kernels need `VLLM_ROCM_USE_AITER=1` (default off). Details in the `vllm` skill (`references/combos/amd-instinct-rocm.md`).
- FP8 (e4m3) and Quark checkpoints are the supported low-precision paths on MI300 and newer; AWQ and GPTQ are not supported on AMD per the vLLM hardware table.
- Memory: compare `amd-smi metric` (VRAM used) with the engine's reported KV cache size.

## Multi-GPU in a container

Add every GPU's node (`--device /dev/dri` covers all), keep `--ipc=host`, set `--tensor-parallel-size` to the GPUs you expose, and run the RCCL test in `multi-gpu-and-partitioning.md` first. For multi-node, use the `multi-node-inference` skill and an RDMA-capable fabric; test the fabric with a small model before the large one.
