# Engines on RTX PRO Blackwell

> Verified against NVIDIA RTX PRO Blackwell datasheets, CUDA Toolkit 13.4 Update 1 and driver 580 README, 2026-10-11

| Need                              | Engine                                           | Skill                 |
| --------------------------------- | ------------------------------------------------ | --------------------- |
| Single user, GGUF, easy           | llama.cpp, Ollama                                | `llama-cpp`, `ollama` |
| High throughput serving, batching | vLLM, SGLang                                     | `vllm`, `sglang`      |
| EXL3 quantised, one or few cards  | ExLlamaV3 (TabbyAPI)                             | `exllamav3`           |
| Multiple services on one card     | MIG (6000) or separate containers with VRAM caps | this skill            |

Requirements for all of them: open kernel modules, a Blackwell-capable build (CUDA 12.8+, sm_120), and enough VRAM headroom. FP4 (NVFP4) is a hardware feature of 5th-gen Tensor Cores; engine support varies by version, so check each engine skill before relying on it.

Gateway and exposure: `self-hosted-llms`, `litellm`.

## Sources

- <https://docs.nvidia.com/cuda/archive/12.8.2/blackwell-compatibility-guide/index.html>
