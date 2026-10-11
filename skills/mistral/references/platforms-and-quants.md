# Mistral platforms and quants

> Verified against Hugging Face model cards (mistralai, nvidia, unsloth, mlx-community), SGLang cookbooks, vLLM recipes, TensorRT-LLM support matrix and TensorFold v1.0.7 README, 2026-10-11

Official means published by `mistralai` or, for NVFP4 of Medium 3.5, by `nvidia`. Community means everything else.

## Quant availability

| Model                        | Official formats                                                                                                                                        | Community formats seen                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Medium 3.5 128B              | FP8 (native, `mistralai/Mistral-Medium-3.5-128B`), NVFP4 (`nvidia/Mistral-Medium-3.5-128B-NVFP4`, ModelOpt, Blackwell, vLLM only per card), EAGLE draft | Unsloth GGUF (`UD-Q4_K_XL` and others), other GGUF repos. No MLX conversion found: gap     |
| Small 4 119B                 | FP8 (native), NVFP4 (`mistralai/Mistral-Small-4-119B-2603-NVFP4`, llm-compressor with vLLM/Red Hat, kernels with NVIDIA), EAGLE                         | Unsloth GGUF (`UD-Q4_K_M`), `mlx-community/Mistral-Small-4-119B-2603-4bit` (mlx-vlm 0.4.0) |
| Large 3 675B                 | FP8 (native), NVFP4 (recalibrated 2026-09-09), BF16 mentioned by the card, Eagle                                                                        | not checked                                                                                |
| Ministral 3 3B / 8B / 14B    | FP8 (Instruct), BF16 (Reasoning, Base, and `-Instruct-2512-BF16`), official GGUF for Instruct and Reasoning, ONNX for 3B                                | `mlx-community` 4-bit MLX (for example `Ministral-3-8B-Reasoning-2512-4bit`), Unsloth      |
| Devstral 2 123B, Small 2 24B | FP8                                                                                                                                                     | GGUF (llama.cpp needs a recent build, the card links a PR for community GGUFs)             |

No official MXFP4 checkpoint was found for any Mistral model.

## Datacenter (H100, H200, B200, B300)

| Model            | Recommendation                                                                                                                                                              | Source           |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| Large 3          | FP8 on one 8xH200 or 8xB200 node; NVFP4 on 8xH100/A100 (Marlin FP4 fallback saves memory, no speedup versus FP8); B200 for real NVFP4 speed                                 | HF cards         |
| Medium 3.5       | FP8 with TP 8 on H200 or TP 4 on B200 (vLLM recipe); SGLang says `--tp 4` on Hopper, `--tp 2` on Blackwell (FP8 about 130 GB). H100 80 GB listed by the recipe; budget TP 8 | recipe, cookbook |
| Medium 3.5 NVFP4 | NVIDIA's card tests on B200 with `--tensor-parallel-size 4 --max-model-len 196608`, vLLM image `vllm/vllm-openai:v0.21.0`; scores within noise of FP8 on its table          | NVIDIA card      |
| Small 4          | FP8 about 119 GB: TP 2 on H100/H200, TP 1 on B200/B300. NVFP4 about 60 GB, Blackwell only, TP 1                                                                             | SGLang cookbook  |

## NVIDIA DGX Spark (GB10, 128 GB unified, about 273 GB/s)

No Mistral-specific GB10 recipe or qualification was found upstream. What the sources support:

| Model                     | Fit                                                                                                                                                                                                             | Evidence level                            |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| Small 4 NVFP4             | About 60 GB weights (SGLang cookbook), leaves room for KV. Run with vLLM (card command uses `--attention-backend TRITON_MLA`) or SGLang with TP 1                                                               | Size verified; **GB10 run not verified**  |
| Ministral 3 8B / 14B      | Fits easily. 14B is 32 GB in BF16 and under 24 GB quantized (card)                                                                                                                                              | Card                                      |
| Medium 3.5                | Dense 128B is bandwidth bound: a Q4 GGUF is about 70 GB, third-party calculators estimate roughly 3 to 5 tokens/s on a Spark. NVIDIA's NVFP4 targets Blackwell datacenter parts (tested on B200); GB10 untested | Estimates are third party, **unverified** |
| Large 3                   | Does not fit one Spark (675B total)                                                                                                                                                                             | Card sizes                                |
| FP8 Small 4 or Medium 3.5 | About 119 GB and 130 GB: no headroom, do not attempt on one Spark                                                                                                                                               | Cookbook sizes                            |

Prefer vLLM or llama.cpp from the Spark playbooks and `self-hosted-llms` for the surrounding stack. TensorFold
v1.0.7 qualifies only Nemotron, Qwen3.8, GLM and Qwen3.5 checkpoints: **no Mistral model is qualified**.

## Consumer RTX / Linux workstation

| Model                 | Notes                                                                                                                                                                                                                                                            |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Devstral Small 2 24B  | Card: single RTX 4090 or a 32 GB Mac (quantized)                                                                                                                                                                                                                 |
| Ministral 3 14B       | 32 GB BF16, under 24 GB quantized; GGUF official                                                                                                                                                                                                                 |
| Small 4, Medium 3.5   | Only through llama.cpp GGUF with CPU offload (MoE Small 4 offloads well because only 6.5B are active; dense Medium 3.5 does not). One third-party report ran a UD-Q4_K_XL Medium 3.5 (75.69 GB) with about 55 GiB of weights in RAM and attention on a 32 GB GPU |
| vision with llama.cpp | A separate `mmproj` GGUF is required. A user report with Medium 3.5 shows image encoding falling back to CPU when flash attention is on (llama.cpp issue 24272, closed; fix unverified)                                                                          |

## Apple Silicon

| Model                    | Route                                                                                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ministral 3              | `mlx-community` 4-bit via `mlx-vlm`; official GGUF via llama.cpp or Ollama (`ministral-3`, needs Ollama 0.13.1 or newer)                                                              |
| Small 4                  | `mlx-community/Mistral-Small-4-119B-2603-4bit` (mlx-vlm 0.4.0). A community card from March 2026 said stable `mlx-lm` lacked `mistral4`, re-check your version. About 62 GB for 4-bit |
| Medium 3.5               | Ollama `mistral-medium-3.5` (80 GB) or Unsloth GGUF Q4 (about 70 GB, plan for 96 GB or more unified memory with long context). No MLX conversion verified                             |
| Large 3, Devstral 2 123B | Too large for most Macs; not verified                                                                                                                                                 |

## Ollama

| Tag                               | Facts from the library page                                                                                |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `mistral-medium-3.5`              | latest is 80 GB, 256K                                                                                      |
| `ministral-3` (`3b`, `8b`, `14b`) | 3 / 6 / 9.1 GB, 256K, needs Ollama 0.13.1+                                                                 |
| `devstral`                        | still the 24B v1 (Small 3.1 based, 128K). The Devstral 2 HF cards link `devstral-2` and `devstral-small-2` |
| `mistral-small`                   | still the Mistral Small 3 line (24B, 32K tag). No Small 4 tag was found: unverified                        |

## TensorRT-LLM

The support matrix lists `Mistral3ForConditionalGeneration` (example Small 3.1 24B, text and image) and
`MixtralForCausalLM`. Small 4 support was added through AutoDeploy (PR 12266, tracking issue closed 2026-04-07);
Large 3 has a VLM PR and an `examples/models/core/mistral_large_3` README. No evidence for Medium 3.5 or Ministral 3
parser flags in TensorRT-LLM docs: gap.

## Sources

- https://huggingface.co/nvidia/Mistral-Medium-3.5-128B-NVFP4
- https://huggingface.co/mistralai/Mistral-Small-4-119B-2603-NVFP4
- https://huggingface.co/mistralai/Mistral-Large-3-675B-Instruct-2512-NVFP4
- https://huggingface.co/mistralai/Ministral-3-14B-Instruct-2512-GGUF
- https://huggingface.co/mlx-community/Mistral-Small-4-119B-2603-4bit
- https://huggingface.co/mlx-community/Ministral-3-8B-Reasoning-2512-4bit
- https://huggingface.co/unsloth/Mistral-Medium-3.5-128B-GGUF
- https://recipes.vllm.ai/mistralai/Mistral-Medium-3.5-128B
- https://docs.sglang.io/cookbook/autoregressive/Mistral/Mistral-Small-4
- https://docs.sglang.io/cookbook/autoregressive/Mistral/Mistral-Medium-3.5
- https://ollama.com/library/mistral-medium-3.5
- https://ollama.com/library/ministral-3
- https://nvidia.github.io/TensorRT-LLM/reference/support-matrix.html
- https://github.com/NVIDIA/TensorRT-LLM/pull/12266
- https://github.com/ashhart/TensorFold
- https://github.com/ggml-org/llama.cpp/issues/24272
