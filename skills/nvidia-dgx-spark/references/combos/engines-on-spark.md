# Engines on DGX Spark

> Verified against dgx-spark-playbooks (vllm 06/12/2026, sglang 04/28/2026, trt-llm 04/28/2026, llama-cpp, ollama 10/12/2025), Docker Hub, ghcr.io manifests, 2026-10-11

NVIDIA publishes a playbook per engine at <https://github.com/NVIDIA/dgx-spark-playbooks> (<https://build.nvidia.com/spark>). Engine depth is in the product skills; this table records what NVIDIA documents for GB10.

| Engine       | Image or install NVIDIA documents                                                                                                                                                                                            | Multi-node on Spark                                                 | Product skill  |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | -------------- |
| vLLM         | `nvcr.io/nvidia/vllm:<tag>` (NGC; playbook pins `26.05-py3` for the cluster flow); model-specific recipes from HF model cards                                                                                                | Yes: Ray cluster via `run_cluster.sh` over the ConnectX-7 interface | `vllm`         |
| SGLang       | `lmsysorg/sglang:latest-cu130` (CUDA 13.0); older `lmsysorg/sglang:spark` tag last updated 2025-11-06                                                                                                                        | Playbook covers single node; multi-node is in the product skill     | `sglang`       |
| TensorRT-LLM | `nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc13` (single node), `1.3.0rc5` appears in the multinode section; check NGC for current                                                                                            | Yes: multinode playbook section                                     | `tensorrt-llm` |
| llama.cpp    | Build from source: `cmake -B build -DGGML_NATIVE=ON -DGGML_CUDA=ON -DGGML_CURL=ON -DGGML_RPC=ON -DCMAKE_CUDA_ARCHITECTURES=121a-real`; or `ghcr.io/ggml-org/llama.cpp:server-cuda13` (multi-arch, amd64 and arm64, verified) | RPC backend (`-DGGML_RPC=ON`)                                       | `llama-cpp`    |
| Ollama       | `curl -fsSL https://ollama.com/install.sh \| sh` (playbook uses NVIDIA Sync custom app)                                                                                                                                      | No                                                                  | `ollama`       |
| llama-swap   | `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (multi-arch, verified) or `linux_arm64` binary                                                                                                                                | Wrapper scripts                                                     | `llama-swap`   |
| TensorFold   | see product skill                                                                                                                                                                                                            | Dual-node                                                           | `tensorfold`   |

Other playbooks exist for NIM (`nim-llm`), NVFP4 quantization, speculative decoding, LM Studio, Open WebUI, Unsloth, LLaMA Factory, ComfyUI and more; list them with `gh api repos/NVIDIA/dgx-spark-playbooks/contents/nvidia --jq '.[].name'`.

## Choosing quickly

- Model plus KV fits one node, interactive use: llama.cpp (GGUF) or vLLM/SGLang with NVFP4 or FP8 checkpoints from NVIDIA's model cards.
- Needs 256 GB or tensor parallel: vLLM (Ray) or TensorRT-LLM multinode, see `dual-node-cluster.md`.
- Many models, swap on demand: llama-swap in front of any of them.

## Rules

- Prefer NGC or tags that state CUDA 13 or GB10 support; verify arm64 with `docker manifest inspect <image> | jq -r '.manifests[].platform.architecture'`.
- Prefer pinned tags over `latest`; the moving `latest-cu130` image changed on 2026-10-01.
- Memory fractions follow `../memory.md`.

## Sources

- <https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia>
- <https://hub.docker.com/r/lmsysorg/sglang/tags>
