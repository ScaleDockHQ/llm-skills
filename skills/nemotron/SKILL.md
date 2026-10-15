---
name: nemotron
description: Serve NVIDIA Nemotron open models (3.5 Lightning, 3 Nano, Super, Ultra, Nano 4B, Nano Omni, Llama-Nemotron). Gives vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama and TensorFold flags, nemotron_v3 and qwen3_coder parsers, enable_thinking, NVFP4 on DGX Spark, context and bugs. Use for nvidia/NVIDIA-Nemotron-* repos, nano_v3 or super_v3 parser errors, empty content with tool calls, hybrid Mamba MoE. Stack in self-hosted-llms; laptops in local-llms.
license: MIT
compatibility: Read-only discovery needs a POSIX shell, optional nvidia-smi, curl and jq. Installing engines, downloading weights, starting servers and exposing ports need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Nemotron

Serve an NVIDIA Nemotron open model with the right parsers, reasoning toggle, quant and context limit for the
user's engine and hardware, and avoid the known bugs of the hybrid Mamba-2 MoE architecture.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs.

Work through the steps in order. Load a reference only when a step names it. Everything in the references was read
on 2026-10-11; NVIDIA ships new checkpoints monthly, so re-check Hugging Face before quoting a repo id.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Engines and versions (any may be absent)
command -v vllm && vllm --version
command -v sglang && python3 -c "import sglang; print('sglang', sglang.__version__)" 2>&1 | tail -n 1
command -v trtllm-serve && trtllm-serve --help 2>&1 | head -n 1
command -v llama-server && llama-server --version 2>&1 | head -n 2
command -v ollama && ollama --version
command -v tensorfold && tensorfold --version

# Hardware and memory (GB10 reports unified memory; Apple Silicon uses sysctl)
nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null
free -g 2>/dev/null || sysctl -n hw.memsize 2>/dev/null

# Nemotron weights already on disk, and servers already running
ls -d "${HF_HOME:-$HOME/.cache/huggingface}"/hub/models--nvidia--*emotron* 2>/dev/null
ollama list 2>/dev/null | grep -i nemotron
ps -eo pid,args | grep -i -E 'vllm|sglang|trtllm|llama-server|tensorfold' | grep -v grep | cut -c1-200
```

## Decision flow

1. Which model? Use `references/models.md`. Default picks: **Nemotron 3.5 Lightning 30B-A3B** (newest small agent
   model, 2026-08-11), **Nemotron 3 Super 120B-A12B** (mid-size), **Nemotron 3 Ultra 550B-A55B** (datacenter).
   Nemotron 3 Nano 30B-A3B and Nano 4B are older small models; Nano Omni adds image, video and audio.
2. Which memory budget? Match the model to the platform in `references/platforms-and-quants.md`: Lightning NVFP4
   is about 21.5 GB, Super NVFP4 about 80 GB (fits one DGX Spark), Ultra NVFP4 about 352 GB (4x B200).
3. Which engine? vLLM is what every card documents first. SGLang and TensorRT-LLM have card recipes too. llama.cpp
   and Ollama for local use. TensorFold is qualified for Lightning only (GB10 CUDA, Apple Metal).
4. Wire parsers and toggles from `references/parsers-and-templates.md`. Check `references/known-issues.md` for the
   exact model, engine and GPU before declaring done.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables. Hugging Face tokens go in
  `HF_TOKEN` or the login cache, never on a command line.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date.
- **Parsers are mandatory for agents.** On vLLM use `--reasoning-parser nemotron_v3 --enable-auto-tool-choice
  --tool-call-parser qwen3_coder` for Lightning, Super (current vLLM), Ultra and Omni. Nano 30B and Nano 4B cards
  still ship a plugin: `--reasoning-parser-plugin nano_v3_reasoning_parser.py --reasoning-parser nano_v3`.
- **Reasoning is on by default.** Turn it off per request with `chat_template_kwargs {"enable_thinking": false}`.
  Give tool-calling requests a large `max_tokens`: reasoning runs before the tool call.
- **Use card sampling.** Lightning, Super, Ultra: temperature 1.0, top_p 0.95 everywhere. Nano 30B: 1.0 and 1.0
  for reasoning; Nano 4B: 1.0 and 0.95; both use 0.6 and 0.95 for tool calling.
- **Hybrid models need engine care.** Pin the vLLM or llama.cpp version the card names and check the issue list
  before upgrading: several regressions hit Nemotron hybrids first.
- **Bind to loopback** unless the user approved exposure, and sit behind an authenticated gateway.

## Serving the family

- [ ] Pick model, format and engine -> `references/models.md`, `references/platforms-and-quants.md`
- [ ] Check disk and memory against the sizes; set `--max-model-len` below 1M unless the user needs it
- [ ] Build the launch command and toggles -> `references/parsers-and-templates.md`
- [ ] Smoke test: one plain chat, one with `enable_thinking` false, one tool call with `max_tokens` of 1024 or
      more. Confirm tool calls arrive in `tool_calls` and reasoning in `reasoning` (vLLM) or `reasoning_content`
      (SGLang, llama.cpp, TensorRT-LLM), not as raw `<tool_call>` or `<think>` text in `content`.
- [ ] Compare symptoms against `references/known-issues.md` when output looks wrong
- [ ] Verify: the endpoint answers all three smoke tests and the context limit and quant match what the user chose.

## Reference index

- `references/models.md`: current generations (3.5 Lightning, 3 Nano, Super, Ultra, Nano 4B, Nano Omni, Labs variants, Llama-Nemotron legacy), sizes, active parameters, context, licenses. Load first.
- `references/parsers-and-templates.md`: template behaviour, reasoning toggles, per-engine parser flags, copy-ready vLLM, SGLang, TensorRT-LLM, llama.cpp and TensorFold commands, sampling. Load when writing a launch command.
- `references/platforms-and-quants.md`: official and community quants, DGX Spark, RTX, Apple Silicon, datacenter, Ollama, TensorFold. Load when sizing hardware.
- `references/known-issues.md`: symptom to cause and fix table, plus open gaps. Load when something breaks.

## Companion skills

- `self-hosted-llms`: the full gateway, swapping and exposure stack on Linux GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `nvidia-dgx-spark`: DGX Spark setup and memory. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`: engine install and operation. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm` (same pattern for the others).
- `tool-calling-parsers`: parser internals across engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill tool-calling-parsers`.
- `local-llms`: running models on a laptop. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `model-quantization`: making or choosing GGUF, FP8 and NVFP4 quants. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `fine-tuning-llms`: finetuning Nemotron models. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `cloud-llms`: calling Nemotron through a hosted API instead. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
