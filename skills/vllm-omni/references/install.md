# vLLM-Omni: install

> Verified against vLLM-Omni v0.30.0 (vLLM 0.30.0), 2026-10-11

Upstream: [vllm-project/vllm-omni](https://github.com/vllm-project/vllm-omni) (Apache-2.0, not archived, last push 2026-10-11). Latest stable **v0.30.0** (2026-09-25); `v0.31.0rc1` is a pre-release. PyPI has `vllm-omni` 0.30.0 (Python `>=3.10,<3.14` metadata, but the docs require 3.12) and Docker Hub has `vllm/vllm-omni:v0.30.0`. The in-repo install docs at that tag still show 0.28.0 in some pre-built examples; the 0.30.0 artifacts exist, so use 0.30.0 and keep the pair matched.

## Requirements

- Linux only; Windows is not natively supported. Python **3.12**.
- NVIDIA GPU with compute capability 7.0 or higher (V100, T4, RTX 20xx, A100, L4, H100 and up). AMD ROCm and Intel XPU have their own sections in the docs; MThreads MUSA and Ascend NPU exist too.
- vLLM and vLLM-Omni must be the same major.minor. A mismatch prints a warning on import; fix it before debugging anything else. The `vllm` command owns the CLI and hands `--omni` to vLLM-Omni, so `vllm` and `vllm-omni` must be in the same environment.
- Use a **fresh** environment. vLLM compiles kernels for one CUDA and PyTorch pair; conda's statically linked NCCL also causes trouble.
- v0.30.0 of vLLM ships CUDA 13.0 binaries by default (check the NVIDIA driver supports that); for another CUDA or an existing PyTorch, build vLLM from source.

## NVIDIA wheels (pin both)

```bash
uv venv --python 3.12 --seed && source .venv/bin/activate
uv pip install vllm==0.30.0 --torch-backend=auto
uv pip install vllm-omni==0.30.0          # add 'vllm-omni[demo]==0.30.0' for the Gradio demos
vllm --version
```

Upstream's quickstart installs vLLM-Omni from source (`git clone` then `uv pip install -e .`) because it moves quickly; use that only when you need unreleased code, and then check out a tag that matches the vLLM version.

## ROCm

Source flow in the docs: `uv pip install vllm==0.30.0+rocm723 --extra-index-url https://wheels.vllm.ai/rocm/0.30.0/rocm723`, then clone the repo and `VLLM_OMNI_TARGET_DEVICE=rocm uv pip install -e .` (or with `--no-build-isolation`); `onnxruntime` must be swapped for `onnxruntime-rocm`. The Docker image is `vllm/vllm-omni-rocm`; on 2026-10-11 no `v0.30.x` tag was listed there and the docs' example uses `v0.28.0`, so check the tags before relying on it. Run it with `--device /dev/kfd --device /dev/dri --group-add=video --ipc=host --cap-add=SYS_PTRACE --security-opt seccomp=unconfined`.

## Intel XPU

The docs recommend the Docker build from the repo (`docker/` Dockerfile for XPU, base image vLLM v0.30.0 by default); there are no pre-built wheels.

## Docker (NVIDIA)

```bash
docker run --runtime nvidia --gpus all \
  -v "${HF_HOME:-$HOME/.cache/huggingface}":/root/.cache/huggingface \
  --env HF_TOKEN \
  -p 127.0.0.1:8091:8091 --ipc=host \
  vllm/vllm-omni:v0.30.0 \
  vllm serve Tongyi-MAI/Z-Image-Turbo --omni --port 8091
```

- The CUDA image has **no default entrypoint**: write `vllm serve ... --omni` after the image name. The ROCm image passes `--model ... --omni` directly as in the docs' example.
- Tags: `vX.Y.Z` (multi-arch with `-x86_64` and `-aarch64` suffixes), `nightly` (rolling, main) and `nightly-<commit>` (the newest 14 are kept). Pin a version tag, or a commit tag if you need nightly.
- `--env HF_TOKEN` forwards the host variable without writing it in the command. Mount the cache to avoid re-downloading.
- Build your own: `DOCKER_BUILDKIT=1 docker build -f docker/Dockerfile.cuda --build-arg BASE_IMAGE=vllm/vllm-openai:v0.30.0 -t vllm-omni-cuda .` from the repo.

## Verify

```bash
pip list 2>/dev/null | grep -Ei "^(vllm|vllm-omni) "
vllm --version
```
