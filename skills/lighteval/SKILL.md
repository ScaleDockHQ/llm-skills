---
name: lighteval
description: Run Hugging Face Lighteval benchmarks with the lighteval CLI (lighteval eval, vllm, endpoint litellm, accelerate) on MMLU, GSM8K, GPQA, IFEval and 1000+ tasks, against vLLM, LiteLLM or OpenAI-compatible endpoints. Use for lighteval tasks list, --save-details, results JSON, custom tasks, reasoning tags. Not for strategy (llm-evals), lm-evaluation-harness or promptfoo.
license: MIT
compatibility: Python >=3.10 (pip), PyTorch 2.x, curl and jq; macOS and Linux (Windows untested upstream). GPU only for local vllm or accelerate backends. Installs, dataset or model downloads, Hugging Face Hub pushes and paid API calls need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Lighteval

Run public LLM benchmarks with Hugging Face's Lighteval: pick tasks, pick a backend, get results and per-sample details you can compare.

**Scope:** this one product: install, choose a backend, run tasks, read results, add a custom task, update, troubleshoot. Eval strategy (which benchmarks matter, gates, decisions) belongs to `llm-evals`. EleutherAI's harness is `lm-evaluation-harness`; your own golden set is `promptfoo`; Inspect itself is `inspect-ai`.

Work through the steps in order. Load a reference only when a step names it. Verified against lighteval 0.13.0 (PyPI 2025-11-24) and the `main` branch source (0.13.1.dev0) on 2026-10-11; the CLI was not executed on the writing machine (Python 3.9, lighteval needs 3.10+), so confirm flags with `lighteval <command> --help`.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                               # needs >=3.10
command -v lighteval jq curl nvidia-smi
lighteval --help 2>/dev/null | sed -n 1,40p     # which backends this install has
pip show lighteval 2>/dev/null | sed -n 1,2p; pip list 2>/dev/null | grep -i -E '^(inspect-ai|vllm|litellm|torch|transformers) '
lighteval tasks list 2>/dev/null | grep -i -E 'gsm8k|mmlu|ifeval|gpqa' | head
ls results/ lighteval-logs-*/ 2>/dev/null | head
for v in HF_TOKEN OPENAI_API_KEY; do [ -n "$(printenv $v)" ] && echo "$v set" || echo "$v unset"; done
curl -fsS "${LLM_BASE_URL:-http://localhost:8000/v1}/models" ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} | jq -r '.data[].id'
```

## Decision flow

1. Python < 3.10 or no venv: create one first (`references/install.md`); pin `lighteval==X.Y.Z`.
2. Model is behind an OpenAI-compatible server (vLLM, llama.cpp, LiteLLM gateway, cloud) and the tasks have an Inspect definition: `lighteval eval` with an Inspect model string, upstream's preferred path (`references/backends.md`).
3. Task is not supported by `lighteval eval` ("not supported by inspect_ai yet"): use `lighteval endpoint litellm` for a served model, or `lighteval vllm` / `accelerate` for a local model (`references/backends.md`).
4. Local GPU, no server: `lighteval vllm "model_name=<hf-repo>,..."` or `accelerate` (`references/backends.md`).
5. Reasoning model: strip thinking tags and check the extracted answers (`references/tasks-and-results.md`).
6. Own data or metric: custom task file (`references/tasks-and-results.md`).
7. Something failed or scores look off: `references/troubleshooting.md`.

## Rules

- **Pin the version** (`pip install "lighteval==0.13.0"`); the backends and task formats changed between releases. Re-run the baseline after any bump.
- **Smoke first.** `--max-samples 5` on one task, read the output, then the full run.
- **Same settings both sides.** Same version, tasks, few-shot count, backend, temperature, seed, max tokens when comparing models or quants.
- **`lighteval eval` caches model calls by default** (its solver uses `generate(cache=True)`), has `--timeout 30` seconds per call by default, and retries once. Raise the timeout for slow models and clear the Inspect cache (`inspect cache clear`) for decision runs.
- **Tokens from the environment.** `HF_TOKEN`, provider keys: env vars or `0600` files; never inline in `model_args` or YAML files you commit, and never print them.
- **Ask before downloads and pushes.** Datasets, model weights, `--push-to-hub`, `--repo-id` uploads and paid API runs need approval; results pushed to the Hub are private unless `--public-run`/`--public` is set.
- **Benchmarks are a prior, not a decision.** Your own tasks decide (`llm-evals`, `promptfoo`).

## Workflows

### 1. First run against a served model

- [ ] Create a venv and install pinned `lighteval` (and `vllm` or `litellm` extras only if the chosen backend needs them). -> `references/install.md`
- [ ] Find the served id: `curl $BASE/models | jq`. Export keys by env var.
- [ ] `lighteval eval openai-api/<name>/<served-id> gsm8k --model-base-url "$LLM_BASE_URL" --max-samples 5 --timeout 300 --log-dir logs/smoke` (provider env `<NAME>_API_KEY`). -> `references/backends.md`
- [ ] Verify: results table printed, log dir has logs with `success`, answers are not truncated or full of thinking text.

### 2. Local model with vLLM or Accelerate

- [ ] `lighteval vllm "model_name=<repo>,gpu_memory_utilization=0.8" ifeval --max-samples 5 --output-dir results --save-details`. -> `references/backends.md`
- [ ] Verify: `results/results/<model>/results_*.json` exists and details parquet files are present.

### 3. Compare two models or quants

- [ ] Same command twice, only the model changes; keep `--output-dir` and `--save-details`. -> `references/tasks-and-results.md`
- [ ] `templates/compare-results.sh a.json b.json` for metric deltas with stderr. Verify per-task, not only means.

### 4. Reasoning models

- [ ] Keep `--remove-reasoning-tags` (default on), set `--reasoning-tags` for non-`<think>` tags, give enough `max_new_tokens`. -> `references/tasks-and-results.md`

### 5. Custom task

- [ ] Write a `TASKS_TABLE` file; run with `--custom-tasks`. -> `references/tasks-and-results.md`

### 6. Update

- [ ] `references/updating.md`: read release notes, bump pin, re-run the baseline.

## Reference index

- `references/install.md`: Python, extras, version pins, tokens, maintenance and ownership.
- `references/backends.md`: `eval` (Inspect), `vllm`, `endpoint litellm`, `accelerate`, `sglang`, `tgi`, model-args and YAML configs.
- `references/tasks-and-results.md`: task strings, listing, few-shot, reasoning tags, outputs, details, custom tasks.
- `references/troubleshooting.md`: symptoms, causes, fixes.
- `references/updating.md`: upgrade procedure.
- `templates/compare-results.sh`, `templates/litellm-endpoint.yaml`, `templates/vllm-model.yaml`: starting files.

## Companion skills

- `llm-evals`: eval strategy and gates. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `inspect-ai`: the framework behind `lighteval eval`. Install: `npx skills add ScaleDockHQ/llms-skills --skill inspect-ai`.
- `lm-evaluation-harness`: EleutherAI benchmarks. Install: `npx skills add ScaleDockHQ/llms-skills --skill lm-evaluation-harness`.
- `promptfoo`: own golden-set tests. Install: `npx skills add ScaleDockHQ/llms-skills --skill promptfoo`.
- `vllm`: serve the model under test. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `litellm`: gateway to endpoints. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
