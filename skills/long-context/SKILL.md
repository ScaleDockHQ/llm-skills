---
name: long-context
description: Extend and serve long context windows safely with YaRN and RoPE scaling, context-length flags, chunked prefill, sliding window attention, KV-cache memory math and context parallelism, with per-engine flags for vLLM, SGLang, TensorRT-LLM, llama.cpp, TensorFold, Ollama and ExLlamaV3. Use for --max-model-len, --context-length, --hf-overrides rope_parameters, --rope-scaling yarn, num_ctx, OLLAMA_CONTEXT_LENGTH, --chunked-prefill-size, -dcp, out of memory at long prompts, "prompt too long" errors, or quality loss after context extension.
license: MIT
compatibility: Linux with NVIDIA GPUs for vLLM, SGLang and TensorRT-LLM; llama.cpp, Ollama and TensorFold also run on Apple Silicon. Needs curl and jq. Config changes and restarts need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Long Context

Raise the usable context window of a served model in the right order: fit the KV cache, set the engine's context flag, extend positions only when the model needs it, and prove with long-context tests that quality held.

**Scope:** this cross-product technique, with per-engine flags and quality gates. Product install and tuning stay in product skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print secrets or tokens.

```bash
jq '{max_pos: .max_position_embeddings, rope: (.rope_scaling // .rope_parameters), layers: .num_hidden_layers, heads: .num_attention_heads, kv_heads: .num_key_value_heads, head_dim: .head_dim, window: .sliding_window, types: .layer_types}' /path/to/model/config.json
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv
command -v vllm sglang trtllm-serve llama-server ollama tensorfold-native
curl -fsS http://127.0.0.1:8000/v1/models | jq '.data[] | {id, max_model_len, context_length}'   # vLLM and TensorFold advertise the window
ollama ps 2>/dev/null          # CONTEXT column shows the allocated window
```

Record: native context (`max_position_embeddings` and any existing `rope_scaling`), KV heads and head dim, layers, KV dtype, free memory, the context the user needs (prompt plus reply), and the number of concurrent requests.

## Decision flow

1. **Is the needed context at or below the model's native window?** Yes: set the engine's context flag to the need, do not extend RoPE. Go to the KV memory math.
2. **Does the model card already ship a long variant or document a YaRN setting?** Use the vendor's exact numbers. Some models (for example Qwen3) are validated to 4x with static YaRN. Do not invent a factor.
3. **Needed context above native and no long variant:** RoPE scaling (YaRN preferred) with `factor` set to the smallest value that covers the need (need divided by native, rounded up). This changes numerics on every request. Gate it (see Rules).
4. **KV cache does not fit?** Work down this list, one change at a time: lower concurrency, lower the context, quantize the KV cache (`kv-cache-quantization` skill), offload KV (`kv-cache-offloading` skill), add GPUs with TP or context parallel (`-dcp` in vLLM), then a smaller or sliding-window model.
5. **Time to first token on long prompts is too slow or blocks decode?** Tune chunked prefill, or add prefill context parallel where the engine supports it. See `references/engine-matrix.md`.

## Rules

- **Ask before changing the system.** Config edits, restarts and memory settings need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Flags move between releases. vLLM removed `--rope-scaling` for `--hf-overrides` with `rope_parameters`. Check `--help` of the installed version.
- **Numerics gate.** RoPE or YaRN scaling, a quantized KV cache and sliding-window overrides change outputs. Static YaRN applies the scaling to short prompts too, so short-text quality can drop (Qwen's model card says so). Gate every such change with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`) using `references/quality-gate.md`: needle-in-a-haystack and RULER-style checks at several lengths, a short-prompt regression check, and a rollback.
- **A bigger window is not better quality.** Retrieval accuracy usually drops with length. Measure at the lengths you will really use.
- **Memory first.** The flag that raises the window also reserves KV memory for it. Check the startup log for the KV capacity before announcing success.

## KV memory math

Per token, per sequence: `2 x layers x kv_heads x head_dim x bytes_per_element`. Multiply by tokens, then by concurrent sequences. This is standard arithmetic for full-attention layers; read the exact values from `config.json`.

Example: 48 layers, 4 KV heads, head dim 128, FP16 (2 bytes): `2 x 48 x 4 x 128 x 2 = 98,304` bytes per token, so 131,072 tokens is 12 GiB for one sequence. These are the Qwen3-30B-A3B layer and KV-head counts from its model card; head dim 128 is assumed here (check `config.json`). Models with sliding-window layers, MLA or linear-attention layers need less, so trust the engine's startup log over this formula. With tensor parallel the cache is split across GPUs, but KV heads fewer than TP ranks get replicated (TensorRT-LLM and vLLM docs say so).

## Techniques per engine

- [ ] Baseline: serve the current config, record KV capacity from the log, run the `llm-evals` baseline plus a short needle test (`references/quality-gate.md`).
- [ ] Set the context flag from `references/engine-matrix.md` to the real need, not the model maximum.
- [ ] Only if above native: add RoPE/YaRN scaling with the smallest factor, using the engine's exact key (vLLM `--hf-overrides`, SGLang `--json-model-override-args`, llama.cpp `--rope-scaling yarn --rope-scale N --yarn-orig-ctx N`).
- [ ] Tune chunked prefill and batch tokens for time to first token while decode runs.
- [ ] Add context parallel only for a measured memory or latency problem (vLLM `-dcp`, SGLang `--attn-cp-size` or `--dcp-size`, TensorRT-LLM `cp_size`).
- [ ] Verify: the endpoint accepts a prompt near the limit, KV capacity in the log covers the target concurrency, long-context checks pass at 25%, 50%, 75% and 100% of the new window, and short-prompt scores did not drop.

## Verify

```bash
curl -fsS http://127.0.0.1:8000/v1/models | jq '.data[] | {id, max_model_len, context_length}'
# Send a prompt of about 90% of the window (generate filler with seq or a fixture file), ask a fact planted in the middle
curl -fsS http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d @needle-request.json | jq -r '.choices[0].message.content, .usage'
```

Then run `references/quality-gate.md`. Keep the previous launch command as the rollback.

## Reference index

- `references/engine-matrix.md`: per-engine context, RoPE/YaRN, chunked prefill, sliding window and context-parallel flags with defaults and constraints, and the TensorFold, Ollama and ExLlamaV3 status. Load at the "set the flag" step.
- `references/quality-gate.md`: baseline-versus-candidate procedure with needle and RULER-style long-context checks, short-prompt regression check and rollback. Load before any RoPE, KV-dtype or window change.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`. Engine skills may not be published yet; use upstream docs until they are.

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: install, serve and tune each engine.
- `llm-evals`: the quality gate for any numerics-changing option.
- `kv-cache-quantization`, `kv-cache-offloading`, `prefix-aware-routing`: stretch memory and reuse prompts.
- `multi-node-inference`, `disaggregated-serving`: spread long prefill across nodes.
- `choosing-hardware`, `choosing-inference-engine`: pick GPUs and engine for a long-context workload.
- `moe-serving`, `multi-lora-serving`, `speculative-decoding`, `reasoning-models`: techniques that interact with context memory.
