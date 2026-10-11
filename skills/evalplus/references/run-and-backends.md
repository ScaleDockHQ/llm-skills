# EvalPlus: generate, sanitize, evaluate

> Verified against EvalPlus 0.3.1 (docs `cli.md`, README, source `codegen.py`, `evaluate.py`, `provider/` at v0.3.1), 2026-10-11

## Commands

| Command             | Does                                                                               |
| ------------------- | ---------------------------------------------------------------------------------- |
| `evalplus.codegen`  | Generate solutions and post-process (sanitize) them. No code execution             |
| `evalplus.sanitize` | Clean model output into compilable code (strip prose, extra code)                  |
| `evalplus.syncheck` | Report code that does not compile before and after sanitizing                      |
| `evalplus.evaluate` | Generation, sanitizing and execution in one go, or execution only with `--samples` |
| `evalplus.evalperf` | EvalPerf efficiency evaluation (`execution-and-evalperf.md`)                       |

## `evalplus.codegen` flags (v0.3.1 source)

`--model`, `--dataset humaneval|mbpp|evalperf`, `--backend` (default `vllm`), `--root` (default `evalplus_results`), `--greedy`, `--n-samples` (default 1), `--temperature` (default 0.0), `--bs` (batch size; defaults to `min(n_samples, 32)`), `--resume` (default true), `--id-range 0 10` (subset for a smoke test), `--version` (dataset version), `--force-base-prompt`, `--base-url`, `--tp` (vLLM tensor parallel), `--attn-implementation` (hf), `--trust-remote-code` (executes model repo code: trusted repos only), `--dtype` (default bfloat16), `--evalperf-type instruct|perf-instruct|perf-CoT`.

`--greedy` forces temperature 0, `bs=1`, `n_samples=1`. Output: `<root>/<dataset>/<model>_<backend>_temp_<T>.jsonl`, for example `evalplus_results/humaneval/ise-uiuc--Magicoder-S-DS-6.7B_vllm_temp_0.0.jsonl`.

## Backends

| `--backend`                      | Notes                                                                                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `openai`                         | Any OpenAI-compatible chat server with `--base-url`; key from `OPENAI_API_KEY` (defaults to `none`). Chat only                              |
| `vllm`, `hf`                     | Local weights; base vs chat prompt auto-detected from `tokenizer.chat_template`; `--force-base-prompt` for base models that have a template |
| `anthropic`, `google`, `bedrock` | Hosted APIs (`ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `BEDROCK_ROLE_ARN`)                                                                     |
| `gptqmodel`                      | GPTQ-quantized models via GPTQModel                                                                                                         |
| `ollama`                         | `--base-url http://localhost:11434/v1`                                                                                                      |
| `hf_gaudi`                       | Intel Gaudi (Habana)                                                                                                                        |

For backends other than `hf` and `vllm` only the chat prompt mode is allowed.

### Against a served model

```bash
export OPENAI_API_KEY="$(cat ~/.config/llm/key)"      # skip for open local servers
evalplus.codegen --model "<served-model-name>" --dataset humaneval \
  --backend openai --base-url "http://localhost:8000/v1" --greedy --root evalplus_results
```

`--model` must equal the server's model id (`/v1/models`). The prompt is the instruction prefix "Please provide a self-contained Python script that solves the following problem in a markdown code block:" plus the task in a fenced block; the answer is taken from the code block.

### Fixed generation limits to know

In v0.3.1 `max_new_tokens` is a class default of 768 and has no CLI flag, and the OpenAI backend sends it as `max_tokens`. Consequences: long answers are cut and fail; servers or models that require `max_completion_tokens` instead may reject the request; and the sampling parameters beyond temperature (top_p and so on) are the server's defaults. Treat the score as "under a 768-token budget at the server's defaults".

### Reasoning and thinking models

Thinking text counts against the 768 tokens, and sanitizing extracts code from the response: a model that spends its budget thinking returns no code and scores zero. Options: disable thinking at the server or via the template for this eval (see the `reasoning-models` skill), or generate the samples yourself with a larger budget and score them with `--samples` (below). Say which you did.

## Own generation, then score

Samples file schema (`samples.jsonl`): one object per line with `task_id` and either `solution` (self-contained, usually includes the prompt) or `completion` (function body only); `solution` wins if both exist. A directory layout `${SAMPLE_DIR}/${TASK_ID}/${SAMPLE_ID}.py` (task id with `/` replaced by `_`) is also accepted.

```python
from evalplus.data import get_human_eval_plus, write_jsonl      # get_mbpp_plus for MBPP+
samples = [dict(task_id=t, solution=GEN(p["prompt"])) for t, p in get_human_eval_plus().items()]
write_jsonl("samples.jsonl", samples)
```

```bash
evalplus.sanitize --samples samples.jsonl            # writes samples-sanitized.jsonl
evalplus.syncheck --samples samples.jsonl --dataset humaneval
```

## Evaluate

```bash
evalplus.evaluate --dataset humaneval --samples samples-sanitized.jsonl     # executes code!
```

Flags: `--base-only`, `--parallel N` (default half the cores), `--test-details`, `--mini`, `--noextreme`, `--min-time-limit`, `--gt-time-limit-factor`, `--i-just-wanna-run` (ignore the cache), `--version`. Output example:

```
Base
{'pass@1': 0.884...}
Base + Extra
{'pass@1': 0.768}
```

`k` values of 1, 10, 100 are reported when the sample count allows. Results are cached as `<samples>_eval_results.jsonl`; delete it to rerun. Dataset overrides: `HUMANEVAL_OVERRIDE_PATH`, `MBPP_OVERRIDE_PATH` pointing to a `.jsonl.gz`.
