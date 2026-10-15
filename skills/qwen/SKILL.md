---
name: qwen
description: Serve Alibaba Qwen (Qwen3.8, 3.6, 3.5, Coder-Next, Qwen3) with the right parsers, templates, thinking toggles and quants per engine and platform. Use for qwen3_coder or qwen3 reasoning parser, enable_thinking, preserve_thinking, reasoning_effort xhigh, Qwen3.8-27B, 2.4T-A95B, Flash-Next, 35B-A3B, empty tool_calls with thinking, "System message must be at the beginning", NVFP4 or GGUF picks, and tool-call bugs on vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, MLX or TensorFold.
license: MIT
compatibility: Linux, macOS or Windows host with curl and jq. Reading model cards needs no GPU. Downloading weights, installing engines and starting servers need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Qwen

Pick the right Qwen generation, size and format for the hardware, then serve it with the engine flags, chat template and thinking toggle that upstream documents.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs. Engine install and tuning belong to the engine skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# GPUs and memory
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
uname -m; sysctl -n hw.memsize 2>/dev/null; free -g 2>/dev/null | head -2
# Engines and versions already present
command -v vllm sglang llama-server ollama trtllm-serve tensorfold 2>/dev/null
python3 -c 'import vllm; print("vllm", vllm.__version__)' 2>/dev/null
llama-server --version 2>&1 | head -1
ollama list 2>/dev/null | grep -i qwen
# Qwen weights already cached
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i qwen
# What a running server exposes
curl -fsS http://127.0.0.1:8000/v1/models 2>/dev/null | jq -r '.data[].id'
```

## Decision flow

1. If the user names Qwen2.5, Qwen3 (original), Qwen3-VL, Omni, QwQ or Qwen-Image, say so. Qwen3 originals use `/think` and `/no_think` and 32K native context; read `references/models.md` and the "Earlier Qwen3" table in `references/parsers-and-templates.md`. Image, speech and embedding models are out of scope.
2. Pick the model. Default to **Qwen3.8-27B** (dense, vision, Apache 2.0). Use **Qwen3.6-35B-A3B** or Qwen3.5 MoE when only 3B active parameters per token matter (all weights still load). Use Qwen3.5-9B or smaller for laptops. Use **Qwen3-Coder-Next** for non-thinking coding. Qwen3.8-2.4T-A95B needs 8+ Blackwell GPUs and a licence review; Qwen3.8-Flash-Next is a Qwen4-architecture preview. Load `references/models.md`.
3. Pick the format from memory (weights only, then add KV cache): 24 GB or less, Q4 GGUF of the 27B or Qwen3.5-9B; 32 GB, 27B NVFP4 (short context on one RTX 5090); 80 GB, FP8; DGX Spark (128 GB), NVFP4 on vLLM; Apple Silicon, MLX 4-bit. Load `references/platforms-and-quants.md`.
4. Pick the engine: vLLM or SGLang for servers and agents, TensorRT-LLM on Blackwell, llama.cpp or Ollama for local, MLX on Apple Silicon. TensorFold natively serves only qualified Metal pairs. Load `references/parsers-and-templates.md` for exact flags.
5. If `tool_calls` is empty, reasoning leaks into `content`, a client gets a template exception, or thinking will not turn off, match the symptom in `references/known-issues.md` before editing the template.
6. If the user wants speed, use the built-in MTP head (vLLM, SGLang, TensorRT-LLM for MoE) or the DFlash2 and DSpark drafters for Qwen3.8-27B; see the `speculative-decoding` skill.

## Rules

- **Ask before changing the system.** Installs, downloads, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Hugging Face and other tokens live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. Qwen3.5+ engine support moves fast; check the engine version before trusting a flag.
- **Use the engine's chat template path.** Never hand-build ChatML prompts for tool use or thinking.
- **Thinking is on by default and set by template kwargs.** Disable per request with `chat_template_kwargs {"enable_thinking": false}`. Always pair `--reasoning-parser qwen3` (vLLM, SGLang) or `qwen3_5` (TensorRT-LLM) with it.
- **Sampling:** thinking `temperature=1.0, top_p=0.95, top_k=20, min_p=0`; non-thinking `temperature=0.7, top_p=0.8, top_k=20, presence_penalty=1.5`. Never greedy.
- **Tool parser:** `qwen3_coder` on vLLM and SGLang, `qwen3` on TensorRT-LLM, built into `--jinja` on llama.cpp.
- **Context:** native 262,144. Size `--max-model-len` to the workload, keep 128K or more for thinking, and use static YaRN to about 1M only for long prompts.
- **Loopback by default.** Bind `127.0.0.1` unless the user asked for exposure; see `self-hosted-llms` for auth.
- **Licence:** Qwen3.8-27B, Qwen3.6, Qwen3.5 and Qwen3-Coder-Next are Apache 2.0. Qwen3.8-2.4T-A95B (`qwen3.8-max`) and Flash-Next (`qwen-community-1.0`) are custom licences with Model-as-a-Service conditions.

## Serving the family

- [ ] Choose the generation, size and format -> `references/models.md`, `references/platforms-and-quants.md`.
- [ ] Choose the engine and copy its flags -> `references/parsers-and-templates.md`.
- [ ] Serve on loopback with `--max-model-len` sized to the workload, not the maximum.
- [ ] Check `/v1/models`, then one plain request, one with `enable_thinking` false, one tool call, and one streamed tool call.
- [ ] Verify: reasoning is separate from `content`, tool calls come back as `tool_calls` JSON, and no raw `<tool_call>` or `<think>` text reaches the client.
- [ ] If anything fails, match the symptom in `references/known-issues.md`.

## Reference index

- `references/models.md`: Qwen3.8, 3.6 and 3.5 sizes, active parameters, context, modalities, licences, Coder-Next and earlier families, Ollama tags. Load when choosing a model.
- `references/parsers-and-templates.md`: template and token facts, thinking, effort and preserved-thinking toggles, sampling, and the vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama and TensorFold matrix with launch commands. Load when writing serve flags.
- `references/platforms-and-quants.md`: FP8, NVFP4, GGUF, MLX and GPTQ checkpoints, per-platform picks (DGX Spark, RTX, Apple Silicon, H100/B300, AMD), context and memory. Load when sizing hardware.
- `references/known-issues.md`: tool-parser, reasoning-parser, template and quant bugs with workarounds. Load on any misbehaviour.

## Companion skills

- `vllm`: install, tune and troubleshoot the vLLM server. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: SGLang server. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `llama-cpp`: llama.cpp and GGUF. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `ollama`: Ollama server and Modelfiles. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
- `mlx`: Apple Silicon MLX. Install: `npx skills add ScaleDockHQ/llm-skills --skill mlx`.
- `tensorrt-llm`: TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `tensorfold`: TensorFold engine. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorfold`.
- `speculative-decoding`: MTP, DFlash and DSpark drafters. Install: `npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding`.
- `self-hosted-llms`: DGX Spark and GPU server stacks, gateway, benchmarks. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `local-llms`: laptop-first local running. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `model-quantization`: choosing and making quants. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `fine-tuning-llms`: tuning Qwen with TRL and PEFT. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
