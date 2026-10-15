# Multi-LoRA Serving: quality gate

> Verified against llm-evals skill v1.0.1 (workflow 3, quality-gate a numerics change), vLLM v0.31.0 (lora docs), SGLang v0.5.21 (lora docs), llama.cpp build b11556 (server README), 2026-10-11

Install the gate tooling: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`. This page adds the adapter-specific checks. The generic baseline-versus-candidate method lives in that skill. Adapter creation and the "does the adapter beat the base" training evaluation live in the `fine-tuning-llms` skill.

## Which changes need the gate

| Change                                                                                                                   | Why it can change outputs                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| Merging an adapter into base weights (especially into FP8, INT4 or GGUF quantized weights)                               | The merged weights are rounded at low precision; the adapter delta can be partly lost.                            |
| Serving an adapter on a quantized base it was not trained against (QLoRA-trained adapter on a BF16 base, or the reverse) | Base weights differ from training.                                                                                |
| `--lora-dtype` different from training (vLLM)                                                                            | Adapter math runs at another precision.                                                                           |
| `--lora-scaled` or `POST /lora-adapters` scale other than 1.0 (llama.cpp)                                                | The adapter delta is blended or attenuated on purpose.                                                            |
| `--lora-target-modules` restricted to fewer modules than the adapter targets (vLLM, SGLang)                              | Some adapter layers are not applied.                                                                              |
| `max_lora_rank` lower than an adapter's rank                                                                             | Should be rejected at load; if the engine truncates, quality drops. Treat any warning as a failure.               |
| Engine, kernel backend (`--lora-backend`) or version change                                                              | Different kernels.                                                                                                |
| Slot count, CPU cache, overlap loading, eviction policy                                                                  | Should not change outputs, but run the isolation check, because slot reuse bugs show up as cross-adapter leakage. |

## Procedure

1. **Define expected behavior per adapter.** For each adapter, take its training-time held-out eval set (from the `fine-tuning-llms` run) or build a 20 to 100 item golden set. Each item has an expected property (format, fact, refusal, tool call), not a full expected text.
2. **Baseline.** Serve the base model alone, and run each adapter's set against the base for the "adapter lift" reference. Then serve one adapter by the known-good path (the training framework's own inference, or a single-adapter engine launch). Record each adapter's scores. Run the baseline against itself once to measure noise.
3. **Candidate.** Change one thing: the engine, slot configuration or merge. Serve all adapters together.
4. **Per-adapter regression.** Run each adapter's set on the candidate, with `temperature 0`, a fixed seed and the same chat template. Compare with the single-adapter baseline per item. Check critical items. A delta inside baseline noise is not a regression.
5. **Isolation check.** Send interleaved requests for adapters A, B and the base in one concurrent burst (concurrency at least `--max-loras`, then above it to force eviction and reload). Each response must still match what that adapter produced alone. Any response that matches the wrong adapter or the base is a failure. Repeat after an unload and reload of one adapter, and after `load_inplace` replacement where used.
6. **Base unaffected.** Re-run the base golden set on the candidate. Base requests batched with adapters must not regress.
7. **Merge check (only if merging).** Compare merged-and-quantized against unmerged adapter serving on the same sets. If the merge loses the adapter's lift, merge at higher precision first and quantize after, or keep serving the adapter dynamically.
8. **Speed and memory.** Run `bench.sh` from the `self-hosted-llms` skill or the user's benchmark at the target concurrency, with the adapter mix expected in production. Record time to first token, decode speed, LoRA memory-pool size in the startup log, and any adapter load latency.
9. **Decide and record.** Pass, fail or pass-with-conditions, with numbers, commands and result files, using the `llm-evals` decision record.

## Rollback

- Keep the previous launch command, engine version and the adapter directory versions. Adapters are immutable files, so version them by directory name, not by replacing them in place.
- Roll back by restoring the previous launch command and restarting. For runtime-loaded adapters on vLLM, `unload_lora_adapter` the new version and `load_lora_adapter` the previous path, or use `load_inplace` back to the old path.
- For llama.cpp scale changes, `POST /lora-adapters` back to the previous scales. They are not persisted across restarts.
- If a gate fails, change one thing back, not several.

## Pass criteria (set before running, adjust to the user's risk)

- Each adapter keeps its single-adapter baseline score within the agreed margin, and its lift over the base.
- No cross-adapter leakage in the isolation check.
- Base requests do not regress.
- No OOM, load failures or engine restarts in a 30 minute soak at target concurrency and adapter mix.
