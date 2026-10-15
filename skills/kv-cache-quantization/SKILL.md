---
name: kv-cache-quantization
description: Fit more context or concurrent requests by quantizing the KV cache (FP8, NVFP4, int8, q8_0, q4_0) on vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, ExLlamaV3 and TensorFold, with exact per-engine flags and a quality gate. Use for "--kv-cache-dtype", "-ctk q8_0", "OLLAMA_KV_CACHE_TYPE", "cache_mode", KV cache OOM, out of KV blocks, "V cache quantization requires flash_attn", or long-context accuracy loss.
license: MIT
compatibility: Linux, macOS or Windows host running an LLM engine. Uses nvidia-smi, curl and jq for read-only discovery. Restarting an engine or changing launch flags needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# KV Cache Quantization

Store the attention KV cache in fewer bits so the same memory holds more tokens: longer context, more concurrent sequences, or fewer CPU-offloaded layers. This skill sizes the problem, picks a dtype per engine and hardware, applies the exact flag, and gates the quality loss before it reaches users.

**Scope:** this cross-product technique, with per-engine flags and quality gates. Product install and tuning stay in product skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# Engine, version, current KV dtype in the launch flags
ps -eo pid,args | grep -E 'vllm|sglang|trtllm|llama-server|tensorfold|ollama|tabby' | grep -v grep
vllm --version 2>/dev/null; llama-server --version 2>&1 | head -2; ollama --version 2>/dev/null
env | grep -E '^OLLAMA_(KV_CACHE_TYPE|FLASH_ATTENTION)=' 2>/dev/null

# GPU generation decides which dtypes have kernels (compute_cap 8.0 Ampere, 8.9 Ada, 9.0 Hopper, 10.0 Blackwell)
nvidia-smi --query-gpu=name,compute_cap,memory.used,memory.total --format=csv 2>/dev/null

# KV bytes per token = 2 x layers x kv_heads x head_dim x bytes_per_element (2 for f16/bf16, 1 for 8-bit)
jq '{layers:.num_hidden_layers, kv_heads:(.num_key_value_heads // .num_attention_heads), head_dim:(.head_dim // ((.hidden_size // 0) / (.num_attention_heads // 1)))}' \
  "$MODEL_DIR/config.json"

# Is the cache really the limit? Look for OOM, preemption or CPU-offloaded layers
curl -fsS "${BASE_URL:-http://127.0.0.1:8000}/metrics" 2>/dev/null | grep -i kv | head
ollama ps 2>/dev/null
```

Also read: target context length, expected concurrency, and whether the checkpoint already carries KV scales (ModelOpt or llm-compressor exports).

## Decision flow

1. **Is the KV cache the limit?** Symptoms: out-of-memory at your context, requests queued or preempted for lack of KV blocks, llama.cpp or Ollama pushing layers to CPU. If the model fits with headroom, stop: do not change numerics for nothing.
2. **Try levers that do not change numerics first:** lower the context cap or concurrency, add prefix caching, offload cold KV to CPU or disk (`kv-cache-offloading` skill), or use smaller weights (`model-quantization` skill, a separate gated change).
3. **Pick the least aggressive dtype that fits.** Order by risk: engine default (`auto`, `f16`, `bf16`), 8-bit (`fp8`/`fp8_e4m3`, `q8_0`), `fp8_e5m2` (more range, less precision), then 4-bit (`q4_0`, `nvfp4`, `fp4_mx_block16`), which are the likeliest to hurt long-context and reasoning quality.
4. **Check hardware and backend support** in `references/engine-matrix.md`. Unsupported combinations either fail at startup or silently fall back to slow paths.
5. **Prefer calibrated scales** where the engine supports them (vLLM: calibrate with llm-compressor; SGLang: scales from the checkpoint or `--quantization-param-path`). Default scales of 1.0 can cause accuracy problems.
6. **Apply on a staging port, keep the baseline running, run the quality gate, then roll out.**

## Rules

- **Ask before changing the system.** Restarting an engine or editing launch flags needs approval and an undo path (keep the old command or unit file).
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Dtype names and support change per release. Check the installed engine's `--help` before using a value from this skill.
- **KV quantization changes numerics.** Never enable it on the basis of a speed or memory benchmark alone. Gate it (below).
- **Test at the longest context you serve.** Upstream notes quantization error accumulates with context length, and small models and reasoning tasks suffer most.
- **Change one thing.** Hold weights, sampling, context and engine version constant between baseline and candidate.

## Quality gate

Gate with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`). Procedure:

1. **Baseline:** current KV dtype (`auto`/`f16`/`bf16`), same engine version, model, sampling and context.
2. **Candidate:** only the KV dtype (and its scales) changes.
3. **Eval set:** the user's own golden set, including the longest-context and multi-step reasoning items they serve, plus a handful of retrieval-from-long-context items. Perplexity or KL divergence is a quick screen, not a replacement for task results.
4. **Run both** through the same endpoint path, greedy first and then at production temperature with repeated runs to measure the noise floor.
5. **Set the acceptance threshold before running.** The user chooses: allowed pass-rate drop beyond baseline-vs-baseline noise, and critical items that must not regress. Write it in the `llm-evals` decision record.
6. **Rollback:** keep the baseline launch command. If the gate fails, restart with the baseline dtype, or try the next less aggressive dtype, or skip sensitive layers where the engine allows it (vLLM `--kv-cache-dtype-skip-layers`).

## Techniques per engine

- [ ] Compute KV bytes per token and the gain at the target dtype. -> `references/sizing-and-quality.md`
- [ ] Pick the dtype, flag and constraints for your engine and GPU. -> `references/engine-matrix.md`
- [ ] Start a staging instance with the candidate dtype; keep the baseline.
- [ ] Run the quality gate above, at your longest context.
- [ ] Benchmark speed at real concurrency. A dtype without fused attention support can be slower than f16 (SGLang warns of extreme slowdowns; llama.cpp can fall back to CPU attention without a CUDA build option).
- [ ] Verify: the engine reports a larger token capacity (or the model stays fully on GPU), the gate passed, tokens per second at your concurrency is not worse, and the rollback command is recorded.

## Reference index

- `references/engine-matrix.md`: per-engine flag matrix (vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, ExLlamaV3, TensorFold) with dtypes, defaults, hardware, constraints and unverified items. Load for any apply step.
- `references/sizing-and-quality.md`: KV size arithmetic, expected gains, upstream accuracy evidence, calibration, and troubleshooting. Load when sizing or when the gate shows loss.

## Companion skills

- `llm-evals`: A/B quality gate and decision record. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `vllm`: install and operate vLLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `sglang`: install and operate SGLang. Install: `npx skills add ScaleDockHQ/llm-skills --skill sglang`.
- `tensorrt-llm`: install and operate TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`.
- `llama-cpp`: install and operate llama.cpp. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `ollama`: install and operate Ollama. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
- `tensorfold`: install and operate TensorFold. Install: `npx skills add ScaleDockHQ/llm-skills --skill tensorfold`.
- `exllamav3`: install and operate ExLlamaV3 and TabbyAPI. Install: `npx skills add ScaleDockHQ/llm-skills --skill exllamav3`.
- `model-quantization`: weight and calibrated KV-scale checkpoints (ModelOpt, llm-compressor, GGUF). Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `kv-cache-offloading`: move KV to CPU or disk instead of shrinking it. Install: `npx skills add ScaleDockHQ/llm-skills --skill kv-cache-offloading`.
- `long-context`: long-context serving and evaluation. Install: `npx skills add ScaleDockHQ/llm-skills --skill long-context`.
- `speculative-decoding`: drafters add KV and memory cost. Install: `npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding`.
- `choosing-hardware`: size GPUs and memory. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `self-hosted-llms`: run the stack on owned GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
