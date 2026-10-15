---
name: lm-evaluation-harness
description: Run EleutherAI's lm-evaluation-harness (lm_eval, lm-eval CLI) for public benchmarks (MMLU, GSM8K, HellaSwag, IFEval) on HF, vLLM or OpenAI-compatible endpoints via local-completions and local-chat-completions. Use for --apply_chat_template, --limit, --log_samples, logprobs/tokenizer errors, think_end_token. Not for task evals on your own data (promptfoo).
license: MIT
compatibility: Python >=3.10 (isolated venv); needs curl and jq for endpoint checks. hf and vllm backends need a GPU or Apple/CPU torch and large downloads. Installs, model or dataset downloads, GPU use and anything that pushes results to the Hugging Face Hub need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# lm-evaluation-harness

Produce comparable public-benchmark scores for a model, either directly (`hf`, `vllm`) or through its OpenAI-compatible server (`local-completions`, `local-chat-completions`), with settings you can record and repeat.

**Scope:** this one product: install, point at a backend, pick tasks, run, read output, update, troubleshoot. Deciding whether a benchmark matters for a product, and gates for quantization or engine changes, belong to `llm-evals`. Your own golden set belongs to `promptfoo`.

Work through the steps in order. Load a reference only when a step names it. Verified against lm-evaluation-harness v0.4.13 (PyPI latest, 2026-08-31) on 2026-10-11 from the docs and source at that tag; the CLI itself could not be run on the writing machine (Python 3.9), so confirm flags with `lm-eval run -h` on the installed version.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                        # needs >=3.10
command -v lm_eval lm-eval curl jq
lm-eval --help 2>/dev/null | head -5
pip show lm_eval 2>/dev/null | head -3

# Endpoint (key presence only)
echo "${LLM_BASE_URL:-unset}"; [ -n "${LLM_API_KEY:-}" ] && echo "LLM_API_KEY set" || echo "LLM_API_KEY not set"
curl -fsS -H "Authorization: Bearer ${LLM_API_KEY:-none}" "${LLM_BASE_URL:-http://localhost:8000/v1}/models" | jq -r '.data[].id'

# Does /v1/completions return prompt logprobs? (needed for loglikelihood and multiple-choice tasks)
curl -fsS -H "Authorization: Bearer ${LLM_API_KEY:-none}" -H 'Content-Type: application/json' \
  "${LLM_BASE_URL:-http://localhost:8000/v1}/completions" \
  -d '{"model":"<model-id>","prompt":"Hello","max_tokens":1,"logprobs":1,"echo":true}' | jq '.choices[0].logprobs != null'

# GPU for hf or vllm backends
nvidia-smi -L 2>/dev/null; uname -sm
```

## Decision flow

1. Model is served over HTTP and the task is generative (GSM8K, IFEval, MATH): `local-chat-completions` with `--apply_chat_template` (`references/endpoints.md`).
2. Task is loglikelihood or multiple choice (MMLU, HellaSwag, ARC, Winogrande): `local-completions`, and the server must return prompt logprobs with `echo`. A chat endpoint cannot run these (`references/endpoints.md`).
3. You have the weights and a GPU and want speed or exact reference numbers: `vllm` or `hf` backend, no server (`references/backends.md`).
4. Instruction-tuned model: use `--apply_chat_template` consistently on every compared run, and never apply it twice (server plus harness).
5. Reasoning model: `think_end_token` (and `enable_thinking` on `vllm` or `hf`) strips the trace before scoring (`references/tasks.md`).
6. Comparing a quantized model against its parent: `references/combos/quant-benchmark-check.md`.
7. Scores look wrong, a request errors, or the run is slow: `references/troubleshooting.md`.

## Rules

- **Public benchmarks are a prior, not a decision.** Decide on your own tasks (`llm-evals`, `promptfoo`).
- **Compare like with like.** Same harness version, task version, `--num_fewshot`, chat-template flags, `--gen_kwargs`, seed and `max_length` on both sides. Record them.
- **`--limit` is for smoke tests only.** Never report a `--limit` run as a benchmark result.
- **Smoke first.** `--limit 20 --log_samples`, read the samples and confirm answer extraction before a full run.
- **Keys through the environment.** `local-*` models read `OPENAI_API_KEY`; export it from your own variable. Never put a key in `--model_args` (it lands in logs and result files).
- **Isolate the install.** A venv per harness version; heavy backends (`vllm`, `hf`) pull large dependencies.
- **Remote datasets and code.** Tasks download datasets; some run model-generated code (`--confirm_run_unsafe_code`) and `--trust_remote_code` executes hub code. Ask first.
- **Contamination exists.** Treat a gain on a public benchmark with suspicion; see `llm-evals`.

## Workflows

### 1. Install

- [ ] Python >=3.10 venv; `pip install "lm_eval[api]==0.4.13"` for endpoint runs, `lm_eval[hf]` or `lm_eval[vllm]` for local backends. -> `references/install.md`
- [ ] Verify: `lm-eval --version` and `lm-eval ls tasks | head`.

### 2. Smoke run against a served model

- [ ] `export OPENAI_API_KEY="$LLM_API_KEY"`.
- [ ] Generative: `lm-eval run --model local-chat-completions --model_args model=<id>,base_url=$LLM_BASE_URL/chat/completions,num_concurrent=4 --tasks gsm8k --apply_chat_template --limit 20 --log_samples --output_path ./lm-eval-results`. -> `references/endpoints.md`
- [ ] Verify: open `samples_*.jsonl`, check `resps`/`filtered_resps` against `target`; no empty answers; no `<think>` text.

### 3. Full run and record

- [ ] Drop `--limit`; keep every other flag. Save `--output_path` with the config and model versions. -> `references/output.md`
- [ ] Verify: `results_*.json` exists under the model directory and lists every task with its metrics.

### 4. Local backend (vllm or hf)

- [ ] `--model vllm --model_args pretrained=<hf-id-or-path>,dtype=auto,gpu_memory_utilization=0.8,max_model_len=4096 --batch_size auto`. -> `references/backends.md`

### 5. Compare two models

- [ ] Same flags, two runs, diff the `results_*.json` metrics and read per-sample disagreements. -> `references/combos/quant-benchmark-check.md`

### 6. Update

- [ ] New venv with the new version, re-run the baseline before comparing. -> `references/updating.md`

## Reference index

- `references/install.md`: Python and extras, venv, versions, maintenance status, env vars.
- `references/endpoints.md`: `local-completions`, `local-chat-completions`, logprobs, tokenizer rules, `model_args`, auth.
- `references/backends.md`: `hf` and `vllm` backends, parallelism, dtype and quantization args.
- `references/tasks.md`: choosing tasks, few-shot, chat template, generation kwargs, reasoning models, config files, custom tasks.
- `references/output.md`: result files, samples, limits, caching, seeds, reproducibility.
- `references/troubleshooting.md`: errors and wrong-score causes.
- `references/updating.md`: upgrade procedure.
- `references/combos/quant-benchmark-check.md`: benchmark subset for a quantized model against its parent.
- `templates/eval_config.yaml`, `templates/run-endpoint.sh`: starting files.

## Companion skills

- `llm-evals`: eval strategy and quality gates. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `promptfoo`: task evals on your own golden set. Install: `npx skills add ScaleDockHQ/llm-skills --skill promptfoo`.
- `vllm`: serve the model with prompt logprobs; also the `vllm` backend's engine. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `llama-cpp`: local GGUF server as an endpoint. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `model-quantization`: produce the quantized candidates. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `reasoning-models`: thinking-token handling. Install: `npx skills add ScaleDockHQ/llm-skills --skill reasoning-models`.
