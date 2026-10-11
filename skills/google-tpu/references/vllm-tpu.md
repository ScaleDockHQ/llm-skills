# vLLM on TPU (vllm-tpu, tpu-inference)

> Verified against vllm-project/tpu-inference v0.31.0 (PyPI vllm-tpu 0.31.0), docs.vllm.ai/projects/tpu (Installation, Quickstart, Recommended models, Features), 2026-10-11

vLLM TPU is vLLM plus the `tpu-inference` hardware plugin, which lowers JAX and PyTorch models through one XLA path. It keeps the vLLM CLI and OpenAI API. Engine flags and tuning are in the `vllm` skill; this file covers what differs on TPU.

## Install

Python 3.11 or newer (docs use 3.12). On a TPU VM:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh && source "$HOME/.local/bin/env"
uv venv vllm_env --python 3.12 && source vllm_env/bin/activate
uv pip install "vllm-tpu==0.31.0"          # pin; latest verified release
```

Verify (prints versions and the chips JAX sees):

```bash
python -c '
import jax, vllm, importlib.metadata
from vllm.platforms import current_platform
print(vllm.__version__, importlib.metadata.version("tpu_inference"))
print(current_platform.get_device_name()); print(jax.devices())'
```

Expect a device name such as `TPU V6E` and one `TpuDevice` per chip. If `jax.devices()` shows CPU only, the TPU is not visible (see `troubleshooting.md`).

## Docker

Release tags on Docker Hub include `latest`, `v0.31.0`, `v0.30.0`, `v0.29.0`, plus `nightly` and dated nightlies. Pin a version tag.

```bash
export DOCKER_URI=vllm/vllm-tpu:v0.31.0
sudo docker run -it --rm --name "$USER-vllm" --privileged --net=host \
  -v /dev/shm:/dev/shm --shm-size 150gb -p 8000:8000 \
  --entrypoint /bin/bash "$DOCKER_URI"
```

`--privileged`, `--net=host` and the large `--shm-size` are what the project documents for TPU access and shared memory. Use the same image on GKE.

## Serve

```bash
export HF_TOKEN="$(cat ~/.config/huggingface/token)"   # gated models only; never echo it
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --download-dir /tmp/hf \
  --tensor-parallel-size 1 \
  --max-model-len 2048
curl -s localhost:8000/v1/models | jq -r '.data[].id'
```

Choose `--tensor-parallel-size` equal to the chips you want to shard across (for example 8 on a `v6e-8`). Prefer models from the recommended list (below); start with a modest `--max-model-len`, then raise it while watching HBM.

## TPU-specific environment variables

From `tpu_inference/envs.py` (v0.31.0). Treat these as tuning and debugging knobs, not required settings:

| Variable                       | Purpose                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------ |
| `MODEL_IMPL_TYPE`              | Model implementation: `auto` (default), `vllm`, `flax_nnx`, `jetpack`          |
| `SKIP_JAX_PRECOMPILE`          | Skip startup precompilation (faster boot, slower first requests); default off  |
| `VLLM_XLA_CHECK_RECOMPILATION` | Fail on XLA recompilation during execution, useful to find unbucketed shapes   |
| `USE_2D_TP`                    | 2D tensor parallelism over multiple axes                                       |
| `NEW_MODEL_DESIGN`             | Experimental model design                                                      |
| `JAX_PLATFORMS`, `TPU_*`       | Platform and multi-host wiring (`TPU_MULTIHOST_BACKEND`, `TPU_WORKER_ID`, ...) |

## Supported models and features

The project keeps matrices in `docs/` (rendered at https://docs.vllm.ai/projects/tpu/en/latest/recommended_models/ and `.../features/`). At the time of writing they mark as passing, among others: Llama 3.1 8B and 3.3 70B, Qwen3 4B, 32B and 30B-A3B, Gemma 3 27B, Gemma 4 variants, gpt-oss-120b, DeepSeek-R1 and Kimi-K2.6. Many models are listed as untested. The feature matrix tracks, per backend (Flax or Torchax): async scheduler, chunked prefill, DCN-based prefill and decode disaggregation, KV cache offload, LoRA, parallelism (TP, DP, EP, PP) and quantization. Multi-host entries are often untested, so confirm there before promising a shape.

Always re-read the matrices; they change with each release.

## Recipes and multi-host

Tested end-to-end recipes live in https://github.com/AI-Hypercomputer/tpu-recipes: Trillium (v6e) on Compute Engine, Ironwood (TPU7x) on GKE. For multi-host, follow the recipe for the exact model and slice, then validate with a small load test.

## Warm-up and compile behaviour

XLA compiles per input shape. vLLM TPU precompiles bucketed shapes at startup unless `SKIP_JAX_PRECOMPILE` is set, so startup can take minutes. After a deploy, send representative request lengths before measuring latency or admitting traffic.

## Gateway and clients

The server is an OpenAI-compatible endpoint on port 8000. For LiteLLM use `hosted_vllm/<model>` with `api_base: http://<host>:8000/v1` (see the `litellm` skill). Keep the endpoint private; add `--api-key` or put an authenticating proxy in front.
