# Long Context: quality gate

> Verified against llm-evals skill v1.0.1 (workflow 3, quality-gate a numerics change), Qwen3-30B-A3B model card (static YaRN guidance), vLLM v0.31.0 (context_extension), 2026-10-11

Install the gate tooling: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`. This page adds the long-context checks. The generic baseline-versus-candidate method lives in that skill.

## Which changes need the gate

- RoPE, YaRN, linear or dynamic scaling (`--hf-overrides` with `rope_parameters`, `--json-model-override-args`, `--rope-scaling` and `--yarn-*` in llama.cpp, an edited `config.json`).
- A larger window on a model that was not trained or validated for it.
- KV-cache quantization or offload used to afford the window.
- Sliding-window overrides (`--disable-sliding-window`, `max_attention_window`).
- Raising only the context flag within the native window does not change numerics, but run the needle check once to catch silent truncation.

## Procedure

1. **Baseline.** Serve the current production config. Run the user's golden set (short prompts) through the `llm-evals` promptfoo flow with `temperature 0`, a fixed seed and the same chat template. Run baseline against itself once to measure noise.
2. **Build the long-context set.** Use the user's real long documents where possible (strip PII first). Add synthetic checks:
   - **Needle in a haystack:** plant one fact at depths of 10%, 50% and 90% of the prompt, ask for it. Reference harness: https://github.com/gkamradt/LLMTest_NeedleInAHaystack.
   - **RULER-style tasks:** multi-needle retrieval, variable tracking, aggregation and long-document question answering at several lengths. Reference: https://github.com/NVIDIA/RULER. Run it against the OpenAI-compatible endpoint if the harness supports it, otherwise reimplement the tasks as promptfoo tests.
   - Lengths: 25%, 50%, 75% and 100% of the new window, and one length at the old native window so you can compare against the baseline.
3. **Candidate.** Change exactly one option. Disable prefix and prompt caches for the run, otherwise repeated prefixes hide errors.
4. **Compare per item.** Count flips, check critical items, and plot retrieval accuracy against length. Look for a cliff, where accuracy falls sharply past some length: set the served window below it.
5. **Short-prompt regression check.** Re-run the short golden set on the candidate. Static YaRN can lower short-text quality (Qwen model card). If it drops beyond the noise, either lower the factor, serve a second long-context deployment only for long requests, or skip extension.
6. **Cost check.** Record KV capacity from the startup log, peak memory, time to first token at the longest length and decode speed at the longest length.
7. **Decide and record.** Pass, fail or pass-with-conditions, with the numbers, commands and result files, using the `llm-evals` decision record. State the longest length that passed. Serve no more than that.

## Rollback

- Keep the previous launch command (and config.json if edited) as the rollback. Prefer overriding at launch (`--hf-overrides`, `--json-model-override-args`) over editing model files, so rollback is a restart.
- If a model file was edited, keep the original `config.json` copy beside it.
- If a gate fails, change one thing back, not several.

## Pass criteria (set before running, adjust to the user's risk)

- Needle retrieval at least as good as the vendor-documented or baseline accuracy at every length you will serve.
- No short-prompt regression beyond baseline noise.
- No critical item regresses.
- No OOM, truncation warnings or engine restarts during a 30 minute soak at target concurrency and length.
