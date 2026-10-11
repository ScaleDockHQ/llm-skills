# Engines on datacenter GPUs

> Verified against NVIDIA Data Center GPU Driver 580.178.04 release notes and NVIDIA product pages, 2026-10-11

| Goal                                           | Engine                      | Skill                   |
| ---------------------------------------------- | --------------------------- | ----------------------- |
| General high-throughput serving                | vLLM                        | `vllm`                  |
| Structured output, prefix caching              | SGLang                      | `sglang`                |
| Maximum NVIDIA-specific performance (FP8, FP4) | TensorRT-LLM                | `tensorrt-llm`          |
| Kubernetes scheduling                          | GPU Operator                | `nvidia-gpu-operator`   |
| Multi-node prefill/decode split                | see `disaggregated-serving` | `disaggregated-serving` |

Use NGC or engine-published images built for your CUDA major (13 with R580). Hopper runs FP8; Blackwell adds FP4 if the engine build supports it. Gateway and exposure: `self-hosted-llms`, `litellm`.

## Sources

- <https://docs.nvidia.com/datacenter/tesla/drivers/supported-drivers-and-cuda-toolkit-versions.html>
