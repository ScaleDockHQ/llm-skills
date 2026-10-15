---
name: speculative-decoding
description: Speed up LLM token generation with speculative decoding (EAGLE-3, MTP, draft model, n-gram, suffix, DFlash) on vLLM, SGLang, TensorRT-LLM, llama.cpp, TensorFold, Ollama and ExLlamaV3, with exact per-engine flags. Use for "speculative decoding", "draft model", "--speculative-config", "--speculative-algorithm", "--spec-type", "draft_num_predict", low acceptance rate, slower under load, or gating it with llm-evals.
license: MIT
compatibility: Linux, macOS or Windows host running an LLM engine. Uses nvidia-smi, curl and jq for read-only discovery. Restarting an engine or changing launch flags needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Speculative Decoding

Cut per-token latency at low and medium concurrency by letting a cheap drafter propose tokens that the target model verifies in one pass. This skill picks a method, gives the exact per-engine flags, and gates the change before it reaches users.

**Scope:** this cross-product technique, with per-engine flags and quality gates. Product install and tuning stay in product skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Which engine and version is serving, and with which flags
ps -eo pid,args | grep -E 'vllm|sglang|trtllm|llama-server|tensorfold|ollama|tabby' | grep -v grep
vllm --version 2>/dev/null; python3 -m sglang.launch_server --help >/dev/null 2>&1 && pip show sglang 2>/dev/null | head -2
trtllm-serve --help >/dev/null 2>&1 && pip show tensorrt_llm 2>/dev/null | head -2
llama-server --version 2>&1 | head -2; tensorfold-native --version 2>/dev/null; ollama --version 2>/dev/null

# Hardware and free memory (drafters and CUDA graphs need extra VRAM)
nvidia-smi --query-gpu=name,compute_cap,memory.used,memory.total --format=csv 2>/dev/null

# What is served and is speculation already on (OpenAI-compatible endpoint; add a key header from a 0600 file if needed)
curl -fsS "${BASE_URL:-http://127.0.0.1:8000}/v1/models" | jq -r '.data[].id'
curl -fsS "${BASE_URL:-http://127.0.0.1:8000}/metrics" 2>/dev/null | grep -iE 'spec_decode|draft' | head
```

Also read: the model card for a native MTP head or a published EAGLE-3/DFlash drafter for exactly this target checkpoint, the expected concurrency, and the workload (code edits and summaries repeat their input; open chat does not).

## Decision flow

1. **Is the workload latency-bound at low or medium concurrency?** If the server runs at saturating batch sizes, expect little or no gain, and a drafter costs memory. Stop here for throughput-only fleets.
2. **Does the model ship native MTP heads?** Use MTP (vLLM `method: mtp`, TensorRT-LLM `MTP`, llama.cpp `draft-mtp`, ExLlamaV3 `draft_mode: mtp`). No second model to load.
3. **Is there a trained EAGLE-3 drafter for this exact target?** Use EAGLE-3 (vLLM `eagle3`, SGLang `EAGLE3`, TensorRT-LLM `Eagle`, llama.cpp `draft-eagle3`). Drafters are target-specific; do not reuse one across checkpoints.
4. **Is there a small model that shares the target's tokenizer and vocabulary?** Use a draft model (vLLM `draft_model`, SGLang `STANDALONE`, llama.cpp `draft-simple`, TensorRT-LLM `DraftTarget`). Mismatched tokenizers give an extremely low acceptance rate.
5. **Output repeats its input (code edits, summaries, RAG, multi-turn)?** Use a model-free method: n-gram or suffix (vLLM `ngram`/`suffix`, SGLang `NGRAM` on CUDA, llama.cpp `ngram-*`, TensorRT-LLM `NGram`). Cheap, safe default to try first.
6. **Otherwise** leave it off. Speculation is not free: it adds memory, startup time and tuning.

Engine-specific flags, defaults and constraints: `references/engine-matrix.md`. Method trade-offs and tuning order: `references/methods-and-tuning.md`.

## Rules

- **Ask before changing the system.** Restarting an engine or editing launch flags needs approval and an undo path (keep the old command or unit file).
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Flags move fast. Read the engine's current docs and `--help` for the installed version before applying a flag from this skill.
- **"Lossless" still needs a gate.** Upstream describes exact verification as lossless up to hardware numerics, and vLLM states logprobs and outputs can still vary with floating point and batch size. Gate every deployment (below). Anything that relaxes acceptance is lossy by design.
- **Never ship benchmark-only switches.** vLLM `rejection_sample_method: synthetic`, llama.cpp `--spec-synth-len` and `--spec-synth-rates` produce invalid model output on purpose.
- **Measure at your real concurrency.** A win at batch 1 can vanish at batch 32.

## Quality gate

Gate with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`). Procedure:

1. **Baseline.** Same engine, version, model, context and sampling, speculation off (vLLM: omit `--speculative-config`; SGLang: omit `--speculative-algorithm`; llama.cpp: `--spec-type none`; TensorFold: `--no-drafts`; TensorRT-LLM: omit `speculative_config`; Ollama: `draft_num_predict 0`).
2. **Candidate.** Change only the speculation flags.
3. **Run both** on the user's own eval set through the same endpoint path: greedy first (expect identical or near-identical outputs; report the share of byte-identical answers), then at production temperature with repeated runs to learn the noise floor.
4. **Decide the threshold before running.** The user picks it and writes it down: allowed pass-rate drop beyond baseline-vs-baseline noise, and a list of critical items that must not regress. Record it in the decision record from `llm-evals` `references/quality-gates.md`.
5. **Treat lossy variants as quantization-grade changes:** relaxed acceptance (TensorRT-LLM `use_relaxed_acceptance_for_thinking`), SGLang acceptance thresholds below `1.0`, forced greedy verification, and any drafter vocabulary or sampling shortcut. Hold them to a stricter bar.
6. **Rollback.** Keep the baseline launch command ready. On a failed gate or a latency regression, restart without speculation and record why.

## Techniques per engine

- [ ] Choose the method with the decision flow above. -> `references/methods-and-tuning.md`
- [ ] Pick the engine's flags, defaults and constraints. -> `references/engine-matrix.md`
- [ ] Apply on a copy of the launch command or a staging port; keep the baseline running.
- [ ] Tune draft length from the measured acceptance rate, not from a blog post. -> `references/methods-and-tuning.md`
- [ ] Run the quality gate, then the speed benchmark with the same prompts at your real concurrency.
- [ ] Verify: the engine logs or metrics show drafts proposed and accepted (vLLM `vllm:spec_decode_num_accepted_tokens_total` and `vllm:spec_decode_num_draft_tokens_total`; llama.cpp prints `draft acceptance rate`), tokens per second at your concurrency beats the baseline, the gate passed, and the rollback command is recorded.

## Reference index

- `references/engine-matrix.md`: per-engine flag matrix (vLLM, SGLang, TensorRT-LLM, llama.cpp, TensorFold, Ollama, ExLlamaV3) with defaults, constraints, incompatibilities and unverified items. Load for any apply step.
- `references/methods-and-tuning.md`: when each method wins, memory costs, draft-length tuning, acceptance metrics, troubleshooting (low acceptance, OOM, slower under load). Load when choosing or tuning.

## Companion skills

- `llm-evals`: A/B quality gate and decision record. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `vllm`: install and operate vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: install and operate SGLang. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `tensorrt-llm`: install and operate TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `llama-cpp`: install and operate llama.cpp. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `ollama`: install and operate Ollama. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
- `tensorfold`: install and operate TensorFold. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorfold`.
- `exllamav3`: install and operate ExLlamaV3 and TabbyAPI. Install: `npx skills add ScaleDockHQ/llm-skills --skill exllamav3`.
- `choosing-inference-engine`: pick an engine first. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `kv-cache-quantization`: shrink KV memory; check compatibility with drafters. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`.
- `reasoning-models`: thinking-phase behavior and budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill reasoning-models`.
- `structured-outputs`: constrained decoding interacts with drafting. Install: `npx skills add ScaleDockHQ/llm-skills --skill structured-outputs`.
- `self-hosted-llms`: run the stack on owned GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
