# Lighteval Skill

An agent skill for running [Hugging Face Lighteval](https://github.com/huggingface/lighteval) (`lighteval` CLI) on public benchmarks such as MMLU, GSM8K, GPQA and IFEval. It covers a pinned install, the Inspect-backed `lighteval eval`, the `vllm`, `endpoint litellm` and `accelerate` backends, OpenAI-compatible endpoints, task strings and few-shot, reasoning-tag removal, results and per-sample details, custom tasks, troubleshooting and updating. Verified against lighteval 0.13.0 and the `main` source (2026-10-11) from docs and source; the CLI could not be run on the writing machine (Python 3.9, Lighteval needs 3.10+).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill lighteval
```

## Rules

- **Pin the version** and re-run the baseline after any bump.
- **Smoke first** with `--max-samples 5`.
- **Compare like with like**: same version, tasks, few-shot, backend and sampling.
- **`lighteval eval` caches calls and times out at 30 s by default**; raise the timeout and clear the cache for decision runs.
- **Tokens from the environment**; never inline in committed configs.
- **Ask before downloads, Hub pushes and paid calls.**

## References

- [`references/install.md`](references/install.md): Python, extras, pins, tokens, maintenance.
- [`references/backends.md`](references/backends.md): `eval`, `vllm`, `endpoint litellm`, model configs.
- [`references/tasks-and-results.md`](references/tasks-and-results.md): tasks, reasoning tags, results, custom tasks.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrade procedure.

**Templates:** [`templates/compare-results.sh`](templates/compare-results.sh), [`templates/litellm-endpoint.yaml`](templates/litellm-endpoint.yaml), [`templates/vllm-model.yaml`](templates/vllm-model.yaml).

## Companion skills

- `llm-evals`: eval strategy and gates.
- `inspect-ai`: the framework behind `lighteval eval`.
- `lm-evaluation-harness`, `promptfoo`: other eval tools.
- `vllm`, `litellm`: model server and gateway.

## Upstream credits

- [huggingface/lighteval](https://github.com/huggingface/lighteval), MIT licensed.

## License

MIT
