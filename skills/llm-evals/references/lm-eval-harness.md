# lm-evaluation-harness against OpenAI-compatible endpoints

> Verified against lm-evaluation-harness v0.4.13, 2026-10-11

## What it is and when to choose it

[lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness) (EleutherAI) is the reference runner for public benchmarks (MMLU, GSM8K, HellaSwag, ARC, and hundreds more). It can evaluate a model directly or through an inference server's OpenAI-compatible API.

Choose it to compare against published numbers, or as one extra signal in a quality gate. Do not use it as the main decision for a product feature; use your golden set (`promptfoo.md`).

## Install

It is an upstream Python CLI. Install it in an isolated environment, with the API extra:

```bash
pip install "lm_eval[api]"
lm_eval --help | head -20
```

The base package no longer bundles `transformers`/`torch`; the `api` extra is enough for endpoint evals. A Hugging Face tokenizer download may still be needed for some tasks (see tokenizer section).

## Minimal working config

Generative task on a chat endpoint (works with any OpenAI-compatible chat server):

```bash
export OPENAI_API_KEY="$LLM_API_KEY"     # local-* models read OPENAI_API_KEY; empty is allowed for open servers
lm_eval --model local-chat-completions \
  --model_args model=<model-id>,base_url=http://localhost:8000/v1/chat/completions,num_concurrent=4,max_retries=3,timeout=300 \
  --tasks gsm8k \
  --apply_chat_template \
  --limit 20 --log_samples \
  --output_path ./lm-eval-results
```

Loglikelihood / multiple-choice task on a completions endpoint:

```bash
lm_eval --model local-completions \
  --model_args model=<model-id>,base_url=http://localhost:8000/v1/completions,num_concurrent=4,max_retries=3,tokenized_requests=False,tokenizer=<hf-tokenizer-repo> \
  --tasks hellaswag \
  --limit 20 --log_samples \
  --output_path ./lm-eval-results
```

Remove `--limit` only after the smoke run's samples look correct.

## How it plugs into the stack

- **Endpoint:** `base_url` is the **full endpoint URL** (`.../v1/completions` or `.../v1/chat/completions`), unlike promptfoo which takes the `/v1` root.
- **Auth:** `local-completions` and `local-chat-completions` read the bearer token from `OPENAI_API_KEY` (empty string if unset). Export it from your own variable; never put a key in `--model_args`, which ends up in logs and result files.
- **Model types and what they can run:**

| `--model` | Endpoint | Request types | Notes |
| --- | --- | --- | --- |
| `local-completions` | `/v1/completions` | `generate_until`, `loglikelihood`, `loglikelihood_rolling`, `multiple_choice` | Loglikelihood needs `echo` + `logprobs` support |
| `local-chat-completions` | `/v1/chat/completions` | `generate_until` only | Batch size forced to 1; use `--apply_chat_template` |
| `openai-completions` / `openai-chat-completions` | OpenAI API | as above | Require `OPENAI_API_KEY` |
| `litellm`, `litellm-chat` | via LiteLLM SDK | `generate_until` | Alternative when going through a gateway |

- **Logprobs requirement:** for loglikelihood tasks the harness sends `prompt`, `max_tokens: 1`, `logprobs: 1`, `echo: true` and reads prompt token logprobs. vLLM's completions endpoint supports `echo` with `logprobs`. For other servers, test with the discovery `curl` in `SKILL.md`; if logprobs are missing, restrict yourself to generative tasks.
- **Tokenizer requirement:** loglikelihood tasks need tokenization to find the context length. `local-completions` defaults to `tokenizer_backend=auto` (uses a remote tokenizer endpoint if the server offers one, otherwise Hugging Face). Set `tokenizer=<hf-repo-or-path>` when the served model name is an alias that is not a Hugging Face repo. Chat models default to `tokenizer_backend=None`.
- **Gateways:** works through LiteLLM or llama-swap as long as the path and model alias are passed through unchanged.

## Operating

Common flags:

| Flag | Use |
| --- | --- |
| `--tasks a,b` | Task names; `lm-eval ls tasks` lists them |
| `--limit N` | First N examples per task; smoke runs only, never for reported numbers |
| `--num_fewshot N` | Few-shot count; keep identical across compared runs |
| `--apply_chat_template` | Wrap prompts in the chat template (needed for chat endpoints) |
| `--fewshot_as_multiturn` | Few-shot examples as separate chat turns |
| `--system_instruction "..."` | Add a system prompt |
| `--gen_kwargs temperature=0,max_gen_toks=512` | Generation settings |
| `--seed` | Seeds for `python,numpy,torch,fewshot` (default `0,1234,1234,1234`) |
| `--log_samples` | Save every prompt/response for inspection |
| `--output_path DIR` | Where results JSON (and samples) are written |
| `--use_cache PREFIX` | SQLite cache of model responses; leave off for gate runs |

The CLI is installed as both `lm_eval` and `lm-eval`; the single-command form used above is the legacy-compatible form of `lm-eval run`.

`model_args` keys for the API models: `model`, `base_url`, `tokenizer`, `tokenizer_backend`, `tokenized_requests`, `num_concurrent` (default 1), `max_retries` (default 3), `timeout` (seconds, default 30), `max_length` (default 2048), `max_gen_toks` (default 256 or task value), `batch_size`, `seed` (default 1234), `verify_certificate`, `header`. `local-chat-completions` also accepts `think_end_token` to strip reasoning before scoring.

## Tuning knobs worth knowing

- `num_concurrent` is the main throughput knob; match it to the server's batch capacity.
- `timeout` default is short; raise it for long generations or reasoning models.
- `max_length` default (2048) can truncate long few-shot prompts; raise it to the served context.
- `max_gen_toks` too low truncates chain-of-thought answers and tanks GSM8K-style scores.
- `think_end_token=</think>` (or your model's marker) for reasoning models on chat endpoints.

## Known pitfalls

- Using `local-chat-completions` for MMLU-style multiple-choice tasks: chat endpoints do not return prompt logprobs, so these tasks are unsupported. Use `local-completions` or a generative variant of the task.
- Forgetting `--apply_chat_template` on instruction-tuned models served via completions, or applying it twice (server template plus harness template).
- Comparing numbers run with different `--num_fewshot`, chat-template settings or harness versions.
- Reporting `--limit` runs as benchmark results.
- Treating public benchmark gains as product gains; contamination is common (`pitfalls.md`).

## Official links

- Repository and README (model APIs section): https://github.com/EleutherAI/lm-evaluation-harness
- API model guide (TemplateAPI arguments): https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/API_guide.md
- CLI interface: https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/interface.md
- OpenAI-compatible model implementations: https://github.com/EleutherAI/lm-evaluation-harness/blob/main/lm_eval/models/openai_completions.py
