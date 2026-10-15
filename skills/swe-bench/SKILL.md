---
name: swe-bench
description: Grade coding-agent patches on SWE-bench (Verified, Lite, Multilingual, Multimodal, full) with the swebench CLI v5 (swebench eval, report, images, dataset), Docker-isolated per-instance test runs, predictions JSONL, run_id caching, gold-patch validation, Modal. Use for resolve-rate of a local or hosted model plus an agent scaffold such as mini-SWE-agent, harness setup, disk and worker sizing, results.json reading, stale results. Not for single-function codegen (evalplus) or generic benchmarks (lm-evaluation-harness).
license: MIT
compatibility: Python >=3.10 and Docker on x86_64 Linux (arm64 and macOS Docker Desktop are experimental), about 120GB free disk, 16GB RAM and 8 cores recommended, curl and jq. Evaluation executes repository test suites in containers. Installs, Docker builds or pulls, Modal use and any model-driven agent run need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# SWE-bench

Measure how often a model plus an agent scaffold resolves real GitHub issues: the harness applies each predicted patch inside a per-instance Docker container, runs the repository's tests and reports resolved instances. SWE-bench grades patches. It does not generate them.

**Scope:** this one product: install, validate with gold patches, produce or import predictions, evaluate, read results, update, troubleshoot. Single-function code benchmarks belong to `evalplus`; broad benchmark suites to `lm-evaluation-harness`; eval strategy and gates to `llm-evals`.

Work through the steps in order. Load a reference only when a step names it. Verified against PyPI `swebench` 5.0.2 (wheel contents) and upstream docs on `main` (2026-10-11). Upstream `main` is ahead of the PyPI release (see `references/install.md`): confirm every command with `swebench <command> --help` on the installed version.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                              # >=3.10 for swebench 5.x
command -v swebench docker
pip show swebench 2>/dev/null | head -3
swebench --help 2>/dev/null | head -30         # which subcommands this version has
docker info --format 'cpus={{.NCPU}} mem={{.MemTotal}} arch={{.Architecture}}' 2>/dev/null
docker system df 2>/dev/null
df -h . | tail -1                              # about 120GB free needed
ls logs/evaluation/ 2>/dev/null                # earlier run ids (cached by run_id)
```

## Decision flow

1. Not installed or too old: `references/install.md`.
2. First time on this machine: validate the harness with gold patches before any model run (`references/eval-and-datasets.md`).
3. Have predictions JSONL: `swebench eval` (`references/eval-and-datasets.md`).
4. No predictions yet: an agent scaffold must produce them, for example mini-SWE-agent against a local OpenAI-compatible server (`references/predictions-and-inference.md`, `references/combos/local-model-mini-swe-agent.md`).
5. Disk, CPU or Docker pressure: lower `-j`, trim caches (`references/eval-and-datasets.md`).
6. Zero resolved, identical numbers after a change, errors, ARM host: `references/troubleshooting.md`.
7. Upgrading or changing dataset version: `references/updating.md`.

## Rules

- **Pin the version** and record it with every score: `pip install "swebench==5.0.2"`. Datasets, images and graders change across releases, so numbers compare only within one version.
- **Gold first.** Run `--gold` on one instance (for example `sympy__sympy-20590`) before spending model time. If gold fails, the host or images are broken, not the model.
- **A new `run_id` for every new set of patches.** Results are cached by `run_id` plus `instance_id` only. Reusing a `run_id` with different patches silently returns the old verdicts.
- **Size workers conservatively.** Stay below `min(0.75 * cpu_count, 24)` workers. More workers than the Docker VM has cores slows the run and causes timeouts.
- **Containers execute untrusted code.** Run on a dedicated or disposable host, not a machine with secrets or mounted credentials. Agent scaffolds that run model commands need the same isolation.
- **Ask before long or costly steps.** Image pulls and builds are tens of GB, a full run takes hours, and agent runs spend provider budget.
- **Keys from the environment.** Provider keys come from a `0600` file or environment variables, never inline or in committed configs.
- **Report the dataset and count.** "Verified, 500 instances, 61 resolved" beats a bare percentage; check `Instances submitted` equals the dataset size before comparing.

## Workflows

### 1. Validate the harness

- [ ] Install a pinned version. -> `references/install.md`
- [ ] `swebench eval verified --gold -i sympy__sympy-20590 -j 1 --run-id validate-gold`. -> `references/eval-and-datasets.md`
- [ ] Verify: `logs/evaluation/validate-gold/results.json` shows 1 resolved.

### 2. Score a model's predictions

- [ ] Predictions are JSONL with `instance_id`, `model_name_or_path`, `model_patch`. -> `references/predictions-and-inference.md`
- [ ] `swebench eval verified -p preds.jsonl -j 8 --run-id <new-unique-id>`
- [ ] Verify: submitted equals total; read errors and empty patches separately from unresolved.

### 3. Generate predictions with a local model

- [ ] Serve the model on an OpenAI-compatible endpoint (`vllm` skill), then run an agent scaffold. -> `references/combos/local-model-mini-swe-agent.md`
- [ ] Verify: `preds.json` has one patch per instance before evaluating.

## Reference index

- `references/install.md`: requirements, pinned install, PyPI vs `main`, Docker sizing.
- `references/eval-and-datasets.md`: datasets, `eval`, `report`, `images`, results layout, cloud options.
- `references/predictions-and-inference.md`: prediction format, agent scaffolds, `swebench infer`, legacy inference.
- `references/combos/local-model-mini-swe-agent.md`: local vLLM model, mini-SWE-agent, SWE-bench grading.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: upgrades, version drift, dataset changes.

## Companion skills

- `vllm`: serves the model that the agent calls. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `evalplus`: function-level code benchmarks. Install: `npx skills add ScaleDockHQ/llm-skills --skill evalplus`.
- `lm-evaluation-harness`: other public benchmarks. Install: `npx skills add ScaleDockHQ/llm-skills --skill lm-evaluation-harness`.
- `llm-evals`: eval strategy, gates, decision records. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
