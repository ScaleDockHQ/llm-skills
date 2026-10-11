# lm-evaluation-harness: output, limits, caching and reproducibility

> Verified against lm-evaluation-harness v0.4.13 (docs/interface.md, README, lm_eval/loggers/evaluation_tracker.py at tag v0.4.13), 2026-10-11

## Where results go

`--output_path DIR` (or a `.json` path) is required for any saved output, and `--log_samples` requires it. Layout, from the evaluation tracker source:

```text
<output_path>/<model_name_sanitized>/results_<ISO-timestamp>.json     # aggregated metrics plus run config
<output_path>/<model_name_sanitized>/samples_<task>_<ISO-timestamp>.jsonl   # one line per example (with --log_samples)
```

If `--output_path` ends in `.json`, the file name becomes `<stem>_<timestamp>.json` in that directory and samples sit beside it. Timestamps have `:` replaced by `-`. Re-running never overwrites: each run adds new timestamped files, so pick the latest deliberately when scripting.

The results JSON holds a `results` object keyed by task, a `task_hashes` object (hashes of docs, prompts and targets, only when samples are logged), and run metadata from the tracker: `model_source`, `model_name`, `system_instruction` with its SHA, `fewshot_as_multiturn`, `chat_template` with `chat_template_sha`, and `total_evaluation_time_seconds`. Compare `chat_template_sha` across the runs you compare to confirm both used the same template. The directory name comes from the first of `peft`, `delta`, `pretrained`, `model`, `path`, `engine` found in the model args. Other config fields (harness version, git hash) were not verified one by one: inspect your own file first:

```bash
f="$(ls -t lm-eval-results/*/results_*.json | head -n 1)"
jq 'keys' "$f"
jq '.results' "$f"                 # metric keys follow a "<metric>,<filter>" convention; confirm on your file
```

Each sample line has `arguments` (the exact request), `resps` and `filtered_resps` (raw and post-filter model output), `target`, per-metric scores, and `doc_hash`, `prompt_hash`, `target_hash`. Reading five samples is the fastest check that the prompt, template and answer extraction are right:

```bash
s="$(ls -t lm-eval-results/*/samples_gsm8k_*.jsonl | head -n 1)"
jq -c '{target, filtered_resps, arguments}' "$s" | head -n 5      # secrets are not written; the prompt is
```

Samples contain full prompts and outputs: treat the directory as sensitive when the eval data is.

## Limits and sampling

- `--limit N` (integer count) or a float `0.0-1.0` (fraction) per task. Upstream marks it testing only: small subsets are noisy and the first N are not a random sample. Never report `--limit` numbers.
- `--samples '{"task1": [0, 1, 2]}'` runs specific example indices; incompatible with `--limit`.
- `--predict_only` saves predictions without computing metrics (implies `--log_samples`).

## Caching

- `--use_cache PREFIX` stores model responses in SQLite so an interrupted run resumes. Caching is rank-dependent, so restart with the same GPU count. Leave it off for runs that feed a comparison, otherwise a "new" run may replay old responses.
- `--cache_requests true|refresh|delete` caches preprocessed prompts (path from `LM_HARNESS_CACHE_PATH`). Safe for speed; use `refresh` after changing a task or template.

## Seeds and determinism

`--seed` takes one integer or `python,numpy,torch,fewshot` (default `0,1234,1234,1234`; `None` skips one). The API model types also send a request `seed` (default 1234 via `model_args`). A seed makes few-shot selection repeatable; it does not make a batched inference server deterministic. For comparisons use greedy decoding, the same seed and the same harness version, and run the baseline twice to measure run-to-run variation before reading a delta.

Metrics come with `_stderr` entries for many tasks; a difference smaller than about twice the combined stderr is not evidence of change.

## Publishing and tracking (ask first)

- `--hf_hub_log_args hub_results_org=...,results_repo_name=...,push_results_to_hub=True,push_samples_to_hub=True,public_repo=False` pushes results and samples to a Hub dataset using `HF_TOKEN`. Samples include prompts; keep `public_repo=False` and do not push private eval data.
- `--wandb_args project=...,name=...` logs to Weights & Biases (extra `wandb`).

## Record with every result

Command line or config file, `lm_eval` version, task names, few-shot count, chat-template flags, `gen_kwargs`, seed, model ID and server or engine version, `max_length`, and the results file path. An unrecorded run did not happen.

Official sources: https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/interface.md, https://github.com/EleutherAI/lm-evaluation-harness#saving--caching-results
