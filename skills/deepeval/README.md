# DeepEval Skill

An agent skill for running [DeepEval](https://github.com/confident-ai/deepeval) (`deepeval test run`), the pytest-based LLM evaluation framework with GEval, answer relevancy, faithfulness and other metrics. It covers a pinned install, telemetry and Confident AI data-egress controls, judge setup for local OpenAI-compatible servers, Ollama, LiteLLM and hosted models (and the invalid-JSON failure mode), test cases and metric requirements, datasets, `deepeval test run` flags, caching and local storage, CI gating, troubleshooting and updating. Verified against deepeval 4.2.8 (2026-10-11) from the docs source and metric source; the CLI could not be run on the writing machine (Python 3.9).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill deepeval
```

## Rules

- **Pin the version** and re-run the baseline after any bump.
- **Choose the judge explicitly**; with none set DeepEval falls back to OpenAI.
- **Deterministic metrics first**, judged metrics where nothing deterministic fits; pin and calibrate the judge.
- **Telemetry is on by default and `deepeval login` uploads results**: both are the user's call.
- **Secrets from the environment or `0600` dotenv files**; never printed.
- **Smoke before suite**, and do not ignore judge errors on a gate.

## References

- [`references/install.md`](references/install.md): install, telemetry, Confident AI, maintenance.
- [`references/judges.md`](references/judges.md): judge providers and JSON reliability.
- [`references/tests-and-metrics.md`](references/tests-and-metrics.md): test cases, metrics, datasets.
- [`references/running-and-ci.md`](references/running-and-ci.md): flags, cache, storage, CI.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrade procedure.

**Templates:** [`templates/test_example.py.txt`](templates/test_example.py.txt), [`templates/env.example`](templates/env.example), [`templates/deepeval-ci.yml`](templates/deepeval-ci.yml).

## Companion skills

- `llm-evals`: eval strategy and gates.
- `ragas`: RAG evaluation with Ragas.
- `promptfoo`: YAML golden-set tests.
- `vllm`, `ollama`, `litellm`: judge servers and gateway.

## Upstream credits

- [confident-ai/deepeval](https://github.com/confident-ai/deepeval), Apache-2.0 licensed.

## License

MIT
