# Predictions and getting patches from a model

> Verified against swebench 5.0.2 (PyPI wheel contents) and upstream docs on main, 2026-10-11

## Prediction format

JSON Lines, one object per instance:

```json
{
  "instance_id": "sympy__sympy-20590",
  "model_name_or_path": "my-model",
  "model_patch": "diff --git a/... (unified diff as a string)"
}
```

- `instance_id` must match the dataset. Missing instances count as "incomplete", empty patches as "empty", never as resolved.
- The patch is a `git diff` style unified diff of the repository at the task's base commit.
- `swebench eval -p` accepts `.json` (as written by mini-SWE-agent's `preds.json`) or `.jsonl`.

Quick sanity check:

```bash
jq -c '{instance_id, n: (.model_patch|length)}' preds.jsonl | head
jq -s 'length' preds.jsonl
```

## Who produces the patches

SWE-bench grades. An agent scaffold must read the issue, edit the repository in a sandbox and emit a diff. Options named by upstream:

- **mini-SWE-agent** (`pip install mini-swe-agent`, 2.4.6 at writing, Python >=3.10): `mini-extra swebench --subset verified --split test -m <model> -w 4 -o <dir>` writes `preds.json` plus trajectories. Flags: `-o` output, `-m` model, `-c` config, `-w` workers (default 1), `--subset` (default `lite`), `--split` (default `dev`, so pass `--split test`), `--slice 0:5`, `--filter <regex>`, `--redo-existing`, `--environment-class docker`. Single instance with interactivity: `mini-extra swebench-single`.
- **swebench infer** (upstream `main` only, not in PyPI 5.0.2): thin wrapper over `mini-extra swebench`, for example `swebench infer verified -m <model> --run-id r1 -w 8`, writing `preds.json` under `logs/inference/<run_id>`.
- SWE-agent, OpenHands and others: any scaffold works as long as it outputs the format above.
- Legacy completion-style utilities (`python -m swebench.inference.run_api`, `run_llama`) exist for retrieval-based baselines. They are not agentic and score far lower; use only to reproduce old papers.

## Model endpoint for mini-SWE-agent

mini-SWE-agent calls models through litellm. For a local OpenAI-compatible server set `custom_llm_provider` and `api_base` under `model.model_kwargs` in a config file, and set `cost_tracking: "ignore_errors"` (or `MSWEA_COST_TRACKING=ignore_errors`) since a local model has no price entry. Export the key variable the provider reads (`OPENAI_API_KEY` for OpenAI-compatible endpoints). Note the upstream warning that `api_key: os.environ/VAR` in a model config is sent literally, not resolved. Full flow: `references/combos/local-model-mini-swe-agent.md`.

Agent runs execute model-chosen shell commands inside containers (docker environment class recommended); mini's Linux containers assume x86. Check the scaffold's own docs for the config schema of your installed version: the model-config keys changed between mini-SWE-agent major versions.
