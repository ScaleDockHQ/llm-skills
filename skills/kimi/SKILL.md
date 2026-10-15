---
name: kimi
description: Serve Moonshot AI Kimi open-weight models (K3, K2.7-Code, K2.6, K2.5, K2-Thinking, Kimi-Linear, Kimi-VL) with correct parsers, templates, quants and sizing. Use for kimi_k3 or kimi_k2 tool/reasoning parsers, reasoning_effort, preserve_thinking, empty tool_calls, "!!!!" output, Kimi GGUF/NVFP4/MLX, licenses. For hosting plans see self-hosted-llms, local-llms, cloud-llms.
license: MIT
compatibility: Linux or macOS shell with curl and jq. Read-only discovery by default; installs, downloads of hundreds of GB and engine restarts need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Kimi

Pick the right Kimi checkpoint for the hardware, then serve it with the parser names, template toggles, quant and flags upstream documents, and avoid the known bugs.

**Scope:** Moonshot AI open weights: Kimi K3 (2.8T MoE, 1M context), Kimi K2.x (1T MoE: K2.7-Code, K2.6, K2.5, K2-Thinking, K2-Instruct-0905), Kimi-Linear-48B-A3B and Kimi-VL-A3B. Chat templates, tool and reasoning parsers per engine, quants per platform, context limits, licenses and known bugs. Verified 2026-10-11; re-check upstream before quoting versions.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# GPUs and memory (skip what does not exist)
command -v nvidia-smi && nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
uname -sm; (free -g 2>/dev/null || sysctl -n hw.memsize)
# Engines and versions
command -v vllm && vllm --version
command -v sglang && sglang --version
command -v llama-server && llama-server --version 2>&1 | head -n 2
python3 -c "import transformers; print('transformers', transformers.__version__)" 2>/dev/null
# Is a Kimi endpoint already up? Look at ids, not keys
curl -fsS http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
# Cached Kimi checkpoints (sizes only)
du -sh ~/.cache/huggingface/hub/models--moonshotai--* 2>/dev/null
```

## Decision flow

1. **Choose the model** (`references/models.md`): coding agents -> K2.7-Code (thinking only); general multimodal on 1T-class hardware -> K2.6; frontier quality, 1M context, datacenter Blackwell -> K3; one small GPU, Spark or laptop -> Kimi-Linear-48B-A3B (text) or Kimi-VL-A3B (vision). The 1T and 2.8T models do not fit a DGX Spark or a consumer GPU at any published quant.
2. **Match memory to a platform recipe** (`references/platforms-and-quants.md`): K3 needs at least 8x B300 or 16x B200 on vLLM (SGLang also documents H200 2x8 and H100 4x8); K2.x INT4 runs on 8x H200, NVFP4 on 4x B300; 350 GB or more of RAM+VRAM for the smallest K2.x GGUF, about 610 GB for the smallest K3 GGUF.
3. **Choose the engine.** vLLM or SGLang for datacenter (both document Kimi); TensorRT-LLM for Blackwell (K3 is SM100 only, built from source); llama.cpp for GGUF and CPU/Metal; MLX for Apple Silicon. Ollama only offers `:cloud` tags for Kimi (not local). TensorFold has no Kimi support (not in its v1.0.7 qualified list).
4. **Get parsers and toggles right** (`references/parsers-and-templates.md`): `kimi_k3` for K3, `kimi_k2` for K2.x; the thinking toggle key differs per engine.
5. **If something misbehaves** (empty `tool_calls`, `!!!!`, leaked markers, hangs), read `references/known-issues.md` before changing flags.
6. If the user only wants hosted Kimi, point to `cloud-llms` instead of planning hardware.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path. Say the download size first: K3 is 1.56 TB, K2.x about 595 GB, the smallest GGUFs 340-600 GB.
- **Secrets never touch output.** Keys live in `0600` files or environment variables. Never put a key on a command line you print.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date; engine flags for K3 change weekly.
- **Keep reasoning on the wire.** K3 requires the full assistant message (`reasoning_content` and `tool_calls`) returned in the next request; K2.7-Code forces preserved thinking. Do not strip it in a gateway.
- **Always `--trust-remote-code`** for Kimi checkpoints on vLLM/SGLang, and pass K3 `--enable-prefix-caching` explicitly (off by default).
- **Use the card's sampling:** temperature 1.0 and top_p 0.95 for thinking; 0.6 for K2.6/K2.5 instant mode; K3 agentic runs use top_p 1.0.
- **Validate tool calls.** Check `tool_calls` against your schema and retry on empty results (vLLM says K3 occasionally emits a format its parser misses).
- **Give thinking models room:** a large `max_tokens`, or answers truncate and look wrong.
- **Respect the licence.** K3 has a Model-as-a-Service clause (separate agreement above 20M USD revenue over 12 months unless exempt); K2.x is Modified MIT with a UI-attribution clause; Linear and VL are MIT. See `references/models.md`; this is not legal advice.

## Serving the family

- [ ] Pick model and size against memory -> `references/models.md`, `references/platforms-and-quants.md`
- [ ] Download the checkpoint or quant the user approved (`hf download`, resumable); for K3 vLLM use the Docker image from the vLLM recipes page
- [ ] Start the engine with the exact parser flags -> `references/parsers-and-templates.md`
- [ ] Set sampling and the thinking/effort toggle for the model
- [ ] Verify: `GET /v1/models` lists the model; a chat request returns `content` and, for thinking models, `reasoning_content` (or `reasoning`); a one-tool request returns a non-empty `tool_calls` with `finish_reason` `tool_calls`; a long multi-turn request keeps the reasoning fields -> `references/known-issues.md` if not
- [ ] For a stack behind a gateway, hand the endpoint to `self-hosted-llms` (llama-swap, LiteLLM) and keep the engine on loopback

## Reference index

- `references/models.md`: generations, sizes, active params, modes, context, licences and sources. Load first.
- `references/parsers-and-templates.md`: parser names per engine (vLLM, SGLang, llama.cpp, TensorRT-LLM, TensorFold, Ollama), template quirks, thinking/effort toggles, sampling, version requirements.
- `references/platforms-and-quants.md`: what fits on Spark, RTX, Apple Silicon, H100/H200, Blackwell and AMD; official NVFP4/INT4/MXFP4, GGUF and MLX options with sizes; memory levers.
- `references/known-issues.md`: tool-parser bugs and fixed-in versions, `!!!!` output, hangs, install gotchas, licence gotchas.

## Companion skills

- `self-hosted-llms`: gateway, model swapping and exposure for a GPU server. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `local-llms`: laptop and desktop serving (llama.cpp, Ollama, MLX). Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `cloud-llms`: hosted Kimi APIs and providers. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `model-quantization`: making or judging GGUF, FP8, NVFP4 and MLX quants. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `fine-tuning-llms`: fine-tuning Kimi-Linear or Kimi-VL (the 1T-class models are out of reach for single-node tuning). Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `mlx`, `ollama`, `tensorfold`, `tool-calling-parsers`: engine-level detail. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm` (same pattern for the others).
