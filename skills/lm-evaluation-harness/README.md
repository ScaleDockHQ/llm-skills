# LM Evaluation Harness Skill

An agent skill for running [EleutherAI's lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness) (`lm_eval`, `lm-eval`) for public benchmarks such as MMLU, GSM8K, HellaSwag and IFEval. It covers the `local-completions` and `local-chat-completions` endpoint model types (logprobs and tokenizer requirements, `--apply_chat_template`), the `hf` and `vllm` backends, task and generation settings, reasoning models (`think_end_token`), result files and limits, troubleshooting, and a benchmark screen for quantized models. Verified against v0.4.13 (2026-10-11) from docs and source; the CLI could not be run on the writing machine (Python 3.9, harness needs 3.10+).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill lm-evaluation-harness
```

## Rules

- **Benchmarks are a prior, not a decision.** Your tasks decide (see `llm-evals` and `promptfoo`).
- **Compare like with like.** Same version, tasks, few-shot, chat-template flags, generation settings and seed.
- **`--limit` is for smoke tests only.**
- **Keys through the environment.** `OPENAI_API_KEY`, never `--model_args`.
- **Chat endpoints cannot run loglikelihood tasks.** Use `local-completions` with prompt logprobs, or a local backend.
- **Isolate installs and ask before downloads.** Venv per version; datasets, weights and code-executing tasks need approval.

## References

- [`references/install.md`](references/install.md): Python and extras, versions, maintenance, environment variables.
- [`references/endpoints.md`](references/endpoints.md): endpoint model types, logprobs, tokenizer rules, `model_args`.
- [`references/backends.md`](references/backends.md): `hf` and `vllm` backends and parallelism.
- [`references/tasks.md`](references/tasks.md): tasks, chat template, generation, reasoning models, config files.
- [`references/output.md`](references/output.md): result and sample files, limits, caching, seeds.
- [`references/troubleshooting.md`](references/troubleshooting.md): errors and wrong-score causes.
- [`references/updating.md`](references/updating.md): upgrade procedure.
- [`references/combos/quant-benchmark-check.md`](references/combos/quant-benchmark-check.md): parent versus quantized benchmark screen.

**Templates:**

- [`templates/run-endpoint.sh`](templates/run-endpoint.sh): run chat or completions mode against a server.
- [`templates/compare-results.sh`](templates/compare-results.sh): metric deltas of two result files with stderr noise check.
- [`templates/eval_config.yaml`](templates/eval_config.yaml): config-file starting point.

## Companion skills

- `llm-evals`: eval strategy and quality gates.
- `promptfoo`: task evals on your own golden set.
- `vllm`, `llama-cpp`: serve the model under test.
- `model-quantization`: produce quantized candidates.
- `reasoning-models`: thinking-token handling.

## Upstream credits

- [EleutherAI lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness), MIT licensed.

## License

MIT
