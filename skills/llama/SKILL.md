---
name: llama
description: Serve Meta's open models, Muse Glimmer 30B and Llama 4 Scout/Maverick (plus Llama 3.x), with the right template, parsers, quant and sampling. Use for Llama 4, Llama-4-Scout-17B-16E, Maverick, Llama 3.3 70B, Muse Glimmer, meta-models/Muse-Glimmer-30B, llama4_pythonic, llama3_json, muse_glimmer parser, ATEM tool calls, reasoning_strength, "unknown model architecture muse-glimmer", empty content from a reasoning model, or choosing a Llama quant for DGX Spark, RTX, Apple Silicon or H100/B200. Not for choosing an engine (choosing-inference-engine) or generic server setup (self-hosted-llms).
license: MIT
compatibility: Linux or macOS with shell, curl and jq. Model downloads are large and need the user's approval. Llama 4 weights are gated behind Meta's license on Hugging Face.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Llama

Pick the right Meta model and serve it with the correct chat template, tool-call and reasoning parser, sampling, quant and context on the user's platform.

**Scope:** this model family: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Hardware and memory
nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv 2>/dev/null
uname -sm; (sysctl -n hw.memsize 2>/dev/null || free -g 2>/dev/null)

# Engines and versions already present (versions gate Muse Glimmer support)
command -v vllm >/dev/null && vllm --version
command -v sglang >/dev/null && sglang version
command -v llama-server >/dev/null && llama-server --version 2>&1 | head -2
command -v ollama >/dev/null && ollama --version && ollama list | grep -i -E 'llama|muse'
docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i -E 'vllm|sglang|tensorrt'

# Already-served Meta model?
curl -fsS http://127.0.0.1:8000/v1/models 2>/dev/null | jq -r '.data[].id' | grep -i -E 'llama|muse'
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i -E 'llama|muse'
```

## Decision flow

1. **Which model?** Meta's newest open model is **Muse Glimmer 30B** (August 2026, Apache 2.0, dense, reasoning, vision, 128K). The newest model named Llama is still **Llama 4** (Scout 109B/17B active, Maverick ~400B/17B active; April 2025, custom Llama license). Meta's frontier Muse Spark models are API-only, not open weights. Details: `references/models.md`.
2. If the user says "Llama" and wants an agent or coding model on one GPU, suggest Muse Glimmer; if they need Llama 4 specifically (10M-context Scout, license or fine-tune reasons) or a Llama 3.x model, serve that. Say which one you chose and why.
3. **Which engine and flags?** The two families differ completely: Muse Glimmer uses channel-scoped output with `muse_glimmer` (vLLM) or `muse` (SGLang) parsers; Llama 4 uses the pythonic tool format. See `references/parsers-and-templates.md`.
4. **Which quant and platform?** See `references/platforms-and-quants.md` (DGX Spark, RTX 5090, Apple Silicon, H100/B200).
5. If a launch fails or tools or reasoning misbehave, check `references/known-issues.md` before changing flags.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules and exposure need approval and an undo path. Ask before downloading weights (Muse BF16 is about 60 GB, Llama 4 Scout BF16 over 200 GB).
- **Secrets never touch output.** Keys live in `0600` files or environment variables, including the Hugging Face token for gated Llama repos.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. Muse Glimmer docs from Meta lag the engines: re-check the engine recipe page.
- **Muse Glimmer: never greedy, never stop on `<|eom|>`, never pass `--chat-template`.** Use `temperature 1.0, top_p 0.95, top_k 64`, parser names with underscores in vLLM, and give `max_tokens` room for the reasoning trace.
- **Llama 4: use the pythonic parser and its template.** `llama4_pythonic` with `tool_chat_template_llama4_pythonic.jinja`; the JSON parser name does not match the model's default output.
- **Numerics-changing choices need a quality gate.** A quant, KV dtype or speculative decoding change passes a task eval (`llm-evals`), not only a speed benchmark.
- **Mind the license.** Llama 4 needs "Built with Llama" attribution, a `Llama` model-name prefix for derived models and a licence request above 700M MAU. Muse Glimmer is Apache 2.0.

## Serving the family

- [ ] Choose model and size from the discovered memory -> `references/models.md`
- [ ] Choose engine, parser flags and template -> `references/parsers-and-templates.md`
- [ ] Choose quant and context for the platform -> `references/platforms-and-quants.md`
- [ ] Smoke-test chat, one tool call and (for Muse) the reasoning field; the reply must have non-empty `content`, `tool_calls` in the JSON (not as text) and reasoning outside `content`.
- [ ] Verify: `/v1/models` lists the served name, a tool-call request returns `finish_reason: "tool_calls"`, and sampling matches the card. Run `llm-evals` before declaring a quant done.

## Reference index

- `references/models.md`: current Meta generations, sizes, active parameters, context, licenses and official quantized artifacts. Load first.
- `references/parsers-and-templates.md`: chat formats, tool-call and reasoning parser names for vLLM, SGLang, llama.cpp, Ollama, TensorRT-LLM, TensorFold, plus reasoning toggles and sampling.
- `references/platforms-and-quants.md`: per-platform recommendations for DGX Spark, RTX, Apple Silicon and datacenter GPUs, with commands.
- `references/known-issues.md`: open and closed bugs, stale upstream docs, and symptom-to-fix rows.

## Companion skills

- `vllm`: install and tune vLLM. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `sglang`: install and tune SGLang. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `llama-cpp`: build and serve GGUF. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `ollama`: run models in Ollama. Install: `npx skills add ScaleDockHQ/llms-skills --skill ollama`.
- `tensorrt-llm`: NVIDIA TensorRT-LLM serving. Install: `npx skills add ScaleDockHQ/llms-skills --skill tensorrt-llm`.
- `mlx`: Apple Silicon MLX. Install: `npx skills add ScaleDockHQ/llms-skills --skill mlx`.
- `self-hosted-llms`: the full serving stack, gateway and exposure. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `model-quantization`: quantize or compare formats. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `llm-evals`: quality gates after a quant or engine change. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
