# NVIDIA AIPerf Skill

An agent skill for benchmarking LLM serving with [NVIDIA AIPerf](https://github.com/ai-dynamo/aiperf) (`aiperf profile`) against any OpenAI-compatible endpoint: vLLM, SGLang, TensorRT-LLM, Dynamo, NIM and cloud APIs. It covers install, workload design (synthetic, ShareGPT, custom, traces), concurrency and request-rate sweeps, goodput SLOs, multi-run confidence intervals, GPU telemetry, GenAI-Perf migration and troubleshooting. Verified against AIPerf 0.13.0 (2026-10-11).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill nvidia-aiperf
```

## Rules

- **Pin the version** in a venv; re-run baselines after upgrades.
- **`--url` is the origin**, and `--streaming` is required for TTFT and ITL.
- **State ISL, OSL, seed, warmup and request count** with every number.
- **Same seed and workload** for comparisons; use `--num-profile-runs` and report intervals.
- **Never paste keys** into commands; read them from `0600` files or the environment.

## References

- [`references/install.md`](references/install.md): requirements, install, status, network use.
- [`references/profile-cli.md`](references/profile-cli.md): `aiperf profile` flags, YAML, outputs.
- [`references/workloads-and-metrics.md`](references/workloads-and-metrics.md): datasets, traces, metric definitions, reasoning models.
- [`references/sweeps-and-confidence.md`](references/sweeps-and-confidence.md): sweeps, goodput, multi-run statistics.
- [`references/combos/vllm-concurrency-sweep.md`](references/combos/vllm-concurrency-sweep.md): vLLM server, cache reset, sweep.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): upgrades and GenAI-Perf migration.

## Companion skills

- `vllm`, `sglang`: servers under test.
- `dcgm-exporter`: GPU telemetry source.
- `nvidia-dynamo`: Dynamo serving.
- `self-hosted-llms`: shared `bench.sh` smoke benchmark.
- `lm-evaluation-harness`: answer quality.

## License

MIT
