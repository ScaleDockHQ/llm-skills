# EvalPlus: troubleshooting

> Verified against EvalPlus 0.3.1 (docs `cli.md`, `execution.md`, README, source at v0.3.1), 2026-10-11

Upstream has no troubleshooting page; entries come from the source and docs. (unverified) marks general experience.

| Symptom                                           | Cause and fix                                                                                                                                                                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Pass@1 near zero on a reasoning model             | The 768-token cap is spent on thinking, so no code block is returned. Disable thinking or generate samples yourself (`run-and-backends.md`)                                                                              |
| Scores far below published                        | Chat vs base prompt mismatch, truncation at 768 tokens, thinking text, a different model quant or sampling defaults of the server. Compare with `--greedy` on the exact model; check `samples` for prose instead of code |
| `The model ... does not exist` (404)              | `--model` differs from the server's model id: use `/v1/models`                                                                                                                                                           |
| 400 about `max_tokens` or `max_completion_tokens` | The backend sends `max_tokens`; some newer models or hosted APIs want `max_completion_tokens`. Put a compatibility proxy in front (`litellm` skill) or generate samples yourself                                         |
| Failed samples listed with syntax errors          | Model output not compilable; run `evalplus.syncheck --samples <file> --dataset <ds>` to see before/after sanitizing                                                                                                      |
| Timeouts on correct code                          | Busy or slow machine: lower `--parallel`, raise `--min-time-limit` and `--gt-time-limit-factor`                                                                                                                          |
| Out-of-memory failures in tasks                   | Default per-process cap is `min(4 GB, system)`; raise with `EVALPLUS_MAX_MEMORY_BYTES` only if tasks legitimately need it                                                                                                |
| Rerun shows the same score after changing samples | Cache `*_eval_results.jsonl`: delete it or pass `--i-just-wanna-run`                                                                                                                                                     |
| Fewer than 164 or 378 tasks scored                | Generation interrupted (`--resume` is on, rerun codegen) or `--id-range` left over                                                                                                                                       |
| `vllm` backend fails to import or crashes         | EvalPlus `vllm` extra targets old vLLM (`>=0.5.1`); use a separate venv, or serve with the vLLM skill and use `--backend openai`                                                                                         |
| Claude or Gemini key errors                       | `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY` not exported; never inline keys                                                                                                                                                   |
| EvalPerf: perf counters unavailable               | `perf_event_paranoid` too high, or Docker without `--cap-add PERFMON` (`execution-and-evalperf.md`)                                                                                                                      |
| macOS EvalPerf                                    | Not supported ("*nix only", needs Linux perf)                                                                                                                                                                            |
| Concern: code ran on my machine                   | `evalplus.evaluate` executes samples locally; use the Docker image from now on and treat the host as suspect if the model could be adversarial                                                                           |

Report bugs at https://github.com/evalplus/evalplus/issues (check open issues first: about 78 were open at last check).
