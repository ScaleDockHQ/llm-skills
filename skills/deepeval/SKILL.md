---
name: deepeval
description: Run DeepEval (`deepeval test run`, pytest-based LLM unit tests) with GEval, answer relevancy, faithfulness and other metrics, using a local or OpenAI-compatible judge (vLLM, Ollama, LiteLLM) instead of the OpenAI default. Use for set-local-model, telemetry opt-out, Confident AI login, CI gates, invalid JSON judge errors. Not for strategy (llm-evals), ragas, promptfoo.
license: MIT
compatibility: Python >=3.9,<4 (pip), curl and jq; macOS and Linux. Needs a judge model (a local OpenAI-compatible server or a hosted API). Installs, hosted judge calls, `deepeval login` (uploads results to Confident AI) and any telemetry change need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# DeepEval

Write LLM evals as pytest tests with DeepEval metrics, run them with `deepeval test run`, and gate CI on the exit code, using a judge model you control.

**Scope:** this one product: install, judge configuration (local or hosted), test cases and metrics, datasets, test runs, CI, telemetry and Confident AI, update, troubleshoot. Eval strategy (what to measure, golden-set design, gate thresholds) belongs to `llm-evals`. RAG-specific metric suites from the Ragas project belong to `ragas`; YAML golden-set tests belong to `promptfoo`; public benchmarks belong to `lm-evaluation-harness` or `lighteval`.

Work through the steps in order. Load a reference only when a step names it. Verified against deepeval 4.2.8 (PyPI) and the docs source on 2026-10-11; the CLI itself was not executed on the writing machine (Python 3.9, so only part of the dependency set resolves), so confirm flags with `deepeval --help`.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version
command -v deepeval pytest jq curl
pip show deepeval 2>/dev/null | sed -n 1,2p
ls test_*.py tests/ .env .env.local .deepeval/ 2>/dev/null | head -20
deepeval settings -l 2>/dev/null | sed -n 1,40p        # effective settings; secrets are masked
deepeval diagnose 2>/dev/null | sed -n 1,40p           # default models and where each value comes from
# Telemetry and cloud state (names only)
for v in DEEPEVAL_TELEMETRY_OPT_OUT CONFIDENT_API_KEY USE_LOCAL_MODEL LOCAL_MODEL_BASE_URL OPENAI_API_KEY; do
  [ -n "$(printenv $v)" ] && echo "$v set" || echo "$v unset"; done
curl -fsS "${LLM_BASE_URL:-http://localhost:8000/v1}/models" ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} | jq -r '.data[].id'
```

## Decision flow

1. First, decide the judge: with no judge configured, LLM-as-a-judge metrics fall back to OpenAI, sending test inputs and outputs to a hosted API. Choose and set one deliberately (`references/judges.md`).
2. Private data or no API key: local or self-hosted judge through `deepeval set-local-model` (OpenAI-compatible server), `set-ollama`, or a `DeepEvalBaseLLM` subclass (`references/judges.md`).
3. Judge errors with "invalid JSON": the judge is too weak or lacks structured output; see `references/judges.md` and `references/troubleshooting.md`.
4. No telemetry wanted: `export DEEPEVAL_TELEMETRY_OPT_OUT=1` (`references/install.md`). Do not run `deepeval login` unless the user approves uploading results.
5. Writing tests: `references/tests-and-metrics.md`. Running and gating CI: `references/running-and-ci.md`.
6. Something failed or scores look off: `references/troubleshooting.md`.

## Rules

- **Pin the version.** `pip install "deepeval==4.2.8"` in a venv per project; the API moves quickly (for example `SingleTurnParams` in the current docs). Re-run the baseline after a bump.
- **Choose the judge explicitly.** Never rely on the OpenAI fallback for private data. A judge is a measuring instrument: pin its model id, temperature 0, and use a stronger model than the one being tested.
- **Deterministic metrics first.** `ExactMatchMetric` and `PatternMatchMetric` score without a judge, and `JsonCorrectnessMetric` validates against a Pydantic schema (its failure reason may call a judge; `include_reason=False` avoids that). Use LLM-judged metrics only where those cannot work.
- **Telemetry is on by default** (anonymous PostHog events with the public IP). Set `DEEPEVAL_TELEMETRY_OPT_OUT=1` where policy requires; it is the user's decision.
- **Confident AI is a cloud service.** `deepeval login` and `--official` runs upload test results there. Ask first; leave unauthenticated for local-only work.
- **Secrets from the environment or `0600` dotenv files.** `--save=dotenv` writes keys to `.env.local`; keep it out of git. Never print or inline keys.
- **Smoke before suite.** One test case through `deepeval test run -x`, then the dataset.
- **Metrics have thresholds, not truth.** A score is judge opinion; calibrate on human labels before gating (strategy in `llm-evals`).

## Workflows

### 1. First test run with a local judge

- [ ] Venv, `pip install "deepeval==4.2.8"`, `export DEEPEVAL_TELEMETRY_OPT_OUT=1` if required. -> `references/install.md`
- [ ] `deepeval set-local-model --model=<served-id> --base-url="$LLM_BASE_URL"` (key via prompt or env). -> `references/judges.md`
- [ ] Copy `templates/test_example.py.txt` to `test_example.py`; run `deepeval test run test_example.py -x`. -> `references/tests-and-metrics.md`
- [ ] Verify: a pass or fail with a metric reason, no OpenAI traffic, no JSON error.

### 2. Dataset-driven suite

- [ ] Goldens from CSV, JSON or in code; parametrize with pytest; call your app inside the test. -> `references/tests-and-metrics.md`
- [ ] Verify: each failing case shows its metric reason; `--repeat` on a subset is stable.

### 3. CI gate

- [ ] PR tier: small deterministic subset; full tier on schedule. `deepeval test run` exits non-zero when a test fails. -> `references/running-and-ci.md`
- [ ] Verify: a deliberately failing case breaks the job.

### 4. RAG metrics

- [ ] Supply `retrieval_context` (and `expected_output` where needed) on the test case. -> `references/tests-and-metrics.md`

### 5. Update

- [ ] `references/updating.md`: read release notes, bump the pin, re-run the baseline.

## Reference index

- `references/install.md`: Python, pinning, extras, telemetry, Confident AI, local state, maintenance.
- `references/judges.md`: judge setup (local, Ollama, LiteLLM, hosted, custom class), JSON reliability, thinking.
- `references/tests-and-metrics.md`: test cases, metrics, thresholds, datasets, pytest and `evaluate()`.
- `references/running-and-ci.md`: `deepeval test run` flags, caching, concurrency, results storage, CI.
- `references/troubleshooting.md`: symptoms, causes, fixes.
- `references/updating.md`: upgrade procedure.
- `templates/test_example.py.txt`, `templates/env.example`, `templates/deepeval-ci.yml`: starting files.

## Companion skills

- `llm-evals`: eval strategy, gates, decision records. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `ragas`: RAG evaluation with Ragas. Install: `npx skills add ScaleDockHQ/llm-skills --skill ragas`.
- `promptfoo`: YAML golden-set tests. Install: `npx skills add ScaleDockHQ/llm-skills --skill promptfoo`.
- `vllm`: usual local judge server. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `litellm`: gateway for the judge. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `ollama`: simple local judge. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
