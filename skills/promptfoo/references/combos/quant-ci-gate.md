# promptfoo CI gate on a quantization change

> Verified against promptfoo 0.124.1 (docs: command-line, ci-cd, openai provider) and the GitHub Actions release tags, 2026-10-11

Server flags are not covered here: the quantized endpoint is whatever your serving skill produced.

Goal: before a quantized model (or any other numerics change such as KV-cache dtype or an engine upgrade) reaches users, run the same golden set against the current production endpoint and the candidate endpoint, and block the change on a pre-agreed rule. This file is the promptfoo mechanics. What to measure, thresholds and the decision record live in the `llm-evals` skill (`npx skills add ScaleDockHQ/llm-skills --skill llm-evals`, reference `quality-gates.md`).

## Setup

1. **Two endpoints, one change.** Baseline = production as deployed (same model, quant, engine version, flags, chat template). Candidate = exactly one difference. Serving details: `vllm` (`npx skills add ScaleDockHQ/llm-skills --skill vllm`), `llama-cpp`, or `llm-gateway`; producing the quant: `model-quantization`.
2. **Model IDs and URLs** from `/v1/models` on each endpoint. Through a gateway both can sit behind one base URL with two aliases; then `BASELINE_BASE_URL` and `CANDIDATE_BASE_URL` are equal.
3. **Config:** copy `templates/promptfooconfig.yaml`. It already has `baseline` and `candidate` providers with identical `temperature: 0`, `top_p`, `max_tokens`, `seed`, `showThinking: false`, and format assertions (`not-icontains: "<think>"`, `finish-reason: stop`, non-empty).
4. **Golden set:** `tests: file://golden-set.jsonl`, items tagged `metadata.critical: "yes"` for must-not-regress behaviour.

```bash
export BASELINE_BASE_URL=http://prod-host:8000/v1      CANDIDATE_BASE_URL=http://cand-host:8001/v1
export BASELINE_API_KEY="$(cat ~/.config/llm/baseline.key)"   # 0600 files; never echo
export CANDIDATE_API_KEY="$(cat ~/.config/llm/candidate.key)"
npx promptfoo@0.124.1 validate -c promptfooconfig.yaml
```

## 1. Measure the noise floor

Engines are not deterministic under batching even at temperature 0 unless configured for it, so run the baseline against itself first. Put the same endpoint in both slots of a throwaway config (or run the baseline label twice) and diff:

```bash
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --no-share --filter-providers '^baseline$' -o noise-a.jsonl
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --no-share --filter-providers '^baseline$' -o noise-b.jsonl
templates/ab-diff.sh noise-a.jsonl noise-b.jsonl 999   # the count of "regressions" + "fixes" is the flip noise
```

Record the flips. Allowed candidate regressions must not be set below that noise unless you accept false alarms.

## 2. Run both sides

```bash
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --no-share --filter-providers '^baseline$'  -o baseline.jsonl  -o baseline.json
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --no-share --filter-providers '^candidate$' -o candidate.jsonl -o candidate.json
```

Run candidate and baseline in the same job, back to back: a baseline measured months ago on an older engine is not a baseline.

## 3. Gate

```bash
templates/ab-diff.sh baseline.jsonl candidate.jsonl "${MAX_REGRESSIONS:-0}"        # exit 1 when regressions exceed the allowance
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --no-share \
  --filter-providers '^candidate$' --filter-metadata critical=yes                  # exit 100 on any critical failure (default threshold 100)
```

Two independent signals:

- `ab-diff.sh`: regressions are items that passed on baseline and fail on candidate; the allowance is a count agreed before the run (`MAX_REGRESSIONS`), usually the noise floor.
- The critical slice must pass on the candidate on its own (exit code `100` otherwise). A critical item that already fails on baseline is a golden-set bug; fix it first.

The script exits `2` when the two files cover different items or lack the expected fields, so a half-finished run cannot pass.

Read every regression's output before judging; a human verdict on critical regressions is part of the decision record. Keep format failures (`<think>` leakage, invalid JSON, truncation) at zero: they break integrations outright.

## 4. Wire it into CI

Start from `templates/llm-evals.yml` and add a job (or workflow) triggered by `workflow_dispatch` with inputs for the candidate URL, since a quantization candidate usually has no pull request. Keep these properties:

- Runs on a self-hosted runner that can reach both private endpoints (do not expose inference to the internet for CI).
- `--no-cache` on both sides; `PROMPTFOO_DISABLE_TELEMETRY=1`; `--no-share`.
- Secrets from `secrets.*`; URLs from `vars.*` or workflow inputs.
- `actions/upload-artifact` for `baseline.*`, `candidate.*`, `noise-*.jsonl`; short retention (they hold prompts and outputs).
- A final step that runs `ab-diff.sh` and fails the job.

## 5. Add the other signals, then decide

- Throughput and latency from the same run (`latency` metric, or a separate bench): a quant that is not faster or smaller has no point.
- Optional distribution screen with `llama-perplexity` (KL divergence) when both weight files exist, and a benchmark subset via `lm-evaluation-harness` (`npx skills add ScaleDockHQ/llm-skills --skill lm-evaluation-harness`). Both are screens, not the decision.
- Write the decision record (PASS, FAIL, PASS WITH CONDITIONS) with config, model IDs, versions, sampling, noise floor, regressions and artifacts.

## Pitfalls

- Cached results make candidate equal baseline. Always `--no-cache`.
- Reasoning models: apply the same `showThinking` and `chat_template_kwargs` to both, and check that a quant did not change thinking length (truncation shows as `finish-reason` failures).
- Chat template or tokenizer drift between the two servers; diff one rendered prompt via a raw `curl` to each.
- Too few items: with 30 items one flip is 3%. State thresholds as counts.
- Judge-based assertions inside the gate add variance; keep the gate deterministic and review judge results separately.
- `--repeat` produces several rows per `testIdx`; `ab-diff.sh` assumes one row per item, so use `--repeat` only for separate noise estimation.

Official sources: https://www.promptfoo.dev/docs/usage/command-line/, https://www.promptfoo.dev/docs/integrations/ci-cd/
