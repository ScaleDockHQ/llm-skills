# SWE-bench Skill

An agent skill for grading coding-agent patches with [SWE-bench](https://github.com/SWE-bench/SWE-bench): pinned install, gold-patch validation, the v5 `swebench eval`, `report`, `images` and `dataset` commands, predictions JSONL, run_id caching, disk and worker sizing, Modal, and a local-model flow with mini-SWE-agent. Verified against `swebench` 5.0.2 and upstream docs (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill swe-bench
```

## Rules

- **Pin the version**; upstream `main` is ahead of PyPI.
- **Gold patches first**, then model runs.
- **New `run_id` for new patches**; results are cached by run_id and instance_id only.
- **Containers run untrusted code**: use a dedicated or disposable host.
- **Keys from the environment**, never inline.

## References

- [`references/install.md`](references/install.md): requirements, pinned install, PyPI vs `main`.
- [`references/eval-and-datasets.md`](references/eval-and-datasets.md): datasets, eval, report, images, results.
- [`references/predictions-and-inference.md`](references/predictions-and-inference.md): prediction format and agent scaffolds.
- [`references/combos/local-model-mini-swe-agent.md`](references/combos/local-model-mini-swe-agent.md): local model to graded result.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrades and drift.

## Companion skills

- `vllm`: serves the model.
- `evalplus`: function-level code benchmarks.
- `lm-evaluation-harness`: other benchmarks.
- `llm-evals`: eval strategy and gates.

## License

MIT
