# Inspect AI Skill

An agent skill for running [Inspect AI](https://inspect.aisi.org.uk/) (`inspect eval`, `inspect-ai`), the open-source LLM and agent evaluation framework from the UK AI Security Institute and Meridian Labs. It covers a pinned install, Task, dataset and scorer code, model providers for vLLM, Ollama, llama.cpp and LiteLLM, reasoning models, model-graded scoring with a separate grader role, concurrency, retries, eval sets, logs and Inspect View, caching, sandboxes, troubleshooting and updating. Verified against inspect-ai 0.3.278 (2026-10-11) from the docs and PyPI; the CLI could not be run on the writing machine (Python 3.9, Inspect needs 3.10+).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill inspect-ai
```

## Rules

- **Pin the version** in a venv per project and re-run the baseline after a bump.
- **Bind a grader that is not the model under test**; otherwise `model_graded_qa()` falls back to the evaluated model.
- **Deterministic scorers first**, model grading where text matching cannot work.
- **Smoke with `--limit` first**, then the full run.
- **Keys from the environment**; never in `-M` model args, which are written to logs.
- **Sandbox model-run code**, and ask before installs, downloads, Docker builds and paid calls.

## References

- [`references/install.md`](references/install.md): Python, pinning, `inspect-evals`, `.env`, maintenance.
- [`references/endpoints.md`](references/endpoints.md): providers, env vars, reasoning, gateways.
- [`references/tasks.md`](references/tasks.md): Task, datasets, solvers, run config.
- [`references/scoring.md`](references/scoring.md): scorers, model grading, metrics, re-scoring.
- [`references/running.md`](references/running.md): concurrency, errors, eval sets, logs, caching, sandboxes.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrade procedure.

**Templates:** [`templates/dataset.example.jsonl`](templates/dataset.example.jsonl), [`templates/compare-logs.sh`](templates/compare-logs.sh).

## Companion skills

- `llm-evals`: eval strategy and gates.
- `promptfoo`: YAML golden-set tests.
- `lm-evaluation-harness`: EleutherAI public benchmarks.
- `vllm`, `litellm`: usual targets and gateway.
- `reasoning-models`: thinking-token handling.

## Upstream credits

- [UKGovernmentBEIS/inspect_ai](https://github.com/UKGovernmentBEIS/inspect_ai), MIT licensed.

## License

MIT
