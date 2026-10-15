# Promptfoo Skill

An agent skill for running [promptfoo](https://github.com/promptfoo/promptfoo) task evals against any OpenAI-compatible endpoint: vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, and cloud APIs. It covers install and version pinning, config and golden-set JSONL, provider and auth settings (`apiBaseUrl`, `apiKeyEnvar`), reasoning-model handling, deterministic and model-graded assertions, CLI flags and exit codes, GitHub Actions gates, and an A/B gate for quantization changes. Verified against promptfoo 0.124.1 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill promptfoo
```

## Rules

- **Pin the version.** `npx promptfoo@0.124.1`, never `@latest`, for decision runs and CI.
- **`apiBaseUrl` ends at `/v1`.** promptfoo appends the endpoint path.
- **Keys by name.** `apiKeyEnvar`, never inline secrets; an unset variable fails instead of falling back.
- **`--no-cache` on decision runs.** Otherwise a candidate can replay old outputs.
- **Same sampling both sides.** Set `temperature`, `top_p`, `max_tokens` and `seed` explicitly.
- **Deterministic assertions first.** Model-graded checks only with a pinned, separately configured grader.
- **`--no-share` for private data.**

## References

- [`references/install.md`](references/install.md): Node requirement, pinning, telemetry, state paths, ownership (promptfoo is part of OpenAI, still MIT).
- [`references/config.md`](references/config.md): config structure, tests (JSONL, CSV, YAML), `defaultTest`, env templating.
- [`references/providers.md`](references/providers.md): OpenAI-compatible targets, auth, reasoning models, `passthrough`.
- [`references/assertions.md`](references/assertions.md): deterministic and model-graded assertions, grader setup.
- [`references/cli.md`](references/cli.md): `eval` flags, filters, outputs, exit codes, environment variables.
- [`references/ci.md`](references/ci.md): GitHub Actions, promptfoo-action, tiers, private endpoints.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms, causes and fixes.
- [`references/updating.md`](references/updating.md): upgrade procedure.
- [`references/combos/quant-ci-gate.md`](references/combos/quant-ci-gate.md): baseline vs quantized candidate gate.

**Templates:**

- [`templates/promptfooconfig.yaml`](templates/promptfooconfig.yaml): baseline vs candidate on two endpoints.
- [`templates/golden-set.example.jsonl`](templates/golden-set.example.jsonl): promptfoo JSONL tests with metadata.
- [`templates/llm-evals.yml`](templates/llm-evals.yml): GitHub Actions workflow with PR and nightly tiers.
- [`templates/ab-diff.sh`](templates/ab-diff.sh): per-item diff of two JSONL result files (bash and jq).

## Companion skills

- `llm-evals`: eval strategy, quality gates, decision records.
- `lm-evaluation-harness`: public benchmarks against the same endpoint.
- `litellm`, `vllm`, `llama-cpp`: endpoints under test.
- `reasoning-models`: thinking-token handling.

## Upstream credits

- [promptfoo](https://github.com/promptfoo/promptfoo) and its [docs](https://www.promptfoo.dev/docs/).

## License

MIT
