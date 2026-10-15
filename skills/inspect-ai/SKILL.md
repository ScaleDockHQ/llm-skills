---
name: inspect-ai
description: Run Inspect AI (UK AISI) evals with the `inspect eval` CLI, Python Task/dataset/solver/scorer code, model_graded_qa judges, log files and Inspect View, against vLLM, Ollama, LiteLLM or cloud models. Use for inspect_evals benchmarks, agent evals, eval-set, eval-retry, --model-role grader, .eval logs. Not for strategy (llm-evals) or YAML golden-set tests (promptfoo).
license: MIT
compatibility: Python >=3.10 (pip or uv), curl and jq; macOS and Linux. Needs a model provider or an OpenAI-compatible endpoint. Installs, Docker sandboxes (model-run code), dataset downloads and paid judge or cloud calls need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Inspect AI

Run repeatable LLM and agent evals with Inspect: a `Task` (dataset + solver + scorer) run by `inspect eval`, with logs you can query and a viewer.

**Scope:** this one product: install, point at a model or endpoint, write a task, score (including model-graded), run sets, read logs, update, troubleshoot. Eval strategy (what to measure, gates, decision records) belongs to `llm-evals`. YAML golden-set prompt tests belong to `promptfoo`. Public benchmarks through EleutherAI's harness belong to `lm-evaluation-harness`.

Work through the steps in order. Load a reference only when a step names it. Verified against inspect-ai 0.3.278 (2026-10-11); the CLI itself was not executed on the writing machine (Python 3.9, needs 3.10+), so confirm flags with `inspect eval --help` on the installed version.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                              # inspect-ai needs >=3.10
command -v inspect uv pipx jq curl docker
inspect --version 2>/dev/null; pip show inspect-ai 2>/dev/null | sed -n 1,2p
ls *.py tasks/ logs/ .env 2>/dev/null | head -30
grep -l -E 'inspect_ai|from inspect' -r --include=*.py . 2>/dev/null | head
# Provider env: presence only
for v in OPENAI_API_KEY ANTHROPIC_API_KEY VLLM_BASE_URL OLLAMA_BASE_URL LITELLM_PROXY_BASE_URL INSPECT_LOG_DIR INSPECT_EVAL_MODEL; do
  [ -n "$(printenv $v)" ] && echo "$v set" || echo "$v unset"; done
# Reachable OpenAI-compatible server
curl -fsS "${LLM_BASE_URL:-http://localhost:8000/v1}/models" ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} | jq -r '.data[].id'
inspect log list --json 2>/dev/null | jq -r '.[0:5][] | [.name,.task,.status]|@tsv'
```

## Decision flow

1. No Python 3.10+: install it first, then a per-project venv (`references/install.md`). Pin the version.
2. Target model is on a self-hosted server (vLLM, llama.cpp, SGLang, Ollama) or a gateway: `references/endpoints.md` (`openai-api/<name>/<model>`, `vllm/...` with `VLLM_BASE_URL`, `ollama/...`, `litellm-proxy/...`).
3. Want a published benchmark: install `inspect-evals` and run `inspect eval inspect_evals/<task>` (`references/install.md`). Otherwise write a task (`references/tasks.md`).
4. Open-ended answers: model-graded scorer with a separate grader bound by `--model-role grader=...` (`references/scoring.md`). Without a bound role the model under test grades itself.
5. Many tasks or models, or flaky APIs: `inspect eval-set` with its own `--log-dir` (`references/running.md`).
6. Code-running agents or tools: a sandbox is mandatory and needs approval (`references/running.md`).
7. Run failed or scores look wrong: `references/troubleshooting.md`.

## Rules

- **Pin the version.** `pip install inspect-ai==X.Y.Z` in a venv per project; Inspect is pre-1.0 and changes often. Re-run the baseline after any bump.
- **Bind a grader that is not the model under test.** `model_graded_qa()` falls back to the evaluated model when no `grader` role is bound. Use `ModelRole("grader", required=True)` in tasks that must never self-grade.
- **Deterministic scorers first.** `match`, `includes`, `pattern`, `choice`, `exact`, `f1`, `math`; use model grading only where text matching cannot work.
- **Smoke first.** `--limit 5` and read the log before a full run; remove `--limit` only for the real run.
- **Same settings both sides.** Set `--temperature`, `--max-tokens`, `--seed`, `--epochs` explicitly when comparing models.
- **Credentials from the environment.** Keys live in env vars or a `0600` `.env` outside version control (`.env` is auto-loaded from the cwd and parents). Never put keys in `-M` model args (they are written to logs) and never print them.
- **Use the log API, not raw JSON.** `.eval` logs are binary; read them with `inspect log dump`, `read_eval_log()` or `inspect view`.
- **Sandboxes for model-run code.** Never run model-generated shell or Python on the host; ask first.
- **Ask before downloads and spend.** Dataset pulls, `--sandbox docker` builds and paid provider or judge calls need approval.

## Workflows

### 1. First eval against an endpoint

- [ ] Create a venv, `pip install inspect-ai==<pin> openai`. -> `references/install.md`
- [ ] Save the minimal task from `references/tasks.md` as `task.py` (JSONL dataset, `generate()`, `match()`), and start from `templates/dataset.example.jsonl`.
- [ ] Set the server env (for example `VLLM_BASE_URL`, `VLLM_API_KEY`) and run `inspect eval task.py --model vllm/<served-model-id> --limit 5 --log-dir logs/smoke`. -> `references/endpoints.md`
- [ ] Verify: log status `success`, five samples, outputs contain no leaked thinking text unless intended (`references/endpoints.md` reasoning section).

### 2. Own dataset and scorer

- [ ] One record per line with `input` and `target` (plus `id`, `metadata`); load with `json_dataset` or `csv_dataset`, map columns with `FieldSpec`. -> `references/tasks.md`
- [ ] Choose a scorer. -> `references/scoring.md`
- [ ] Verify: scores are not all-zero or all-one on a smoke run; read five sample transcripts in `inspect view`.

### 3. Compare models

- [ ] `inspect eval-set task.py --model a,b --log-dir logs/cmp-1 --epochs 3` with identical generation config. -> `references/running.md`
- [ ] Compare per-sample, not only aggregates (`templates/compare-logs.sh`). Verify: stderr noise bounds the difference.

### 4. Judge-graded task

- [ ] Task uses `model_graded_qa(model_role=ModelRole("grader", required=True))`; run with `--model-role grader=<judge>`. -> `references/scoring.md`
- [ ] Calibrate the judge on human labels before gating on it (strategy in `llm-evals`).

### 5. Recover and re-score

- [ ] Failed or cancelled run: `inspect eval-retry <log>`; sets: re-run the same `eval-set` command. -> `references/running.md`
- [ ] Changed a scorer: `inspect score <log>` re-scores without regenerating.

### 6. Update

- [ ] `references/updating.md`: read release notes, bump the pin, re-run the baseline.

## Reference index

- `references/install.md`: Python, pinning, extras, `inspect-evals`, `.env`, maintenance and ownership.
- `references/endpoints.md`: providers for local servers and gateways, env vars, reasoning models, logprobs.
- `references/tasks.md`: Task anatomy, datasets and `FieldSpec`, solvers, run-time overrides, run-config files.
- `references/scoring.md`: built-in scorers, model grading and roles, metrics, epochs, re-scoring.
- `references/running.md`: parallelism, limits, errors and retries, eval sets, caching, logs and viewer, sandboxes.
- `references/troubleshooting.md`: symptoms, causes, fixes.
- `references/updating.md`: upgrade procedure and what to re-check.
- `templates/dataset.example.jsonl`, `templates/compare-logs.sh`: starting files (the task code is in `references/tasks.md`; the repo ships no Python files).

## Companion skills

- `llm-evals`: eval strategy, gates, decision records. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `promptfoo`: YAML golden-set tests and CI gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill promptfoo`.
- `lm-evaluation-harness`: EleutherAI public benchmarks. Install: `npx skills add ScaleDockHQ/llm-skills --skill lm-evaluation-harness`.
- `vllm`: usual self-hosted target. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `litellm`: gateway the evals can go through. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `reasoning-models`: thinking-token handling. Install: `npx skills add ScaleDockHQ/llm-skills --skill reasoning-models`.
