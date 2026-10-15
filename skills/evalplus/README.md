# EvalPlus Skill

An agent skill for scoring code-generation models with [EvalPlus](https://github.com/evalplus/evalplus): HumanEval+, MBPP+ and EvalPerf. It covers pinned install, generating samples from vLLM, OpenAI-compatible servers, Hugging Face and hosted APIs, sanitizing, sandboxed execution in Docker, pass@k on base vs extended tests, EvalPerf efficiency scoring, a quantization code-ability check and troubleshooting. Verified against EvalPlus 0.3.1 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill evalplus
```

## Rules

- **Pin the version** and record the Docker image; datasets changed across releases.
- **Execute model-written code in a sandbox** (Docker image or throwaway VM).
- **Greedy for comparisons; report Base and Base + Extra.**
- **Mind the 768-token cap** and thinking text on reasoning models.
- **Keys from the environment**, never inline.

## References

- [`references/install.md`](references/install.md): requirements, extras, status, Docker image.
- [`references/run-and-backends.md`](references/run-and-backends.md): codegen, sanitize, evaluate, backends, sample formats.
- [`references/execution-and-evalperf.md`](references/execution-and-evalperf.md): sandboxing, limits, EvalPerf.
- [`references/combos/quant-code-check.md`](references/combos/quant-code-check.md): quantization code check on vLLM.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrades and dataset versions.

## Companion skills

- `vllm`: server for `--backend openai`.
- `lm-evaluation-harness`: other benchmarks.
- `swe-bench`: repository-level coding evals.
- `llm-evals`: eval strategy and gates.

## License

MIT
