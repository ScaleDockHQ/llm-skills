# Intel GPU

> Verified against vLLM docs (Intel XPU), llama.cpp docs/backend/SYCL.md, intel/llm-scaler README, OpenVINO Model Server docs 2026, 2026-10-11

## Drivers and groups

Install Intel GPU drivers from Intel's driver pages (data center: `dgpu-docs.intel.com`; client Arc and iGPU: the client driver overview). Add the user to the `render` and `video` groups (`sudo usermod -aG render $USER`), then log in again. Check with `ls -l /dev/dri`, `clinfo -l` and, after `source /opt/intel/oneapi/setvars.sh`, `sycl-ls` (expect `[level_zero:gpu]` entries).

## vLLM XPU

Supported hardware per the vLLM docs: Intel Data Center GPU and Intel Arc GPU. The `vllm-xpu-kernels` wheel is Python 3.12 only. From vllm-xpu-kernels v0.1.10 the docs recommend a compute runtime 26.18 driver.

Container (official image `vllm/vllm-openai-xpu`, `latest` is stable from v0.26.0):

```bash
docker run --rm --network=host --device /dev/dri:/dev/dri \
  -v /dev/dri/by-path:/dev/dri/by-path -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN --ipc=host --privileged \
  vllm/vllm-openai-xpu:latest --model Qwen/Qwen3-0.6B
```

`HF_TOKEN` is passed by name so the value stays in your environment. The docs use `--privileged`; weigh that on shared hosts. Wheels: `uv pip install vllm --extra-index-url https://wheels.vllm.ai/nightly/xpu --extra-index-url https://download.pytorch.org/whl/xpu --index-strategy unsafe-best-match` (both indexes are needed; the XPU index carries a `triton==3.7.2+xpu` shim).

## llm-scaler (Arc Pro B60 and B70)

Intel's `intel/llm-scaler` targets Arc Pro B60/B70 with vLLM, ComfyUI, SGLang Diffusion and Xinference. Images: `intel/llm-scaler-vllm` (latest named in the README: `0.26.0-b2`) and `intel/llm-scaler-omni`. Features listed: INT4 and FP8 online quantization, tensor, pipeline and data parallel, embedding and reranker models. Run flags and model-specific commands are in the repo's `vllm/README.md`; read it before running.

## llama.cpp SYCL

Supported: Intel Flex and Arc series, built-in Arc GPUs, and Core iGPUs (11th gen and newer). Verified on Linux: Ubuntu 22.04, Fedora Silverblue 39, Arch. Verified devices include Arc A770/A750/A730M, Arc B580 and built-in Arc in Meteor Lake, Arrow Lake and Lunar Lake.

```bash
source /opt/intel/oneapi/setvars.sh
cmake -B build -DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DGGML_SYCL_F16=ON
cmake --build build --config Release -j
./build/bin/llama-ls-sycl-device                  # list devices
export ONEAPI_DEVICE_SELECTOR="level_zero:0"      # pick one GPU
```

Select devices with `ONEAPI_DEVICE_SELECTOR` or `--device SYCL0,SYCL1`; `-sm none -mg 0` pins one GPU. Server flags: see the `llama-cpp` skill. The docs say oneAPI 2026.1 speeds up the SYCL build (one measurement on Arc B570: prompt processing 1331 vs 434 t/s against the 2025.3 build).

## OpenVINO

OpenVINO Model Server (`docs.openvino.ai/2026/model-server`) serves OpenVINO-format LLMs with OpenAI-style endpoints; the LLM servable's `device` option accepts `CPU` or `GPU` (default `CPU`). Use it when you have an OpenVINO export or the target is mixed CPU/GPU/NPU. Check the docs for the image tag and the exact model-preparation steps before use.

## Choosing

- Many concurrent users on Arc Pro: `intel/llm-scaler-vllm` or vLLM XPU.
- Single user, GGUF models, laptops, iGPU: llama.cpp SYCL (Vulkan is an alternative; see `llama-cpp`).
- OpenVINO models or NPU/CPU mix: OpenVINO Model Server.
