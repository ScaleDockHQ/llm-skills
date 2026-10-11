---
name: deepseek
description: Serve DeepSeek V4.1, V4 (Flash, Pro), V3.2 and R1 with the right parsers, templates, quants and sampling per engine and platform. Use for DeepSeek-V4.1-Flash, V4-Flash-0731, V4-Pro-0813, DSpark, deepseek_v4 or deepseek_v41 parsers, raw DSML tool calls, empty content with finish_reason length, reasoning_effort, R1 distills, GGUF or NVFP4 on DGX Spark, and DeepSeek bugs on vLLM, SGLang, llama.cpp, TensorRT-LLM, MLX or Ollama.
license: MIT
compatibility: Linux, macOS or Windows host with curl and jq. Reading model cards needs no GPU. Downloading weights, installing engines and starting servers need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# DeepSeek

Pick the right DeepSeek generation, size and format for the hardware, then serve it with the engine flags, prompt encoding and reasoning toggle that upstream documents.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs. Engine install and tuning belong to the engine skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# GPUs and memory
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
uname -m; sysctl -n hw.memsize 2>/dev/null; free -g 2>/dev/null | head -2
# Engines and versions already present
command -v vllm sglang llama-server ollama trtllm-serve 2>/dev/null
python3 -c 'import vllm; print("vllm", vllm.__version__)' 2>/dev/null
python3 -c 'import sglang; print("sglang", sglang.__version__)' 2>/dev/null
llama-server --version 2>&1 | head -1
ollama list 2>/dev/null | grep -i deepseek
# DeepSeek weights already cached
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i deepseek
# What a running server exposes
curl -fsS http://127.0.0.1:8000/v1/models 2>/dev/null | jq -r '.data[].id'
```

## Decision flow

1. Name the generation first. Current on 2026-10-11: **V4.1-Flash** (multimodal, 1M context), **V4-Flash-0731** and **V4-Pro-0813** (text, 1M context, DSpark draft attached). Older: V3.2, V3.1, R1-0528 and the R1 distills. Load `references/models.md`.
2. Check memory before anything else. Every V4 and V4.1 checkpoint is large: V4.1-Flash is about 476 GiB on disk, V4-Flash about 160 GB, V4-Pro is 1.6T parameters. One DGX Spark (128 GB) or one consumer GPU cannot hold the native checkpoints. Load `references/platforms-and-quants.md`.
3. Pick the engine by checkpoint, not preference. V4.1 needs vLLM 0.30.0+ (nightly Docker image per the recipe) or the SGLang preview image `lmsysorg/sglang:dev-dsv41`. V4 and V4-0731/0813 run on stock vLLM and SGLang. llama.cpp has V4 but not V4.1 upstream. Load `references/parsers-and-templates.md` for flags.
4. Use the engine's built-in DeepSeek prompt encoding. V4 repos ship no Jinja template; vLLM uses `--tokenizer-mode deepseek_v4` or `deepseek_v41`, SGLang uses its parsers. Never hand-build DSML prompts.
5. If tool calls arrive as raw `<｜DSML｜...` text, `content` is empty with `finish_reason=length`, output is garbled, or DSpark accepts nothing, read `references/known-issues.md` before changing the model.
6. If the user wants a small or local DeepSeek, say plainly that V4 has no small sibling. The options are a heavily quantized V4-Flash GGUF on 128 GB+ memory, or the older R1 distills (1.5B to 70B) with their own template rules.

## Rules

- **Ask before changing the system.** Installs, downloads, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Hugging Face and other tokens live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. DeepSeek V4.x engine support moves weekly; check the engine version before trusting a flag.
- **Sampling:** `temperature=1.0`, `top_p=0.95` for agentic work, `1.0` otherwise (V4-0731, V4-0813, V4.1 cards). R1 and distills use `temperature=0.6`.
- **Reasoning is a request switch.** V4: `chat_template_kwargs {"thinking": true, "reasoning_effort": "high"|"max"}`. V4.1: integer 1-100 effort. Defaults differ per engine, so set it explicitly.
- **Budget output tokens.** At `high` and `max` effort DeepSeek recommends up to 384K output tokens; Think Max needs a context of at least 384K on V4.
- **Use the paired parser.** `deepseek_v4` parsers do not parse V4.1; its DSML tags carry a leading space and need `deepseek_v41` (vLLM) or `deepseekv41` (SGLang).
- **Loopback by default.** Bind `127.0.0.1` unless the user asked for exposure; see `self-hosted-llms` for auth.
- **Licence:** every DeepSeek model checked here is MIT. R1 Llama distills inherit the Llama licence.

## Serving the family

- [ ] Choose generation, size and context -> `references/models.md`.
- [ ] Choose platform and quant -> `references/platforms-and-quants.md`.
- [ ] Copy engine flags, parser names and reasoning toggles -> `references/parsers-and-templates.md`.
- [ ] Send a text request, a tool call request and (V4.1) an image request; check `reasoning_content` and `tool_calls` are populated -> `references/known-issues.md` if not.
- [ ] Verify: the model answers `17*19` with `323`, tool calls arrive structured, and `max_model_len` meets the effort level.

## Reference index

- `references/models.md`: current and older generations, sizes, active parameters, context, licenses, official quants.
- `references/parsers-and-templates.md`: prompt encoding, DSML tool format, parser and toggle names for vLLM, SGLang, llama.cpp, TensorRT-LLM, Ollama and MLX.
- `references/platforms-and-quants.md`: DGX Spark, consumer RTX, Apple Silicon, H100/H200 and Blackwell recommendations, GGUF, NVFP4, MLX and FP8 repacks.
- `references/known-issues.md`: open bugs, version traps and engine gaps with issue links.

## Companion skills

- `vllm`: vLLM install and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `sglang`: SGLang install and tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `llama-cpp`: GGUF serving. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `tensorrt-llm`: NVIDIA engine. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorrt-llm`.
- `mlx`: Apple Silicon. Install: `npx skills add ScaleDockHQ/llms-skills --skill mlx`.
- `speculative-decoding`: DSpark and draft models. Install: `npx skills add ScaleDockHQ/llms-skills --skill speculative-decoding`.
- `self-hosted-llms`: run, expose and benchmark models on your own server. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `model-quantization`: choosing formats. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
