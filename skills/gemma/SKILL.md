---
name: gemma
description: Serve Google Gemma 4 (E2B, E4B, 12B, 26B-A4B, 31B, QAT, DiffusionGemma) with the right parsers, templates, quants and sampling per engine and platform. Use for gemma-4, gemma4 parser, <|think|>, <|channel>thought, <|tool_call>, enable_thinking not disabling, QAT GGUF or w4a16, NVFP4 on DGX Spark, MTP assistant drafters, MedGemma or Gemma 3 questions, and gemma4 tool-call streaming bugs on vLLM, SGLang, llama.cpp, Ollama, MLX or TensorRT-LLM.
license: MIT
compatibility: Linux, macOS or Windows host with curl and jq. Reading model cards needs no GPU. Downloading weights, installing engines and starting servers need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Gemma

Pick the right Gemma 4 size and format for the hardware, then serve it with the engine flags, chat template and thinking toggle that upstream documents.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs. Engine install and tuning belong to the engine skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# GPUs and memory
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
uname -m; sysctl -n hw.memsize 2>/dev/null; free -g 2>/dev/null | head -2
# Engines and versions already present
command -v vllm sglang llama-server ollama mlx_vlm.generate 2>/dev/null
python3 -c 'import vllm; print("vllm", vllm.__version__)' 2>/dev/null
llama-server --version 2>&1 | head -1
ollama list 2>/dev/null | grep -i gemma
# Gemma weights already cached
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i gemma
# What a running server exposes
curl -fsS http://127.0.0.1:8000/v1/models 2>/dev/null | jq -r '.data[].id'
```

## Decision flow

1. If the user names MedGemma, PaliGemma, CodeGemma, Gemma 3 or older, say so: MedGemma (1.5, 4B) is built on Gemma 3 and has its own Health AI licence. Read `references/models.md`; this skill does not verify the older templates.
2. Pick the size from memory (weights only, then add KV cache): 24 GB or less, E4B or 12B QAT Q4_0; 24-48 GB, 26B A4B or 31B QAT; 80 GB+ or DGX Spark (128 GB), 26B A4B or 31B at BF16, or 31B NVFP4 on Spark. Load `references/platforms-and-quants.md`.
3. Pick the engine: vLLM or SGLang for servers and agents, TensorRT-LLM (PyTorch backend) on NVIDIA, llama.cpp or Ollama for laptops and consumer GPUs, MLX (`mlx-vlm`) or Ollama `*-mlx` on Apple Silicon. Load `references/parsers-and-templates.md` for the exact flags.
4. If tool calls arrive as raw `<|tool_call>` text, reasoning leaks into content, or thinking will not turn off, check `references/known-issues.md` before changing the template.
5. If the user wants speed, use the matching `-assistant` MTP drafter on vLLM (or TensorRT-LLM for 31B, 26B-A4B, E2B, E4B). If they want maximum tokens/second and accept lower scores, DiffusionGemma 26B A4B.

## Rules

- **Ask before changing the system.** Installs, downloads, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Hugging Face and other tokens live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. Gemma 4 engine support moves fast; check the engine version before trusting a flag.
- **Use the engine's chat template path.** Never hand-build Gemma prompts. Image before text, audio after text.
- **Sampling:** `temperature=1.0`, `top_p=0.95`, `top_k=64` (model card), unless the user sets otherwise.
- **Thinking is a template switch.** `enable_thinking` (vLLM, SGLang, llama.cpp kwargs) or `<|think|>` at the start of the system prompt. Strip old thoughts from history; keep them only across tool-call turns.
- **Loopback by default.** Bind `127.0.0.1` unless the user asked for exposure; see `self-hosted-llms` for auth.
- **Licence:** Gemma 4 is Apache 2.0. MedGemma uses the Health AI Developer Foundations terms and gated access.

## Serving the family

- [ ] Choose the size and format -> `references/models.md`, `references/platforms-and-quants.md`.
- [ ] Choose the engine and copy its flags -> `references/parsers-and-templates.md`.
- [ ] Serve on loopback with `--max-model-len` sized to the workload, not the 256K maximum.
- [ ] Check `/v1/models`, then one plain request, one thinking request (`chat_template_kwargs`), one tool call, and one streamed tool call.
- [ ] Verify: reasoning is separate from `content`, tool calls come back as `tool_calls` JSON, and no raw `<|channel>` or `<|tool_call>` text reaches the client.
- [ ] If anything fails, match the symptom in `references/known-issues.md`.

## Reference index

- `references/models.md`: Gemma 4 sizes, active parameters, context, modalities, licences, variants (QAT, MTP assistants, DiffusionGemma, NVFP4), MedGemma and older generations, Ollama tags. Load when choosing a model.
- `references/parsers-and-templates.md`: control tokens, thinking and tool-call formats, sampling, and the vLLM, SGLang, llama.cpp, TensorRT-LLM, Ollama and TensorFold matrix with launch commands. Load when writing serve flags.
- `references/platforms-and-quants.md`: official and community quants, per-platform picks (DGX Spark, RTX, Apple Silicon, H100/B200, AMD/TPU/Xeon), context and vision limits. Load when sizing hardware.
- `references/known-issues.md`: tool-parser streaming bugs, thinking-toggle bugs, mmproj NaNs and workarounds. Load on any misbehaviour.

## Companion skills

- `vllm`: install, tune and troubleshoot the vLLM server. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `sglang`: SGLang server. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `llama-cpp`: llama.cpp and GGUF. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `ollama`: Ollama server and Modelfiles. Install: `npx skills add ScaleDockHQ/llms-skills --skill ollama`.
- `mlx`: Apple Silicon MLX. Install: `npx skills add ScaleDockHQ/llms-skills --skill mlx`.
- `tensorrt-llm`: TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorrt-llm`.
- `self-hosted-llms`: DGX Spark and GPU server stacks, gateway, benchmarks. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `local-llms`: laptop-first local running. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `model-quantization`: choosing and making quants. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `fine-tuning-llms`: tuning Gemma with TRL and PEFT. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
