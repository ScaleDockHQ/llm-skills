---
name: mistral
description: Serve Mistral AI open-weight models (Small 4, Medium 3.5, Large 3, Ministral 3, Devstral 2, Magistral). Gives vLLM, SGLang and llama.cpp flags, tokenizer-mode mistral, reasoning_effort, parsers, quants, context and bugs. Use for mistralai/* repos, [THINK] or [TOOL_CALLS] in output, reasoning_effort must be none or high, Large 4. Serving stack is self-hosted-llms, laptops local-llms.
license: MIT
compatibility: Read-only discovery needs a POSIX shell, optional nvidia-smi, curl and jq. Installing engines, downloading weights, starting servers and exposing ports need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Mistral

Serve a Mistral open-weight model with the right tokenizer mode, tool and reasoning parsers, template toggle,
quant and context limit for the user's engine and hardware, and avoid the known bugs.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs.

Work through the steps in order. Load a reference only when a step names it. Everything in the references was read
on 2026-10-11; Mistral renames models quickly, so re-check Hugging Face before quoting a repo id.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Engines and versions (any may be absent)
command -v vllm && vllm --version
command -v llama-server && llama-server --version 2>&1 | head -n 2
command -v ollama && ollama --version
python3 -c "import mistral_common; print('mistral_common', mistral_common.__version__)" 2>&1 | tail -n 1
python3 -c "import transformers; print('transformers', transformers.__version__)" 2>&1 | tail -n 1

# Hardware and memory
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
free -g 2>/dev/null || sysctl -n hw.memsize 2>/dev/null

# Mistral weights already on disk, and Mistral servers already running
ls -d "${HF_HOME:-$HOME/.cache/huggingface}"/hub/models--mistralai--* 2>/dev/null
ollama list 2>/dev/null | grep -i -E 'mistral|ministral|devstral|magistral'
ps -eo pid,args | grep -i -E 'vllm|sglang|llama-server' | grep -v grep | cut -c1-200
```

## Decision flow

1. Which model? Use the table in `references/models.md`. Mistral Large 4 weights are not public until about
   2026-10-31; if the user asks for it, say so and offer Medium 3.5 (dense) or Small 4 (MoE) now.
2. Which memory budget? Match the model to the platform in `references/platforms-and-quants.md`: Small 4 NVFP4
   is about 60 GB, Medium 3.5 is 128B dense (Q4 about 70 GB, FP8 about 130 GB), Large 3 needs an 8-GPU node.
3. Which engine? vLLM is what every card recommends. SGLang has cookbooks for Ministral 3, Small 4, Medium 3.5 and
   Devstral 2. llama.cpp and Ollama for local use. TensorFold has no qualified Mistral model.
4. Wire parsers and the reasoning toggle from `references/parsers-and-templates.md`. Check
   `references/known-issues.md` for the exact model and engine before declaring done.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables. Hugging Face tokens go in
  `HF_TOKEN` or the login cache, never on a command line.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date.
- **Native tokenizer mode first.** On vLLM use `--tokenizer-mode mistral --config-format mistral --load-format mistral`
  with the official repos, plus `--enable-auto-tool-choice --tool-call-parser mistral`. Add
  `--reasoning-parser mistral` only for models that reason (Small 4, Medium 3.5, Ministral 3 Reasoning).
- **Reasoning is per request, two values only.** Small 4 and Medium 3.5 take `reasoning_effort` of `none` or `high`.
  There is no `enable_thinking` or `/think`. Default is `none`.
- **Use card sampling.** `high`: temperature 0.7 (Medium 3.5 also top_p 0.95). `none`: 0.0 to 0.7. Large 3 and
  Ministral 3 Instruct: below 0.1.
- **Re-pull old Medium 3.5 conversions.** GGUFs, quants and finetunes made from its Transformers config before
  2026-05-01 carry a YaRN bug that hurts long context.
- **Bind to loopback** unless the user approved exposure, and sit behind an authenticated gateway.

## Serving the family

- [ ] Pick model, format and engine -> `references/models.md`, `references/platforms-and-quants.md`
- [ ] Check disk and memory against the sizes, set `--max-model-len` smaller than 262144 if memory is tight
- [ ] Build the launch command and toggles -> `references/parsers-and-templates.md`
- [ ] Smoke test: one plain chat, one request with `reasoning_effort` (Small 4, Medium 3.5), one tool call, and for
      vision models one image. Confirm tool calls arrive in `tool_calls` and reasoning in `reasoning` (vLLM) or
      `reasoning_content` (SGLang, llama.cpp), not as raw `[TOOL_CALLS]` or `[THINK]` text in `content`.
- [ ] Compare symptoms against `references/known-issues.md` when output looks wrong
- [ ] Verify: the endpoint answers all four smoke tests and the context limit and quant match what the user chose.

## Reference index

- `references/models.md`: current generations (Large 4 pending, Medium 3.5, Small 4, Large 3, Ministral 3, Devstral 2), sizes, active parameters, context, licenses, legacy models. Load first.
- `references/parsers-and-templates.md`: tokenizer modes, template tokens, `reasoning_effort`, per-engine parser flags, copy-ready vLLM, SGLang and llama.cpp commands, sampling. Load when writing a launch command.
- `references/platforms-and-quants.md`: official and community quants, DGX Spark, RTX, Apple Silicon, datacenter, Ollama, TensorRT-LLM, TensorFold. Load when sizing hardware.
- `references/known-issues.md`: symptom to cause and fix table, plus open gaps. Load when something breaks.

## Companion skills

- `self-hosted-llms`: the full gateway, swapping and exposure stack on Linux GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `local-llms`: running models on a laptop. Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `model-quantization`: making or choosing GGUF, FP8 and NVFP4 quants. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `fine-tuning-llms`: finetuning Mistral models. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `cloud-llms`: calling Mistral through a hosted API instead. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
