---
name: promptfoo
description: Run promptfoo (npx promptfoo eval, promptfooconfig.yaml) to test prompts and compare models on a golden set against any OpenAI-compatible endpoint (vLLM, llama.cpp, Ollama, LiteLLM, cloud). Use for assertions, llm-rubric judges, apiBaseUrl/apiKeyEnvar, exit code 100, PROMPTFOO_PASS_RATE_THRESHOLD, GitHub Actions gates, quant-change A/B. Not for public benchmarks (lm-evaluation-harness).
license: MIT
compatibility: Node.js >=22.22.0 (npx), curl and jq; macOS and Linux. Needs a reachable OpenAI-compatible /v1 endpoint. Installs, CI changes and anything that sends eval data to a hosted service (share links, cloud judges) need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# promptfoo

Run repeatable task evals with promptfoo: a YAML config, a golden set, deterministic assertions first, and a pass/fail exit code a CI job can trust.

**Scope:** this one product: install, configure, point at OpenAI-compatible endpoints, assert, judge, run in CI, update, troubleshoot. Eval strategy (what to measure, golden-set design, gate thresholds) belongs to `llm-evals`. Public benchmarks (MMLU, GSM8K) belong to `lm-evaluation-harness`.

Work through the steps in order. Load a reference only when a step names it. Everything here was verified against promptfoo 0.124.1 (2026-10-11). Confirm flags on the installed version with `npx promptfoo@<version> eval --help`.

## Discover first

Read-only; nothing here prints secrets.

```bash
# Tooling
node --version                      # promptfoo 0.124.1 needs >=22.22.0
command -v npx jq curl promptfoo
npx --no-install promptfoo --version 2>/dev/null

# Existing eval assets and CI wiring
ls promptfooconfig.* evals/ .promptfoo/ 2>/dev/null
find . -maxdepth 3 \( -name 'promptfooconfig*.y*ml' -o -name '*.jsonl' \) -not -path './node_modules/*' 2>/dev/null | head -20
grep -l -i promptfoo .github/workflows/* package.json 2>/dev/null

# Endpoint (key presence only, never the value)
echo "${LLM_BASE_URL:-unset}"; [ -n "${LLM_API_KEY:-}" ] && echo "LLM_API_KEY set" || echo "LLM_API_KEY not set"
curl -fsS -H "Authorization: Bearer ${LLM_API_KEY:-none}" "${LLM_BASE_URL:-http://localhost:8000/v1}/models" | jq -r '.data[].id'
```

## Decision flow

1. No Node 22.22+: install it first (`references/install.md`); do not install promptfoo globally, pin it with `npx promptfoo@<version>` or a dev dependency.
2. No config yet: copy `templates/promptfooconfig.yaml`; set the model IDs reported by `/v1/models` (`references/config.md`).
3. Target is vLLM, llama.cpp, Ollama, LiteLLM or llama-swap: use `openai:chat:<model>` with `apiBaseUrl` set to the `/v1` root (`references/providers.md`). The native `llama` provider is a different path and not needed for chat.
4. Reasoning model (thinking text in output): set `showThinking: false` and, on vLLM, `passthrough.chat_template_kwargs` (`references/providers.md`).
5. Needs a judge (`llm-rubric`): configure a separate grader provider (`references/assertions.md`).
6. Decision depends on a numerics change (quantization, KV dtype, engine): `references/combos/quant-ci-gate.md`.
7. Results look wrong or the run fails: `references/troubleshooting.md`.

## Rules

- **Pin the version.** `npx promptfoo@0.124.1`, never `@latest`, for any run that feeds a decision or CI. Upgrade deliberately and re-run the baseline.
- **`apiBaseUrl` ends at `/v1`.** promptfoo appends `/chat/completions` itself.
- **Keys by name, never inline.** Use `apiKeyEnvar: NAME`; an unset variable fails and does not fall back to `OPENAI_API_KEY`. Use `apiKeyRequired: false` for open servers.
- **`--no-cache` on decision runs.** Responses are cached on disk by default and a "candidate" can silently reuse old outputs.
- **Same sampling both sides.** Set `temperature`, `top_p`, `max_tokens`, `seed` explicitly on every provider.
- **Deterministic assertions first.** `equals`, `contains`, `regex`, `is-json`, `finish-reason`; model-graded only where nothing deterministic fits, with a pinned grader that is not the model under test.
- **`--no-share` for private data.** Share links upload prompts, outputs and provider config to a hosted viewer.
- **Never print or commit secrets.** Read keys from `0600` files or environment variables; do not put them in `config.env` or inline `apiKey`.

## Workflows

### 1. First eval against an endpoint

- [ ] Confirm the model ID via `/v1/models`.
- [ ] Copy `templates/promptfooconfig.yaml` (two providers) or write the minimal config in `references/config.md`.
- [ ] `export LLM_BASE_URL=...` and `LLM_API_KEY` from a secrets file, then `npx promptfoo@0.124.1 validate -c promptfooconfig.yaml`.
- [ ] `npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --filter-first-n 3`, then read the three outputs. -> `references/cli.md`
- [ ] Verify: three rows, no `ERROR` cells, outputs contain no `<think>` text.

### 2. Golden set and assertions

- [ ] Start from `templates/golden-set.example.jsonl`; one test per line with `vars`, `assert`, `metadata`.
- [ ] Reference it with `tests: file://golden-set.jsonl`. -> `references/config.md`
- [ ] Add `defaultTest.assert` for format checks (`not-icontains: "<think>"`, `finish-reason: stop`). -> `references/assertions.md`
- [ ] Verify: `--repeat 3` on a subset shows stable pass/fail per item.

### 3. Compare two models or endpoints

- [ ] Two providers with labels `baseline` and `candidate`, identical sampling.
- [ ] Run with `--no-cache -o results.json -o report.html`; for per-item diffs run each label separately to JSONL and diff with `jq`. -> `references/cli.md`
- [ ] Verify: report regressions (pass to fail) and fixes by item, not only the aggregate rate.

### 4. LLM-as-judge

- [ ] Set the grader once under `defaultTest.options.provider`, temperature 0, `showThinking: false`. -> `references/assertions.md`
- [ ] Calibrate on human labels before using it in a gate (strategy in `llm-evals`).

### 5. CI gate

- [ ] PR tier: deterministic `critical=yes` subset; full tier on schedule. Fail on exit code 100 or `PROMPTFOO_PASS_RATE_THRESHOLD`. -> `references/ci.md`
- [ ] Quant change: `references/combos/quant-ci-gate.md`.
- [ ] Verify: a deliberately broken assertion makes the job fail.

### 6. Update

- [ ] Re-run the baseline on the new version before trusting deltas. -> `references/updating.md`

## Reference index

- `references/install.md`: Node requirement, pinning, telemetry, project layout, ownership and maintenance status.
- `references/config.md`: config structure, minimal config, tests (JSONL, CSV, YAML), `defaultTest`, vars and env templating.
- `references/providers.md`: OpenAI-compatible targets (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap), auth, reasoning models, `passthrough`.
- `references/assertions.md`: deterministic and model-graded assertions, grader setup, thresholds, weights.
- `references/cli.md`: `eval` flags, filters, outputs, exit codes, env vars, cache, per-item comparison.
- `references/ci.md`: GitHub Actions workflow, promptfoo-action, tiers, secrets, private endpoints.
- `references/troubleshooting.md`: symptoms, causes, fixes.
- `references/updating.md`: upgrade procedure and what to re-check.
- `references/combos/quant-ci-gate.md`: A/B gate for a quantization (or other numerics) change.
- `templates/promptfooconfig.yaml`, `templates/golden-set.example.jsonl`, `templates/llm-evals.yml`: starting files.

## Companion skills

- `llm-evals`: eval strategy, gates and decision records. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `lm-evaluation-harness`: public benchmarks against the same endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill lm-evaluation-harness`.
- `litellm`: gateway endpoint and keys that evals run through. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `vllm`: the usual self-hosted target. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `llama-cpp`: local GGUF target. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `reasoning-models`: thinking-token handling. Install: `npx skills add ScaleDockHQ/llms-skills --skill reasoning-models`.
