---
name: minimax
description: 'Serve and configure MiniMax open-weight models (M3, M2.7, M2.5, M2.1, M2): parsers, chat templates, thinking modes, quants, licenses and bugs. Use for MiniMax-M3, MiniMax-M2.7, M2.5, minimax_m2, minimax_m3, interleaved thinking, "No common block size for 16", garbled output or lost tool calls on vLLM, SGLang, TensorRT-LLM, llama.cpp, MLX or DGX Spark. For the serving stack itself use self-hosted-llms.'
license: MIT
compatibility: Linux, macOS; bash 3.2+, curl, jq. Read-only discovery by default; installs, container starts and downloads of 100+ GB weights need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# MiniMax

Pick the right MiniMax open-weight generation for the hardware, then serve it with the correct
tool-call parser, reasoning parser, chat template and thinking mode, without dropping the
interleaved reasoning that these models need.

**Scope:** MiniMax-M3 (multimodal MoE, 1M context) and the text-only M2 line (M2, M2.1, M2.5,
M2.7): chat templates, tool and reasoning parsers per engine, recommended quants per platform,
context limits, licenses and known bugs. Older MiniMax-Text-01 and M1 are legacy and only listed.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Hardware and memory (GPU memory, unified memory)
nvidia-smi --query-gpu=name,memory.total --format=csv 2>/dev/null; free -g 2>/dev/null | head -2
sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GiB unified\n", $1/2^30}'
# Engines and versions already installed (parser support depends on the version)
command -v vllm && vllm --version; python3 -c 'import sglang;print(sglang.__version__)' 2>/dev/null
command -v llama-server && llama-server --version 2>&1 | head -1
# Which MiniMax weights are on disk, and which architecture they declare
ls -d ~/.cache/huggingface/hub/models--MiniMaxAI--* ~/.cache/huggingface/hub/models--*MiniMax* 2>/dev/null
for d in ~/.cache/huggingface/hub/models--*MiniMax*/snapshots/*/; do jq -r '.architectures[0], .max_position_embeddings' "$d/config.json" 2>/dev/null; done
# Is a MiniMax server already running, and what does it say?
curl -fsS http://127.0.0.1:8000/v1/models | jq -r '.data[].id' 2>/dev/null
```

## Decision flow

1. Total fast memory under about 100 GB (one RTX, 64 GB Mac): no MiniMax open-weight model fits without
   heavy offload. Use `cloud-llms`, or a smaller family. M2.7 `UD-IQ4_XS` (108 GB) needs RAM offload.
2. One 128 GB unified-memory box (DGX Spark, 128 GB Mac): M2-line only. M2.7 GGUF 4-bit (108 GB) fits;
   NVFP4 (130 to 140 GB) needs two Sparks. M3 does not fit one 128 GB box. Read `references/platforms-and-quants.md`.
3. Multi-GPU server (8x H200, B200 and up): serve M3 (`minimax_m3` parsers, `--block-size 128`) or
   M2.7 (`minimax_m2` parsers). Read `references/parsers-and-templates.md`.
4. Need images or video: M3 only. The M2 line is text only.
5. Commercial use: read the license in `references/models.md` first. M2.7 and M3 are not plain MIT.
6. Anything misbehaving (garbled text, empty tool calls, startup crash): `references/known-issues.md`.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, exposure and 100+ GB downloads
  need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date.
- **M2 and M3 parsers differ.** M2 line: `minimax_m2` tool parser plus `minimax_m2_append_think` reasoning
  parser. M3: `minimax_m3` for both. Mixing them silently breaks tool calls or reasoning.
- **Never strip thinking from history.** M2 is an interleaved-thinking model; dropping its think block
  degrades agent quality. Pass the full assistant message back.
- **Sampling from the card:** `temperature=1.0`, `top_p=0.95`, `top_k=40` (set `top_k` per request; SGLang
  does not apply it by default).
- **Do not change KV or context defaults blindly.** M3 needs `--block-size 128` on vLLM; cap
  `--max-model-len` instead of serving the full 1M window unless you sized the KV cache.

## Serving the family

- [ ] Choose the generation and size the memory -> `references/models.md`
- [ ] Choose format and platform (FP8, NVFP4, MXFP8, MXFP4, GGUF, MLX) -> `references/platforms-and-quants.md`
- [ ] Launch with the right engine flags and thinking mode -> `references/parsers-and-templates.md`
- [ ] Verify: `curl /v1/chat/completions` with a tool, then a second turn passing the assistant message back;
      the reasoning is separated (or kept in `content` on the M2 append-think parsers) and `tool_calls` is populated.
- [ ] If anything fails -> `references/known-issues.md`

## Reference index

- `references/models.md`: generations, sizes, active parameters, context, licenses, official quants, what is API-only.
- `references/parsers-and-templates.md`: template tokens, thinking toggles, exact parser names and launch commands per engine.
- `references/platforms-and-quants.md`: DGX Spark, consumer RTX, Apple Silicon, datacenter Hopper and Blackwell.
- `references/known-issues.md`: upstream bugs and gotchas with fixes, plus gaps not verified.

## Companion skills

- `self-hosted-llms`: the surrounding serving stack (gateway, model swapping, engines, exposure). Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `local-llms`: laptop and desktop runtimes. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `cloud-llms`: hosted MiniMax APIs and cloud providers. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `model-quantization`: making or choosing GGUF, AWQ, NVFP4. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `fine-tuning-llms`: adapting weights (mind the license for fine-tuned commercial use). Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
