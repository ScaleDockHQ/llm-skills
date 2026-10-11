# Engines on DGX Station

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

| Engine            | Status on Station                                                           | Notes                                                                                                    |
| ----------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| vLLM              | NVIDIA playbook supports one Station                                        | Recommended image `nvcr.io/nvidia/vllm:26.01-py3` at the playbook date; pin the GB300 GPU. Skill: `vllm` |
| SGLang            | Listed in the Development Guide as supported and preinstalled-class tooling | Skill: `sglang`                                                                                          |
| TensorRT-LLM      | Listed in the core AI libraries                                             | Skill: `tensorrt-llm`                                                                                    |
| Ollama, llama.cpp | Ollama named in the guide                                                   | Skills: `ollama`, `llama-cpp`                                                                            |

All images must be arm64 and CUDA 13 capable (Blackwell Ultra). Prefer NGC images. FP4 (NVFP4) is a hardware strength; engine support differs, so check each engine skill.

Gateway and exposure: `self-hosted-llms`, `llama-swap`, `litellm`.

## Sources

- <https://build.nvidia.com/station/vllm>
- <https://docs.nvidia.com/dgx/dgx-station-development-guide/Intro.html>
