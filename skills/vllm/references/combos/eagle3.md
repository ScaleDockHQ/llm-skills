# EAGLE-3 speculative decoding

> Verified against vLLM v0.31.0 docs (`features/speculative_decoding/eagle.md`, `speculators.md`) and `SpeculativeConfig` in source, 2026-10-11

Speedups on your hardware are unmeasured here.

Use to cut decode latency for one or a few users (chat, coding assistants). Gains shrink as batch size grows,
so do not enable it blindly on a busy shared server. Output quality is unchanged: accepted tokens are exactly
what the target model would produce (upstream statement).

## Serve with an EAGLE-3 draft

Requires a draft model trained for **your exact target model** (EAGLE heads are model-specific).

```bash
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --speculative-config '{"method":"eagle3","model":"RedHatAI/Llama-3.1-8B-Instruct-speculator.eagle3","num_speculative_tokens":3}'
```

- `method`: `eagle` (EAGLE-1/2 drafts) or `eagle3`. `num_speculative_tokens` is the number of draft tokens
  proposed per step; upstream's examples use 2. Try 2-5 and measure acceptance.
- `draft_tensor_parallel_size`: upstream examples use 1 for an `eagle` draft with TP 4, and equal to the target TP
  for the `eagle3` example. Keep it at 1 unless you see a reason.
- Where to find drafts: the RedHatAI speculator collection on Hugging Face, `yuhuili/*` EAGLE models, or the
  model vendor's own EAGLE-3 or MTP heads. Train your own with vLLM's Speculators project
  (https://github.com/vllm-project/speculators).
- Alternatives that need no extra weights: `ngram` and `suffix` (good for code editing and repetitive output), and
  model-native `mtp` for models that ship MTP layers. See `references/features.md`.
- Memory: the draft model and its KV cache take GPU memory; lower `--max-model-len` or
  `--gpu-memory-utilization` if loading fails, and leave extra headroom on unified-memory systems.

## Measure

1. Baseline: `vllm bench serve` at concurrency 1 and at your real concurrency, without speculation.
2. Repeat with `--speculative-config`. Compare TPOT and tokens/s; ITL looks worse with speculation because outputs
   are bundled (`references/performance-tuning.md`).
3. Watch the speculative-decoding series on `/metrics` (accepted vs proposed tokens) to tune
   `num_speculative_tokens`; per-request acceptance metrics are described in upstream `acceptance_metrics.md`.
4. Re-check after every vLLM upgrade; speculative-decoding config and supported methods change between minors.

## Pitfalls

- A mismatched draft (wrong base model or a different fine-tune) gives low acceptance and a slowdown.
- Speculative decoding may not combine with every feature (pipeline parallelism, some structured-output paths,
  some quantization formats). Which combinations work in v0.31.0 is unverified here; test the exact command.
- Quantizing the target does not require quantizing the draft, but a poorly matched quantized target lowers acceptance.
