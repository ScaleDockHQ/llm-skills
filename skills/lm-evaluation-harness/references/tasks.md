# lm-evaluation-harness: tasks, prompts and generation settings

> Verified against lm-evaluation-harness v0.4.13 (docs/interface.md, docs/config_files.md, docs/chat-template-readme.md, docs/footguns.md, task tree at tag v0.4.13), 2026-10-11

## Finding and checking tasks

```bash
lm-eval ls tasks            # groups, subtasks and tags
lm-eval ls groups           # e.g. mmlu, glue
lm-eval ls subtasks         # e.g. mmlu_anatomy, hellaswag
lm-eval ls tags
lm-eval validate --tasks hellaswag,gsm8k      # existence, config syntax, dataset access, templates
```

Terms: a **group** aggregates metrics over subtasks (`mmlu` has 57), a **subtask** is one dataset task, a **tag** is a filter category with no aggregate. Task folders live under `lm_eval/tasks/` in the repo, each with a README that says what is measured and which metrics it reports. Names present at v0.4.13 include `gsm8k` (plus `gsm8k_cot*` variants), `hellaswag`, `mmlu`, `ifeval`, `arc_easy`, `arc_challenge` (and `arc_challenge_chat`), `truthfulqa`, `winogrande`, `lambada_openai`, `gpqa`, `minerva_math`, `humaneval`, and the `leaderboard` group. Read the task's README before choosing; names and variants change between versions.

## Which task kind needs which model type

- **`generate_until`** (GSM8K, IFEval, MATH, HumanEval): works on any model type, including `local-chat-completions`.
- **`loglikelihood` / multiple choice** (MMLU, HellaSwag, ARC, Winogrande): needs prompt logprobs, so `local-completions`, `vllm` or `hf`; never `local-chat-completions`. Some tasks ship a generative variant for chat endpoints (for example `arc_challenge_chat`).

## Prompt and chat template

| Flag                                    | Meaning                                                                                               |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `--apply_chat_template [name]`          | Wrap prompts in the model's chat template (default template, or a named one)                          |
| `--system_instruction "..."`            | System prompt prepended to prompts                                                                    |
| `--fewshot_as_multiturn`                | Few-shot examples as separate chat turns; auto-enabled with `--apply_chat_template`; `false` disables |
| `--num_fewshot N`                       | Few-shot count; override the task default deliberately and record it                                  |
| `--metadata '{"max_seq_length": 4096}'` | JSON passed to the task config (needed by some tasks such as RULER)                                   |

With `--apply_chat_template`, loglikelihood and multiple-choice requests use an empty target delimiter instead of the default space (upstream chat-template note). Runs with and without the flag are therefore not comparable. Apply the template exactly once: harness-side with a chat endpoint, not also baked into your prompt or a gateway.

## Generation

`--gen_kwargs temperature=0,max_gen_toks=1024` (values parsed with `ast.literal_eval`; `'stop=["\n\n"]'` for lists). Task YAML sets per-task defaults under `generation_kwargs`; CLI values override. In YAML, write newlines in double quotes (`until: ["\n"]`); single quotes keep the literal backslash-n (upstream footgun). The API model types read `max_tokens` or `max_gen_toks`, `temperature` (default 0), `until` and send them with the request `seed`.

Greedy decoding (`temperature=0`) is the comparable default. Do not mix sampled and greedy runs when comparing models.

## Reasoning models

Models that emit a thinking trace need the trace removed before metrics run.

- Endpoint chat models: `--model_args model=<id>,base_url=...,think_end_token="</think>"` with `--apply_chat_template`; the server must keep the delimiter inside `message.content` (a server-side reasoning parser that moves thinking elsewhere removes it).
- `vllm` and `sglang`: string `think_end_token`, plus `enable_thinking=True` to switch the template's thinking mode on (`enable_thinking` requires `think_end_token`; it only works with generative tasks, never loglikelihood).
- `hf`: `think_end_token` may be a string or a token ID (an ID avoids the string appearing in ordinary text).
- Find the correct closing token in the model's `tokenizer_config.json` chat template.
- Give reasoning models enough `max_gen_toks`; a cap that cuts the thinking leaves no answer to score.

## Config files

All CLI options exist as YAML keys; CLI values override the file.

```yaml
# eval_config.yaml (see templates/eval_config.yaml)
model: local-chat-completions
model_args:
  model: my-model
  base_url: http://localhost:8000/v1/chat/completions
  num_concurrent: 4
tasks:
  - gsm8k
apply_chat_template: true
gen_kwargs:
  temperature: 0
  max_gen_toks: 1024
log_samples: true
output_path: ./lm-eval-results
limit: 20
```

```bash
lm-eval run --config eval_config.yaml            # add --limit/--tasks to override
```

Schema keys: `model`, `model_args`, `tasks`, `num_fewshot`, `batch_size`, `max_batch_size`, `device`, `limit`, `samples`, `use_cache`, `cache_requests`, `output_path`, `log_samples`, `predict_only`, `apply_chat_template`, `system_instruction`, `fewshot_as_multiturn`, `include_path`, `gen_kwargs`, `wandb_args`, `hf_hub_log_args`, `seed`, `trust_remote_code`, `metadata`. Do not put keys in `model_args`.

## Custom tasks

External task YAMLs live in a directory passed with `--include_path DIR` (also for `lm-eval ls` and `lm-eval validate`). Authoring guide: https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/new_task_guide.md. For your own product data prefer `promptfoo`; a custom harness task is worth it only for metrics the harness already implements.

## Tasks that execute code or hub code

`--confirm_run_unsafe_code` acknowledges tasks that run arbitrary Python (generated code). `--trust_remote_code` lets Hugging Face hub code run. Both need explicit user approval; use a sandbox or disposable host.

Official sources: https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/interface.md, https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/config_files.md
