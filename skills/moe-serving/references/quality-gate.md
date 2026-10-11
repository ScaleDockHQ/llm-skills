# MoE Serving: quality gate

> Verified against llm-evals skill v1.0.1 (workflow 3, quality-gate a numerics change), vLLM v0.31.0 (parallel.py, kernel.py), SGLang v0.5.21 (server_arguments), TensorRT-LLM v1.2.1 (llm_args.py), 2026-10-11

Install the gate tooling: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`. This page adds the MoE-specific parts. The generic baseline-versus-candidate method lives in that skill.

## Which options need the gate

| Option                                                                                                                             | Why it can change outputs                                                               |
| ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Quantized MoE kernel (`--moe-backend deep_gemm`, `flashinfer_cutedsl`, `marlin`; `--moe-runner-backend ...`; `moe_config.backend`) | Different precision paths for expert GEMMs (FP8 block-quantized, FP4, mixed).           |
| Low-precision dispatch or combine (`--deepep-dispatcher-output-dtype fp8`/`nvfp4`, `use_low_precision_moe_combine`)                | Activations are quantized in transit between ranks.                                     |
| Expert offload with a lossy quant (SGLang `--kt-method AMXINT4`, CPU-side INT4 or INT8 experts)                                    | Experts are re-quantized for the CPU kernel.                                            |
| Switching checkpoint format (BF16 to FP8, FP4, GGUF) to make offload fit                                                           | New weights. Use the `model-quantization` skill and gate.                               |
| EP, EPLB, redundant experts, offload at the same dtype                                                                             | Not intended to change quality. Reduction order can differ, so run the smoke gate only. |

## Procedure

1. **Baseline.** Record the production launch command, engine version and image digest. Serve it. Run the user's golden set (and, if wanted, an `lm_eval` subset) through the `llm-evals` promptfoo flow with `temperature 0`, fixed seed, the same max tokens and chat template. Run the baseline against itself once to measure noise.
2. **Candidate.** Change exactly one option from the table. Serve it on another port, or restart the same one after saving the baseline results. Do not use the routing simulation env vars (`VLLM_MOE_ROUTING_SIMULATION_STRATEGY`, `VLLM_RANDOMIZE_DP_DUMMY_INPUTS`): they randomize routing and are for benchmarking only.
3. **Compare per item.** Count pass-to-fail and fail-to-pass flips, and check every `critical` item. A delta inside the baseline-versus-baseline noise is not a regression.
4. **MoE-specific checks.**
   - Long outputs: include 5 to 10 items that generate more than 1,000 tokens. Offload and quantized dispatch errors tend to show as drift late in a reply.
   - Concurrency: run the golden set at concurrency 1 and at the target concurrency. EP and offload bugs can appear only under batching.
   - Routing health: with EPLB, log balancedness (vLLM `--eplb-config '{"log_balancedness":true}'`) and confirm it improves, not only that quality holds.
   - Determinism spot check: send the same temperature-0 prompt 5 times. For TensorRT-LLM CUTLASS MoE with top-k above 2, `moe_config.disable_finalize_fusion: true` restores deterministic numerics per the source docstring, at a speed cost.
5. **Speed.** Run `bench.sh` from the `self-hosted-llms` skill (or the user's benchmark) at the same prompts for baseline and candidate. Keep the change only if the speed or memory win justifies any quality delta the user accepted in step 3.
6. **Decide and record.** Pass, fail or pass-with-conditions, with the numbers, the commands and the result files. Use the decision record in the `llm-evals` skill.

## Rollback

- Keep the baseline launch command and the previous image or version pinned until the candidate has run in production for the agreed soak period.
- Roll back by restoring the baseline command and restarting. Offload and EP changes are launch-time flags, so no state migrates.
- If a gate fails, change one thing back, not several, so the cause is known.

## Pass criteria (set before running, adjust to the user's risk)

- No critical item regresses.
- Aggregate score within the agreed margin of baseline, and outside the noise only in the improving direction.
- No new failure types at target concurrency, no OOM or all-to-all timeouts in the logs during a 30 minute soak.
