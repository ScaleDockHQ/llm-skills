# AMD Instinct and Radeon with ROCm

> Verified against vLLM v0.31.0 (`docs/getting_started/installation/gpu.rocm.inc.md`, `vllm/envs.py`, `docs/deployment/docker.md`), 2026-10-11

Not run on AMD hardware by this skill.

Applies to MI200/MI300/MI350 and the Radeon and Ryzen AI parts listed in `references/install.md`.

## Start

```bash
docker run --rm --group-add=video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --device /dev/kfd --device /dev/dri --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN \
  vllm/vllm-openai-rocm:v0.31.0 --model Qwen/Qwen3-0.6B --max-model-len 16384
```

- The entrypoint is `vllm serve`, so the first argument after the image is the model or a flag.
- Pass `HF_TOKEN` from the environment (`-e HF_TOKEN` with no value forwards it), never inline.
- `--ipc=host` or `--shm-size` is needed for tensor parallel.
- Image family: `vllm/vllm-openai-rocm`; the older `rocm/vllm` and `rocm/vllm-dev` images are deprecated.
- Python wheels are Python 3.12 only; see `references/install.md` for the `rocm723` wheel index and the
  `libcudart.so` symptom on other Python versions.

## Backends

- Attention backend values on ROCm (v0.31.0): `TRITON_ATTN`, `ROCM_ATTN`, `ROCM_AITER_FA`,
  `ROCM_AITER_UNIFIED_ATTN`, and MLA variants `TRITON_MLA`, `ROCM_AITER_MLA`, `ROCM_AITER_TRITON_MLA`.
  Select with `--attention-backend`. Read the startup log first.
- AITER kernels: `VLLM_ROCM_USE_AITER=1` is the master switch (default `False`). With it on, sub-switches such
  as `VLLM_ROCM_USE_AITER_MOE`, `_LINEAR`, `_RMSNORM`, `_MLA` and `_MHA` default to `True`; turn individual ones off
  to bisect a problem. `VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION` defaults to `False`.
- AITER versions are validated per vLLM release; building AITER yourself is documented upstream and the validated
  commit is in `docker/Dockerfile.rocm_base`.
- Quantization: FP8 (e4m3) on MI300 and newer, Quark (AMD) checkpoints. AWQ and GPTQ are not supported on AMD
  per the upstream hardware table. `--kv-cache-dtype fp8` is supported on ROCm.

## Multi-GPU and multi-node

- TP/PP/EP flags are the same as CUDA (`references/parallelism-multinode.md`); collectives run on RCCL.
  `NCCL_*` variable names still apply to RCCL, but which are honored is unverified here.
- Pick GPUs with `HIP_VISIBLE_DEVICES` (general ROCm, not described in vLLM docs: unverified for vLLM).
- Multi-node recipes use the same `--nnodes/--node-rank` or Ray flows; the upstream guidance for InfiniBand
  uses NCCL variables and `--privileged`; test your fabric with a small model first.

## Pitfalls

- `libcudart.so: cannot open shared object file`: you installed a CUDA wheel (wrong Python or index).
- Wheel glibc: the install page says 2.35, the v0.31.0 wheel name says 2.39. Check your distro.
- Gated model downloads fail without `HF_TOKEN`; ROCm images do not change that.
- `rocm-smi` and `amd-smi` show GPU memory; compare with the `GPU KV cache size` line in the vLLM log.
- Profiling or tracing GPU counters from `run_cluster.sh` needs `--cap-add=CAP_SYS_ADMIN`.
