---
name: choosing-inference-engine
description: Choose an LLM inference engine from hardware, model format, features and concurrency, with a decision flow and an engine matrix for vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, TensorFold and ExLlamaV3. Use when asked which engine to run, vLLM vs SGLang vs llama.cpp vs Ollama vs TensorRT-LLM vs ExLlamaV3 vs TensorFold, which engine serves GGUF, EXL3, NVFP4, FP8, AWQ or GPTQ, which engine runs on DGX Spark, RTX, Apple Silicon, AMD ROCm or Intel, or how to pick for many users. For hardware sizing use choosing-hardware. For where to host use choosing-llm-hosting.
license: MIT
compatibility: Read-only discovery uses a POSIX shell with optional nvidia-smi, rocm-smi, system_profiler, lscpu and curl. Any install or service change needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Choosing an Inference Engine

Pick one inference engine (or a short list with a fallback) for a given machine, model format, feature set and number of concurrent users, and say why.

**Scope:** the cross-engine decision. Install, flags and tuning stay in the engine product skills. Where to host stays in `choosing-llm-hosting`. Sizing the machine stays in `choosing-hardware`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints secrets.

```bash
uname -sm
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv,noheader 2>/dev/null
rocm-smi --showproductname --showmeminfo vram 2>/dev/null | head -20
system_profiler SPHardwareDataType 2>/dev/null | grep -E 'Chip|Memory'
lscpu 2>/dev/null | grep -E 'Model name|Flags' | head -2
command -v vllm sglang trtllm-serve llama-server ollama tensorfold tabbyapi 2>/dev/null
```

Ask the user only what discovery cannot show: the model (or size class) and its weight format, how many people or agents call it at once, which features are required (tool calls, structured output, vision, LoRA, long context), and whether quality drift from quantization is acceptable.

## Decision flow

1. **Hardware family.** Use the first row that matches.
   - Apple Silicon: `llama.cpp` (Metal) or `Ollama` first. `TensorFold` only if the model is on its qualified list. MLX and LM Studio are in `references/adjacent-engines.md`. vLLM and SGLang list Apple Silicon support, but check maturity before relying on it.
   - CPU only, or a GPU much smaller than the model: `llama.cpp` (GGUF, CPU+GPU hybrid, MoE expert offload). `ExLlamaV3` also offloads MoE to CPU.
   - AMD Radeon, Ryzen AI (Strix Halo) or Instinct: `llama.cpp` (HIP or Vulkan), `Ollama` (ROCm v7 or Vulkan), `vLLM` (ROCm). `SGLang` lists Instinct MI300X to MI355X. TensorRT-LLM and TensorFold are NVIDIA or Apple only.
   - Intel Arc or Xeon: `llama.cpp` (SYCL or Vulkan), `Ollama` (Vulkan), `vLLM` (XPU, CPU), `SGLang` (XPU, CPU).
   - NVIDIA: continue at step 2.
2. **Model format you already have or want.**
   - GGUF -> `llama.cpp` or `Ollama`. vLLM can load GGUF but its docs treat the other formats as first-class.
   - EXL3 -> `ExLlamaV3` (through TabbyAPI). Other engines do not list EXL3.
   - Hugging Face safetensors in BF16, FP8, NVFP4, AWQ or GPTQ -> `vLLM`, `SGLang` or `TensorRT-LLM`.
   - MLX 4-bit checkpoints -> `TensorFold` on its qualified models, or MLX tooling.
   - No quant yet: choose the engine for hardware and concurrency first, then produce the quant it likes with `model-quantization`.
3. **Concurrency.** Compare the real peak, not the average.
   - 1 user or 1 agent -> `llama.cpp`, `Ollama`, `ExLlamaV3` or `TensorFold`. Lowest setup cost.
   - A few users -> `llama.cpp` with `--parallel`, or `vLLM` or `SGLang` if the model fits their kernels.
   - Many users, agents or batch jobs -> `vLLM`, `SGLang` or `TensorRT-LLM` (continuous batching, prefix caching, parallelism).
   - Ollama defaults to one parallel request per model (`OLLAMA_NUM_PARALLEL`), so raise it on purpose and budget the extra KV memory.
4. **Features that exclude engines.** Check the feature matrix in `references/engine-matrix.md`: speculative decoding, structured outputs, multi-LoRA, prefill/decode disaggregation, multi-node, quantized KV cache, vision.
5. **Newest model architecture.** New models land first in `vLLM`, `SGLang` and `llama.cpp`. Check the engine's supported-models page for the exact architecture string before committing. `TensorRT-LLM` and `TensorFold` support a narrower list.
6. **Multi-node or datacenter scale.** `vLLM`, `SGLang` or `TensorRT-LLM` as the worker engine, with NVIDIA Dynamo above them for disaggregated serving (see `references/adjacent-engines.md`).
7. **Write the decision.** Record the winner, the runner-up, the one fact that decided it and the fact that would reverse it. Keep it next to the hosting decision.

## Shortlist by situation

| Situation                                                     | First choice                      | Fallback                          |
| ------------------------------------------------------------- | --------------------------------- | --------------------------------- |
| Laptop or Mac, one user, GGUF                                 | `llama.cpp` or `Ollama`           | MLX tooling                       |
| Single consumer NVIDIA GPU, one user, fit as much as possible | `ExLlamaV3` (EXL3) or `llama.cpp` | `Ollama`                          |
| DGX Spark or Blackwell workstation, several clients           | `vLLM` or `SGLang`                | `llama.cpp`, `TensorRT-LLM`       |
| Server GPUs (Hopper, Blackwell), many users                   | `vLLM`, `SGLang`, `TensorRT-LLM`  | Dynamo on top at multi-node scale |
| AMD Instinct, many users                                      | `vLLM` (ROCm)                     | `SGLang`                          |
| Qualified model on Apple Silicon or GB10, exact decoding      | `TensorFold`                      | `llama.cpp`                       |
| Model bigger than VRAM, MoE                                   | `llama.cpp` expert offload        | `ExLlamaV3` CPU offload           |

These are starting points, not benchmarks. Measure on the real model with `scripts/bench.sh` from `self-hosted-llms`, or the engine's own benchmark, before committing.

## Rules

- **Ask before changing the system.** Installs, services, containers and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and support lists come from upstream docs read on the writing date. The engine matrix is dated; re-check the support page for your exact GPU and model before buying or building.
- **Gate numerics changes with `llm-evals`.** Quantization (FP8, NVFP4, AWQ, GPTQ, GGUF, EXL3), KV-cache quantization and speculative decoding can change outputs. Run the same eval set before and after. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- **Do not trust a headline tok/s number.** Compare engines on the same model, quant, context length, batch and sampling settings.
- **Prefer one engine per model.** Mixed fleets cost operations time. Swap per model only when the matrix forces it.

## Reference index

- `references/engine-matrix.md`: engine by hardware, by model format and quantization, and by feature. Load for steps 1, 2 and 4.
- `references/adjacent-engines.md`: MLX, LM Studio, NVIDIA Dynamo and Text Generation Inference status, and why they are not in the main matrix. Load when the user names one of them.

## Companion skills

Install any of these with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: install, serve flags and tuning for the chosen engine. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm` (and the same form for each name).
- `choosing-hardware`: size the machine for the model and concurrency. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `choosing-llm-hosting`: decide local, owned server, cloud or hybrid. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `self-hosted-llms`: run the chosen engine behind one authenticated endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `local-llms`: run it on a laptop or desktop. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `model-quantization`: make the quant the engine wants. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `llm-evals`: quality gate for numerics changes. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
