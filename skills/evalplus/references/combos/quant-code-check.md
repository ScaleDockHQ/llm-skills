# EvalPlus code-ability check for a quantized or swapped model on vLLM

> Verified against EvalPlus 0.3.1 (source `codegen.py`, `provider/openai.py`, docs `cli.md`, `execution.md`) and the OpenAI-compatible server flow documented in the vLLM skill, 2026-10-11

Goal: decide whether a quantization, engine change or model swap hurts code generation, using HumanEval+ and MBPP+ through the same OpenAI-compatible path for both sides. Strategy and thresholds belong to `llm-evals`; producing the quant belongs to `model-quantization`.

## Setup

1. Two servers (or one server restarted) with identical flags except the thing under test: baseline on `:8000`, candidate on `:8001`. See the `vllm` skill for serving.
2. Same `EvalPlus` version in one venv, `--greedy`, same `--dataset`, same prompt mode, same machine for execution.
3. If the model has thinking, turn it off for both (or generate with your own budget); see `run-and-backends.md`.

```bash
for side in baseline:8000 candidate:8001; do
  name=${side%%:*}; port=${side##*:}
  for ds in humaneval mbpp; do
    evalplus.codegen --model "<served-name>" --dataset $ds --backend openai \
      --base-url "http://localhost:$port/v1" --greedy --root "results/$name"
  done
done
```

## Execute (sandboxed)

```bash
for name in baseline candidate; do for ds in humaneval mbpp; do
  f=$(ls results/$name/$ds/*.jsonl | grep -v -e sanitized -e eval_results | head -1)
  docker run --rm --network none -v "$(pwd)/results:/app" ganler/evalplus:latest \
    evalplus.evaluate --dataset $ds --samples "/app/${f#results/}" | tee "results/$name/$ds.score.txt"
done; done
```

(The generated file name already holds model, backend and temperature. Sanitized files are produced next to the raw ones: check which of the two your version feeds to `evaluate`; `codegen` sanitizes by default, so the main `.jsonl` is already sanitized.)

## Decide

Compare Base + Extra pass@1 per dataset. One HumanEval+ task is 0.61 pp, one MBPP+ task 0.26 pp: a difference of a few tasks is within decode noise even at temperature 0, because batching can change numerics. Run the baseline twice against itself to measure that noise, as the `promptfoo` quant gate does. Record both versions, the Docker image digest, server flags and the 768-token cap in the decision record.
