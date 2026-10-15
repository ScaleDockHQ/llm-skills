# GuideLLM Skill

An agent skill for load-testing LLM servers with [GuideLLM](https://github.com/vllm-project/guidellm) (`guidellm run`) against vLLM and any OpenAI-compatible endpoint. It covers install and pinning, traffic profiles (sweep, concurrent, constant, Poisson, throughput, knee, goodput, trace replay), data sources, SLO attainment and goodput, report formats, the 0.6 to 0.8 CLI migration and troubleshooting. Verified against GuideLLM 0.8.1 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill guidellm
```

## Rules

- **Pin the version** (venv or `vX.Y.Z` image tag); the CLI changed in 0.7 and 0.8.
- **Record the run:** profile, constraints, data lengths, backend, version.
- **Warm up and bound every strategy** (`max_duration`, `over_saturation`).
- **Same data, seed and profile** when comparing two configurations.
- **Keys never on the command line**; reports contain prompts, so keep them private.

## References

- [`references/install.md`](references/install.md): requirements, pip, container, status, settings.
- [`references/run-and-profiles.md`](references/run-and-profiles.md): CLI format, profiles, constraints, replay.
- [`references/data-and-backends.md`](references/data-and-backends.md): data kinds, tokenizer, backend options, key handling.
- [`references/metrics-and-slo.md`](references/metrics-and-slo.md): metrics, SLO attainment, goodput, outputs.
- [`references/combos/vllm-sweep-and-slo.md`](references/combos/vllm-sweep-and-slo.md): vLLM sweep, SLO search, comparison.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrades and CLI migration.

## Companion skills

- `vllm`: server under test.
- `nvidia-aiperf`: alternative benchmark tool.
- `self-hosted-llms`: shared `bench.sh` smoke benchmark.
- `lm-evaluation-harness`: answer quality.

## License

MIT
