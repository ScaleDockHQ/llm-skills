# lm-evaluation-harness benchmark check for a quantized model

> Verified against lm-evaluation-harness v0.4.13 (docs and source at the tag), 2026-10-11

The serving side (vLLM, llama.cpp) is not re-verified here; use the `vllm` and `llama-cpp` skills for its flags.

Goal: a cheap, comparable public-benchmark signal that a quantized model has not drifted from its parent. This is a **screen**, never the decision: the decision is the task eval on your own golden set (`promptfoo` plus `llm-evals`, see `quality-gates.md` there).

## Protocol

1. **Two models, one difference.** Parent (BF16 or FP16 or the current production quant) and candidate (the new quant). Same model family, same chat template, same tokenizer. Produce quants with `model-quantization`.
2. **Same harness version and venv** for both (`pip install "lm_eval[api]==0.4.13"`).
3. **Pick tasks that expose damage.** A generative reasoning task (`gsm8k`), a multiple-choice task (`hellaswag` or `arc_challenge`), and an instruction-following task (`ifeval`, needs the `ifeval` extra) cover different failure modes. Quantization usually shows first on long generations and exact-format tasks.
4. **Serve each model in turn** with the same engine settings except the quantization, and run the same commands. With one GPU, run parent and candidate sequentially and record both.
5. **Run noise first** (parent twice) if the engine is not deterministic; use the delta against that as your noise floor.
6. **Compare** and read disagreements.

## Commands

Smoke (both models), then full:

```bash
export LLM_API_KEY=...            # from a 0600 file; never echo
export LLM_BASE_URL=http://localhost:8000/v1
LIMIT=20 templates/run-endpoint.sh chat parent-model gsm8k
# read samples, then drop LIMIT:
OUT=./results/parent  templates/run-endpoint.sh chat parent-model gsm8k,ifeval
OUT=./results/quant   templates/run-endpoint.sh chat quant-model  gsm8k,ifeval
TOKENIZER=<hf-repo> OUT=./results/parent templates/run-endpoint.sh completions parent-model hellaswag,arc_challenge
TOKENIZER=<hf-repo> OUT=./results/quant  templates/run-endpoint.sh completions quant-model  hellaswag,arc_challenge
```

(`templates/` is this skill's folder; adjust the path to where the skill is installed.)

Without a server, load both with the `vllm` backend (separate venv or `lm_eval[vllm]`), one at a time:

```bash
CUDA_VISIBLE_DEVICES=0 lm-eval run --model vllm \
  --model_args pretrained=<parent-or-quant-path>,dtype=auto,max_model_len=4096,gpu_memory_utilization=0.8 \
  --tasks gsm8k,hellaswag --apply_chat_template --batch_size auto \
  --log_samples --output_path ./results/<name>
```

Compare:

```bash
templates/compare-results.sh "$(ls -t results/parent/*/results_*.json | head -n 1)" "$(ls -t results/quant/*/results_*.json | head -n 1)"
```

The script prints each metric with the delta and whether it is within twice the combined stderr.

## Reading the result

- A delta inside noise (twice the combined stderr, and inside the parent's run-to-run variation) is "no detectable change", not "identical".
- A drop concentrated in `gsm8k` strict match but not flexible extract is usually a format or truncation change: read samples before concluding the quant is worse.
- Loglikelihood tasks (HellaSwag, ARC) are the least sensitive to quantization damage on generation; do not let them reassure you alone.
- Large moves on one task and none elsewhere point to a template, tokenizer or truncation difference between the two servers. Diff one rendered request (`--write_out`, or the server logs) before blaming the weights.
- Pair this with a KL divergence screen when both weight files exist (`llama-perplexity`, described in `llm-evals` `quality-gates.md`) and with the task gate.

## Pitfalls

- Different `max_length`, few-shot, chat-template flags or `gen_kwargs` between the two runs.
- `--limit` runs compared (first-N subsets are noisy).
- Reasoning models: apply the same `think_end_token` setting and a cap high enough that the quantized model's longer thinking is not truncated.
- Running the parent on a different engine version than the candidate.
- Reporting public-benchmark parity as proof your product behaves the same.

Companion skills: `vllm`, `llama-cpp`, `model-quantization`, `llm-evals`, `promptfoo` (install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`).

Official sources: https://github.com/EleutherAI/lm-evaluation-harness, https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/interface.md
