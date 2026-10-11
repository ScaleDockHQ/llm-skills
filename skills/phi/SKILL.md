---
name: phi
description: Serve Microsoft Phi small models (Phi-4, Phi-4-reasoning, mini, mini-flash-reasoning, multimodal, reasoning-vision-15B) with the right template, parser, quant and sampling. Use for phi-4, phi4-mini, Phi-4-reasoning-plus, functools tool calls, system prompt ignored, missing think tags, Phi4FlashForCausalLM or Phi4ForCausalLMV load errors. For engine setup see self-hosted-llms or local-llms.
license: MIT
compatibility: Linux or macOS shell with curl and jq. Reads only until the user approves serving or installs. Needs NVIDIA GPU, Apple Silicon or CPU depending on the quant chosen.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Phi

Pick the right Phi checkpoint, then serve it with the correct chat template, tool and reasoning parser flags, sampling and
quantization for the user's engine and hardware. Facts were read from upstream on 2026-10-11.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Hardware and engines
nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader 2>/dev/null
uname -sm
for t in vllm sglang trtllm-serve llama-server ollama; do command -v "$t" >/dev/null && echo "$t: $("$t" --version 2>&1 | head -n1)"; done
# What Phi models are already local or served
ollama list 2>/dev/null | grep -i phi
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i -E 'phi'
# A running OpenAI-compatible server (set BASE, e.g. http://127.0.0.1:8000/v1)
curl -fsS "${BASE:-http://127.0.0.1:8000/v1}/models" | jq -r '.data[].id' | grep -i phi
```

## Decision flow

1. Choose the model from the task (details in `references/models.md`):
   - General chat or tools on small hardware: `Phi-4-mini-instruct` (3.8B, 128K, the only Phi with a tool format).
   - Math/science/code reasoning: `Phi-4-reasoning-plus` (14B, 32K), or `Phi-4-mini-reasoning` (3.8B, math only).
   - Images, OCR, GUI grounding: `Phi-4-reasoning-vision-15B` (16K context). Audio plus images: `Phi-4-multimodal-instruct`.
   - Plain 14B instruct: `phi-4` (16K).
   - `Phi-4-mini-flash-reasoning`: not in vLLM, SGLang or llama.cpp docs; Transformers only (`references/known-issues.md`).
2. Choose the engine and flags (`references/parsers-and-templates.md`). vLLM covers the most Phi variants. TensorFold has
   no Phi support. SGLang has no Phi tool or reasoning parser.
3. Choose the quant for the hardware (`references/platforms-and-quants.md`). NVIDIA publishes FP8 and NVFP4 only for
   Phi-4-reasoning-plus and Phi-4-multimodal-instruct. Official GGUF exists only for `phi-4`.
4. If a symptom is already visible (system prompt ignored, `functools[...]` text, no reasoning split), read
   `references/known-issues.md` first.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. Re-run
  `vllm serve --help` (or the engine's help) before using a flag copied from a model card; cards pin 2025-era versions.
- **Reasoning models drop system messages.** Phi-4-reasoning, -plus and the vision model hard-code their system prompt;
  put instructions in the user turn.
- **Never invent a model name or size.** The newest Phi on the Hub is Phi-4-reasoning-vision-15B; there is no Phi-5.
- **Use the card's sampling.** Reasoning models need `temperature` 0.8 and `top_p` 0.95 (14B also `top_k` 50), not greedy.

## Serving the family

- [ ] Pick the checkpoint and read its context limit -> `references/models.md`
- [ ] Apply the template, parser flags and sampling for the engine -> `references/parsers-and-templates.md`
- [ ] Pick the quant for the platform and check memory -> `references/platforms-and-quants.md`
- [ ] Send a first request and check: reasoning separated from `content`, tool call returned as `tool_calls`, answer not truncated -> `references/known-issues.md`
- [ ] Verify: `/v1/models` lists the model, a chat request returns text, and a reasoning model returns a closed `</think>` block (or `reasoning` field).

## Reference index

- `references/models.md`: generations, sizes, context, release dates, licenses, official packaging. Load first.
- `references/parsers-and-templates.md`: chat templates, reasoning toggles, sampling, and flags for vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, TensorFold.
- `references/platforms-and-quants.md`: FP8, NVFP4, GGUF, MLX and ONNX options and picks for DGX Spark, RTX, Apple Silicon, datacenter.
- `references/known-issues.md`: symptom to cause to fix, with upstream issue links.

## Companion skills

- `self-hosted-llms`: run the engine on an owned NVIDIA GPU server or DGX Spark behind a gateway. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `local-llms`: run models on a laptop (Ollama, llama.cpp, MLX). Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `model-quantization`: make or evaluate quants. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `fine-tuning-llms`: adapt Phi to a task. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
- `cloud-llms`: hosted Phi on Azure AI Foundry and other clouds. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
