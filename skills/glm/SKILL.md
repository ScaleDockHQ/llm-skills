---
name: glm
description: Serve Z.ai (Zhipu) GLM open-weight models (GLM-5.3, 5.3-Flash, 5.2, 4.7-Flash, 4.x). Covers chat templates, glm45/glm47 parsers for vLLM, SGLang and TensorRT-LLM, reasoning_effort, GGUF/NVFP4 quants, licenses and bugs. Use for glm-5.3, GlmMoeDsa, Glm5Next, ox-alpha, reasoning_content empty, tool calls as raw text. Hosting stack goes to self-hosted-llms.
license: MIT
compatibility: Linux or macOS with curl and jq for the read-only checks. Installs, container pulls and large weight downloads (hundreds of GB) need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# GLM

Pick the right GLM generation and serving setup for the hardware at hand, then launch it with the correct tool-call parser, reasoning parser and chat-template switches.

**Scope:** Z.ai GLM open-weight text and vision-language models: chat templates, tool and reasoning parsers per engine, recommended quants per platform, context limits, licenses and known bugs. The gateway, systemd, exposure and benchmarking around the engine belong to `self-hosted-llms`.

Work through the steps in order. Load a reference only when a step names it. Verified 2026-10-11; engines move weekly, so re-read the linked recipe before copying flags.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Hardware and free memory (a GLM-5.3 FP8 node needs ~800+ GB of GPU memory; Flash ~390 GB)
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
uname -sm; sysctl -n hw.memsize 2>/dev/null; free -g 2>/dev/null | head -2
# Engines already installed and their versions
for c in vllm sglang trtllm-serve llama-server ollama tensorfold; do command -v "$c" && "$c" --version 2>&1 | head -1; done
python3 -c 'import vllm,transformers;print("vllm",vllm.__version__,"transformers",transformers.__version__)' 2>/dev/null
# Is a GLM already served? Parsers and model id show in /v1/models and the process line
curl -s localhost:8000/v1/models | jq -r '.data[].id' 2>/dev/null
ps aux | grep -E 'vllm|sglang|llama-server|trtllm' | grep -v grep | cut -c1-240
# Weights already on disk
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i -E 'glm'
```

## Decision flow

1. Pick the model from memory, not from preference (`references/models.md`, `references/platforms-and-quants.md`):
   - Server with 8x H200/B200: `zai-org/GLM-5.3` (FP8, 1M context, text only).
   - 4 to 8 data-centre GPUs, or multimodal: `zai-org/GLM-5.3-Flash` (320B-A18B, FP8 ~386 GB, image and video input).
   - One DGX Spark (128 GB) or a 128 GB Mac: only 1 to 2-bit GGUF of GLM-5.3-Flash fits, with a quality tax. Prefer `zai-org/GLM-4.7-Flash` (30B-A3B) when quality per GB matters more than the newest generation.
   - One 24 GB RTX: `GLM-4.7-Flash` Q4 (Ollama `glm-4.7-flash` is 19 GB).
2. Pick the engine. vLLM and SGLang are the documented routes for 5.3; TensorRT-LLM covers GLM-5.x on B200; llama.cpp covers GLM-5.3-Flash (mainline since 2026-09-30, `glm5-next`) and GLM-4.7-Flash; Ollama runs only `glm-4.7-flash` locally. GLM-5.3 (non-Flash) in llama.cpp: Unsloth GGUFs exist (`unsloth/GLM-5.3-GGUF`).
3. Set the three things that break GLM serving (`references/parsers-and-templates.md`):
   - `--tool-call-parser glm47` on every GLM-4.7 and GLM-5.x model (`glm45` leaves GLM-5.x tool calls as raw text).
   - `--reasoning-parser glm47` (vLLM 5.3 recipes) or `glm45` (SGLang, model cards); both appear in upstream docs.
   - Reasoning controls differ per generation: GLM-5.3 and 5.3-Flash cannot disable thinking; use `reasoning_effort` and pass `clear_thinking=true` for chat.
4. Check the licence before shipping. GLM-5.3 is not MIT; GLM-5.3-Flash, 5.2 and 4.7 are (`references/models.md`).
5. Before launch, read `references/known-issues.md` for the engine and model you picked.

## Rules

- **Ask before changing the system.** Installs, container pulls, 100s of GB downloads, services, firewall rules and exposure need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables. Never echo `HF_TOKEN`.
- **Verify upstream.** Versions, flags and defaults come from upstream docs read on the writing date. Treat engine versions in the references as minimums, not pins.
- **Sampling.** Use the card values: `temperature=1.0`, `top_p=0.95` for most tasks (details in `references/parsers-and-templates.md`). Do not hardcode in clients when the server loads `generation_config.json`.
- **Never send `enable_thinking=false` to GLM-5.3 expecting an effect.** It has no off switch; lower `reasoning_effort` instead.
- **Respect the repo checkpoint naming.** For GLM-5.3 the base repo is FP8 and `-BF16` is separate; for 5.2 and earlier it is reversed.

## Serving the family

- [ ] Choose model, size and checkpoint format for the hardware -> `references/models.md`, `references/platforms-and-quants.md`
- [ ] Install an engine build that knows the architecture (`GlmMoeDsaForCausalLM`, `Glm5NextForConditionalGeneration`, `Glm4MoeLiteForCausalLM`) -> `references/platforms-and-quants.md`
- [ ] Launch with parsers, MTP and KV settings -> `references/parsers-and-templates.md`
- [ ] Smoke-test one plain turn and one tool call. Verify: `message.reasoning_content` holds the thinking, `message.content` the answer, and a tool request returns `tool_calls` with `finish_reason: "tool_calls"`.
- [ ] Verify long context and memory: send a prompt near your intended limit before exposing the endpoint.
- [ ] Review the open bugs for your model and engine -> `references/known-issues.md`

## Reference index

- `references/models.md`: generations, sizes, active parameters, context, licences, checkpoint names and architectures.
- `references/parsers-and-templates.md`: template quirks, thinking and effort toggles, tool and reasoning parser names per engine, sampling, launch commands.
- `references/platforms-and-quants.md`: DGX Spark, RTX, Apple Silicon, H100/H200/B200, AMD; official and community FP8/NVFP4/GGUF/MLX; engine support and TensorFold status.
- `references/known-issues.md`: template crashes, output collapse, language bleed, llama.cpp and MLX caveats, tool-call loops.

## Companion skills

- `self-hosted-llms`: gateway, model swapping, exposure and benchmarking around the engine. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `local-llms`: laptop and desktop runs. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `cloud-llms`: hosted GLM through providers. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `model-quantization`: making or choosing GGUF, FP8, NVFP4 and MLX quants. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `fine-tuning-llms`: SFT and RL on GLM weights. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
