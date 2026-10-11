# EvalPlus: safe execution, limits and EvalPerf

> Verified against EvalPlus 0.3.1 (docs `execution.md`, `cli.md`, `evalperf.md`, README), 2026-10-11

## Sandbox

Model-written code runs with the evaluator's privileges. Upstream strongly recommends a sandbox. Use Docker for the evaluate step and keep generation on the host:

```bash
docker run --rm -v "$(pwd)/evalplus_results:/app" ganler/evalplus:latest \
  evalplus.evaluate --dataset humaneval \
  --samples /app/humaneval/<model>_openai_temp_0.0.jsonl
```

Hardening you control (beyond upstream's example): no network (`--network none`), read-only root (`--read-only` plus a tmpfs), no mounted secrets or home directory, limited CPUs and memory (`--cpus`, `--memory`). These are standard Docker options, not EvalPlus features; check the run still passes. Prefer a throwaway VM for large or untrusted sample sets.

## Timeouts, memory, parallelism

- Time limit per task: `max(T_base, T_gt * k)` where `T_base` is `--min-time-limit` (default 4 s), `T_gt` the ground-truth runtime, and `k` is `--gt-time-limit-factor` (default 4). On slow or busy machines raise both to avoid false failures.
- Memory: default limit per process `min(4 GB, system maximum)`; `EVALPLUS_MAX_MEMORY_BYTES=-1` removes it, otherwise a byte count.
- Timeouts and out-of-memory count as failures.
- Do not oversubscribe: `--parallel 64` on 4 cores distorts timing and produces spurious timeouts. Use `--parallel $(nproc)` at most, and avoid other load during evaluation.
- Speed: skip `--test-details` (it runs all ~700+ tests per task instead of stopping at the first failure); `--mini` uses a smaller high-quality HumanEval+ test subset (upstream says 23%+ faster) but is a different benchmark variant: do not mix with full numbers.

## Reading pass@k

"Base" uses the original tests; "Base + Extra" uses EvalPlus's extra tests. Greedy decoding gives one sample per task and pass@1 = fraction of tasks solved. HumanEval+ has 164 tasks (one task is 0.61 percentage points); MBPP+ v0.2.0 has 378. For pass@10 and pass@100 sample with `--n-samples` and a positive `--temperature`.

## EvalPerf (efficiency)

Linux only. Needs the `perf` extra and kernel `perf` events:

```bash
cat /proc/sys/kernel/perf_event_paranoid          # read-only check
# Upstream: sudo sh -c 'echo 0 > /proc/sys/kernel/perf_event_paranoid'   # changes the host: ask first
evalplus.evalperf --model "<model>" --backend vllm
```

Docker needs `--cap-add PERFMON`. Steps: sample 100 solutions per task (`n_samples`), efficiency-evaluate tasks with at least 10 passing samples (`min_correct`), write `<model>_evalperf_v<VERSION>.jsonl` with per-task `results`, `dps`, `dps_norm`, `pass@1`, `n_profiled`, then compute the differential performance score (DPS), which reads like "outperforms X% of reference LLM solutions". Dataset `20240328` has 118 tasks. For the codegen side, `evalplus.codegen --dataset evalperf --temperature 1.0 --n-samples 100` followed by `evalplus.evalperf --samples <file>` in Docker. Efficiency numbers depend on CPU: report the hardware, and do not compare across machines.
