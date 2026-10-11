---
name: model-quantization
description: Produce quantized LLM checkpoints and publish them. Covers GGUF (llama.cpp convert_hf_to_gguf.py, llama-quantize, llama-imatrix; Q4_K_M, Q8_0, IQ4_XS), EXL3 (ExLlamaV3 convert.py, TabbyAPI), AWQ / GPTQ / FP8 / NVFP4 with LLM Compressor (oneshot, compressed-tensors, W4A16, FP8_DYNAMIC) for vLLM and SGLang, NVFP4 / FP8 with NVIDIA Model Optimizer (ModelOpt hf_ptq.py) for TensorRT-LLM, vLLM and SGLang on Blackwell and DGX Spark (GB10), and MLX (mlx_lm.convert -q) for Apple Silicon. Use when asked to quantize a model, convert safetensors to GGUF, make an imatrix, pick a quant format for an engine or GPU, calibrate, compare a quant with its base model (perplexity, KL divergence, smoke prompts), cap memory for conversions on unified-memory machines, write a model card with base_model and base_model_relation quantized, or upload quants with hf upload. Not for choosing or downloading existing quants (self-hosted-llms) or running task evals (llm-evals).
license: MIT
metadata:
  author: ScaleDockHQ
  version: "1.2.0"
compatibility: Linux (x86_64 or arm64 incl. NVIDIA DGX Spark) with NVIDIA GPU for EXL3, LLM Compressor and ModelOpt; macOS on Apple Silicon for MLX; GGUF works on Linux, macOS and CPU-only. Needs git, cmake, Python 3 venvs, curl, jq, and the Hugging Face hf CLI. systemd-run for memory caps on Linux.
---

# Model Quantization

Produce quantized models that an engine can serve, prove they are close enough to the base model, and publish them with their recipe. Formats: GGUF, EXL3, AWQ/GPTQ (INT4), FP8, NVFP4, MXFP, MLX. Upstream tools: llama.cpp, ExLlamaV3, LLM Compressor, NVIDIA Model Optimizer, mlx-lm, huggingface_hub.

**Scope.** In: choosing a target format for a given engine and hardware, converting, calibrating (imatrix, GPTQ/AWQ/NVFP4 calibration sets), quantizing, quality checks against the base, memory-safe execution, model cards and Hub uploads, serving the result for a smoke test. Out: choosing or downloading existing quants and running the serving stack long-term (`self-hosted-llms`, `local-llms`), task evals and quality gates (`llm-evals`), training or LoRA merges (`fine-tuning-llms`).

Load the reference a step names. Do not improvise flags, scheme names or config keys that are not in a reference or in upstream `--help` output.

## Discover first

Run these read-only checks before asking anything. Never print tokens: test for presence only.

```bash
# Hardware and memory
uname -m
nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null
free -h 2>/dev/null || sysctl hw.memsize          # Linux / macOS
df -h ~ ~/.cache/huggingface 2>/dev/null

# Installed tools
for t in llama-quantize llama-imatrix llama-perplexity llama-server hf mlx_lm.convert mlx_lm.server vllm trtllm-serve python3 cmake nvcc systemd-run; do
  command -v "$t" >/dev/null && echo "found $t" || echo "missing $t"; done
ls ~/src/llama.cpp/convert_hf_to_gguf.py ~/src/exllamav3/convert.py ~/src/Model-Optimizer/examples/hf_ptq/hf_ptq.py 2>/dev/null
python3 -c "import llmcompressor" 2>/dev/null && echo "found llmcompressor"
python3 -c "import modelopt" 2>/dev/null && echo "found modelopt"

# Models already on disk and in the HF cache
hf cache ls 2>/dev/null || du -sh ~/.cache/huggingface/hub/* 2>/dev/null
ls ~/models 2>/dev/null

# What is running (serving competes for memory)
ss -ltnp 2>/dev/null || lsof -nP -iTCP -sTCP:LISTEN
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null
systemctl --user list-units --type=service --state=running 2>/dev/null

# Hub auth
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
hf auth whoami 2>/dev/null
```

Then ask only what cannot be discovered:

- Which base model (Hub id or local path), and which revision?
- Which engine will serve it (llama.cpp/Ollama/LM Studio, TabbyAPI, vLLM, SGLang, TensorRT-LLM, mlx-lm), and on which hardware if not this machine?
- Size or quality target (fits in N GB, a bit width, or "as close to BF16 as possible")?
- Calibration text that represents the real workload, if any?
- Publish? To which namespace, public or private?
- Can serving on this node be stopped during the job?

## Decision flow

| Serving engine / hardware                              | Target format                      | Reference                                                        |
| ------------------------------------------------------ | ---------------------------------- | ---------------------------------------------------------------- |
| llama.cpp, Ollama, LM Studio; CPU, Mac, mixed CPU+GPU  | GGUF (imatrix for 4-bit and below) | `references/gguf.md`                                             |
| TabbyAPI / ExLlamaV3 on NVIDIA                         | EXL3                               | `references/exl3.md`                                             |
| vLLM or SGLang on Ampere                               | W4A16 (GPTQ or AWQ)                | `references/llm-compressor.md`                                   |
| vLLM or SGLang on Ada / Hopper                         | FP8 (or W4A16 for memory)          | `references/llm-compressor.md`                                   |
| vLLM / SGLang / TensorRT-LLM on Blackwell or DGX Spark | NVFP4 or FP8                       | `references/modelopt-nvfp4.md` or `references/llm-compressor.md` |
| TensorRT-LLM anywhere                                  | ModelOpt FP8 / NVFP4               | `references/modelopt-nvfp4.md`                                   |
| mlx-lm or LM Studio MLX on Apple Silicon               | MLX                                | `references/mlx.md`                                              |

Full format-to-engine matrix and hardware notes: `references/formats.md`. If a trusted quant of the right format already exists, use it instead (`self-hosted-llms`).

## Rules

- **Pick the format for the engine, not the other way round.** Decide the serving engine and hardware first, then produce the format it runs best; a quant nobody can serve is wasted GPU hours.
- **Quality-check against the base model.** Compare every quant with its own unquantized parent on the same text, context length and tool; never publish on "it loads".
- **Cap memory for every conversion.** Run converts, calibration, compiles and big downloads in a memory-capped scope, and stop serving on unified-memory nodes first.
- **Keep the recipe with the artifact.** Record commands, tool versions or commits, scheme, bits and calibration data in the model card next to the files.
- **Respect the base model's license.** Inherit the license, copy its notices, link the base, and do not publish what the license does not allow.
- **Quantize from 16-bit weights, never from another quant.** Re-quantizing compounds error; keep the BF16 source or BF16 GGUF until all variants pass.
- **Publish private first.** Upload to a private repo, verify files, card and a fresh download, then make it public.

## Workflows

### Pick a target format

- [ ] Run the discovery block; note GPU name, compute capability, RAM, disk.
- [ ] Confirm the serving engine and hardware with the user.
- [ ] Look up the row in the matrix and hardware notes in `references/formats.md`.
- [ ] Check the base model's architecture is supported by the chosen tool (see the tool's reference, Known pitfalls).
- [ ] Check the license allows derivatives and redistribution (`references/publishing.md`, License inheritance).
- [ ] Estimate disk and memory for the job (`references/memory-safety.md`, Plan before running).

### Convert (HF checkpoint to the tool's input)

- [ ] Download the base at a pinned revision in its own capped step (`references/memory-safety.md`, Downloads).
- [ ] GGUF: install llama.cpp and convert to BF16 GGUF (`references/gguf.md`, Install and Minimal command).
- [ ] EXL3, LLM Compressor, ModelOpt, MLX: the tool reads the HF directory directly; install it in its own venv (`references/exl3.md`, `references/llm-compressor.md`, `references/modelopt-nvfp4.md`, `references/mlx.md`).
- [ ] Stop or shrink serving on the node if memory is shared (`references/memory-safety.md`).

### Quantize (with calibration where applicable)

- [ ] Choose calibration data: workload-like text, not your evaluation text; record it.
- [ ] GGUF: `llama-imatrix`, then `llama-quantize` per type (`references/gguf.md`).
- [ ] EXL3: `convert.py -b <bpw>` with a work dir (`references/exl3.md`).
- [ ] AWQ / GPTQ / FP8 / NVFP4 for vLLM/SGLang: `oneshot()` recipe, save compressed (`references/llm-compressor.md`).
- [ ] NVFP4 / FP8 for TRT-LLM or NVIDIA recipes: `hf_ptq.py --qformat` or `--recipe` (`references/modelopt-nvfp4.md`).
- [ ] MLX: `mlx_lm.convert -q` with bits / group size / mode (`references/mlx.md`).
- [ ] Wrap each heavy step in `systemd-run --user --scope -p MemoryMax=... -p MemorySwapMax=0` (`references/memory-safety.md`).

### Quality-check vs the base model

- [ ] Serve the base and the quant the same way; run the smoke prompts (`references/quality-checks.md`, Smoke prompts).
- [ ] GGUF: KL divergence with `llama-perplexity --kl-divergence-base` / `--kl-divergence` (`references/quality-checks.md`).
- [ ] MLX: `mlx_lm.perplexity` with identical settings for base and quant (`references/quality-checks.md`).
- [ ] Other formats: smoke set plus task evals through the endpoint (hand off to `llm-evals`).
- [ ] Apply the gate decided up front; drop variants that fail.

### Publish to Hugging Face

- [ ] Write the model card from `assets/model-card.md`: `base_model`, `base_model_relation: quantized`, license, recipe, quality numbers (`references/publishing.md`).
- [ ] Copy the base license / notice files into the output folder.
- [ ] `hf repos create <org>/<repo> --private`, then `hf upload` (`references/publishing.md`).
- [ ] Download into a clean directory and smoke-test it; then make the repo public.

### Serve and smoke-test

- [ ] Start the engine with the quant: llama-server (`references/gguf.md`), TabbyAPI (`references/exl3.md`), `vllm serve` / SGLang (`references/llm-compressor.md`, `references/modelopt-nvfp4.md`), TensorRT-LLM (`references/modelopt-nvfp4.md`), `mlx_lm.server` (`references/mlx.md`).
- [ ] Check health and `/v1/models`, then run the smoke prompts (`references/quality-checks.md`).
- [ ] Read the startup log for the kernel/quantization method actually used (for example NVFP4 weight-only fallback) (`references/formats.md`, Hardware notes).
- [ ] Hand the long-term serving config (llama-swap, LiteLLM) to `self-hosted-llms` / `llm-gateway`.

## Reference index

- `references/formats.md` — every format, format-to-engine matrix, hardware notes (Ampere to Blackwell, DGX Spark GB10, Apple Silicon).
- `references/gguf.md` — llama.cpp build (CUDA arm64/x86, Metal), `convert_hf_to_gguf.py`, `llama-quantize` types and options, `llama-imatrix`.
- `references/exl3.md` — ExLlamaV3 install and `convert.py` arguments, TabbyAPI serving.
- `references/llm-compressor.md` — how LLM Compressor (W4A16 GPTQ/AWQ, FP8, NVFP4, compressed-tensors) plugs into this stack; depth is in the `llm-compressor` skill.
- `references/modelopt-nvfp4.md` — how NVIDIA Model Optimizer (`hf_ptq.py`, NVFP4/FP8, unified HF export) plugs into this stack; depth is in the `nvidia-modelopt` skill.
- `references/mlx.md` — how MLX quantization plugs into this stack; depth is in the `mlx` skill.
- `references/quality-checks.md` — smoke prompts, KL divergence and perplexity vs base, hand-off to task evals.
- `references/memory-safety.md` — memory/disk planning, `systemd-run` caps, hf-xet env vars, macOS limits.
- `references/publishing.md` — `hf` CLI upload, model card metadata, license inheritance, naming.
- `assets/model-card.md` — model card skeleton with recipe and quality sections.

## Companion skills

- `gguf-quantization` — llama-quantize, imatrix and GGUF recipes in depth: `npx skills add ScaleDockHQ/llms-skills --skill gguf-quantization`
- `exl3-quantization` — ExLlamaV3 convert.py and bpw choices in depth: `npx skills add ScaleDockHQ/llms-skills --skill exl3-quantization`
- `gptqmodel` — GPTQ quantization and its backends: `npx skills add ScaleDockHQ/llms-skills --skill gptqmodel`
- `bitsandbytes` — 8-bit and 4-bit (NF4) loading: `npx skills add ScaleDockHQ/llms-skills --skill bitsandbytes`
- `torchao` — PyTorch-native int4, int8 and float8 quantization: `npx skills add ScaleDockHQ/llms-skills --skill torchao`
- `hqq` — calibration-free HQQ quantization: `npx skills add ScaleDockHQ/llms-skills --skill hqq`
- `llm-compressor` — AWQ, GPTQ, FP8, NVFP4 recipes and vLLM serving in depth: `npx skills add ScaleDockHQ/llms-skills --skill llm-compressor`
- `nvidia-modelopt` — `hf_ptq.py` NVFP4/FP8 PTQ and unified HF export in depth: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-modelopt`
- `mlx` — `mlx_lm.convert`, flags, modes and `mlx_lm.server` in depth: `npx skills add ScaleDockHQ/llms-skills --skill mlx`
- `self-hosted-llms` — choosing/downloading existing quants and running the serving stack: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `local-llms` — Ollama, LM Studio and llama.cpp on a laptop or desktop: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`
- `llm-evals` — task evals and quality gates for a quant: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- `fine-tuning-llms` — train or merge before quantizing: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`
- `llm-gateway` — expose the new model through LiteLLM: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`
