# Local model to graded SWE-bench result

> Verified against swebench 5.0.2, mini-SWE-agent 2.4.6 docs (usage/swebench, models/local_models) and the vLLM skill's OpenAI-compatible flow, 2026-10-11

Goal: serve an open model, let mini-SWE-agent produce patches for a small slice of SWE-bench Verified, grade them with the harness. Serving belongs to the `vllm` skill. Nothing below was executed on the authoring host (Python 3.9, no GPU); confirm each flag with `--help`.

## 1. Endpoint

Serve with tool-friendly settings and confirm it answers (see the `vllm` skill):

```bash
URL="${LLM_BASE_URL:-http://localhost:8000/v1}"
curl -fsS ${OPENAI_API_KEY:+-H "Authorization: Bearer $OPENAI_API_KEY"} "$URL/models" | jq -r '.data[].id'
```

Agent trajectories are long: serve with a large context window (agents on SWE-bench routinely exceed 32k tokens) and enough concurrent slots for `-w`.

## 2. Agent config

Copy mini's default `swebench.yaml` (path from the installed package) and change only the model block:

```yaml
model:
  model_name: "<served-name>"
  cost_tracking: "ignore_errors"
  model_kwargs:
    custom_llm_provider: "openai"
    api_base: "http://localhost:8000/v1"
```

Keep the key out of the file: `export OPENAI_API_KEY=$(cat ~/.config/llm/key)` from a `0600` file, or any non-empty placeholder for a keyless local server.

## 3. Generate (needs approval: runs model-chosen commands in Docker)

```bash
mini-extra swebench --subset verified --split test --slice 0:5 \
  -c ./swebench-local.yaml -w 2 -o out/local-run1 --environment-class docker
jq 'length' out/local-run1/preds.json
```

Start with `--slice 0:5`; scale only after the patches look sane. Remember `--split` defaults to `dev`.

## 4. Grade

```bash
swebench eval verified -p out/local-run1/preds.json -i <id1> -i <id2> -j 2 --run-id local-run1
jq . logs/evaluation/local-run1/results.json | head -30
```

Omit `-i` to grade everything in `preds.json`; instances absent from the predictions are reported as incomplete, so for a slice compare against the slice, not the 500.

## 5. Compare models

Change only the model (and its server flags); keep the slice, scaffold version, config and `swebench` version. Use a new `run_id` per model. With a slice of five, a difference of one task is noise; treat anything under a full-dataset run as a smoke test, and record decisions through `llm-evals`.
