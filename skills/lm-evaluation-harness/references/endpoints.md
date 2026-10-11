# lm-evaluation-harness: OpenAI-compatible endpoints

> Verified against lm-evaluation-harness v0.4.13 (lm_eval/models/openai_completions.py, api_models.py, utils.py, docs/API_guide.md, docs/interface.md at tag v0.4.13), 2026-10-11

The harness can evaluate any server that speaks the OpenAI completions or chat-completions API (vLLM, SGLang, llama.cpp `llama-server`, LiteLLM, llama-swap, cloud). `base_url` is the **full endpoint URL**, unlike promptfoo's `/v1` root.

## Which model type for which task

| `--model`                                        | Endpoint                  | Request types                                                               | Notes                                                                                               |
| ------------------------------------------------ | ------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `local-completions`                              | `.../v1/completions`      | `generate_until`, `loglikelihood`, `loglikelihood_rolling`, multiple choice | Loglikelihood sends `echo: true`, `logprobs: 1`, `max_tokens: 1` and reads prompt logprobs          |
| `local-chat-completions`                         | `.../v1/chat/completions` | `generate_until` only                                                       | `loglikelihood` raises `NotImplementedError`; batch size forced to 1; needs `--apply_chat_template` |
| `openai-completions` / `openai-chat-completions` | OpenAI API                | as above                                                                    | Require `OPENAI_API_KEY`; OpenAI only supports prompt logprobs on `babbage-002`, `davinci-002`      |
| `litellm`                                        | via the LiteLLM SDK       | `generate_until`                                                            | Alternative through a gateway (extra `litellm`)                                                     |

Upstream's own note: loglikelihood and multiple-choice tasks (such as MMLU) are only supported for completion endpoints, not chat endpoints. A completions API that serves an instruct model can still use `--apply_chat_template` to format prompts with the chat template and keep access to logits.

## Generative task on a chat endpoint

```bash
. ~/.venvs/lm-eval-0.4.13/bin/activate
export OPENAI_API_KEY="$LLM_API_KEY"      # empty is allowed for open servers
lm-eval run --model local-chat-completions \
  --model_args model=<model-id>,base_url=http://localhost:8000/v1/chat/completions,num_concurrent=4,max_retries=3,timeout=300 \
  --tasks gsm8k \
  --apply_chat_template \
  --gen_kwargs temperature=0,max_gen_toks=1024 \
  --limit 20 --log_samples \
  --output_path ./lm-eval-results
```

`model_args` accepts `key=val,key2=val2` (comma separated) or space separated pairs. Remove `--limit` only after the smoke run's samples look right.

## Loglikelihood task on a completions endpoint

```bash
lm-eval run --model local-completions \
  --model_args model=<model-id>,base_url=http://localhost:8000/v1/completions,num_concurrent=4,max_retries=3,tokenized_requests=False,tokenizer_backend=huggingface,tokenizer=<hf-repo-or-path> \
  --tasks hellaswag \
  --limit 20 --log_samples \
  --output_path ./lm-eval-results
```

Add `--apply_chat_template` for an instruct model on a completions endpoint. The harness then sets the target delimiter to an empty string for loglikelihood tasks (upstream chat-template note), so scores are not comparable with runs that omit the flag.

## What the server must provide

- **Prompt logprobs.** `echo: true` with `logprobs` on `/v1/completions`. vLLM supports this; for other servers test with the `curl` in `SKILL.md` (`.choices[0].logprobs != null`). When it is null, only generative tasks can run.
- **Token IDs in `logprobs.token_logprobs` and `top_logprobs`** aligned with the harness tokenizer: that is why the tokenizer must match the served model.
- **`seed`, `stop`, `max_tokens`, `temperature`:** sent by the harness on every request. The chat model type sends at most four stop sequences (`stop[:4]`).
- **Reasoning delimiter in `content`** when you use `think_end_token` (the server must return the delimiter inside the message content; with vLLM a reasoning parser that moves thinking to `reasoning_content` removes the delimiter the harness is looking for).

## Tokenizer rules

- `local-completions` defaults to `tokenizer_backend=auto`: it probes the server for the remote `/tokenizer_info` and `/tokenize` endpoints (a vLLM feature). If both work it uses the remote tokenizer, otherwise it falls back to Hugging Face. The probe sends `Authorization: Bearer` only if you pass `auth_token`, and does not use `OPENAI_API_KEY`, so on an authenticated server auto-detection can fail and fall back silently.
- Set `tokenizer_backend=huggingface` and `tokenizer=<hf-repo-or-local-path>` explicitly when the served name is an alias that is not a Hugging Face repo, when the server requires auth, or when you want the same tokenizer on both sides of a comparison.
- `tokenized_requests` defaults to `True` (sends token IDs); `False` decodes back to text before sending. Use `False` when the server or gateway does not accept token arrays; it is ignored for chat inputs.
- `local-chat-completions` defaults to `tokenizer_backend=None` and passes strings through.

## `model_args` reference (defaults from source)

| Key                                       | Default                                  | Meaning                                                                                        |
| ----------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `model` (or `pretrained`)                 | required                                 | Model ID as the server lists it; `model` wins if both are set                                  |
| `base_url`                                | none                                     | Full endpoint URL                                                                              |
| `tokenizer`, `tokenizer_backend`          | `auto` / HF (completions); `None` (chat) | See above; backends: `huggingface`, `tiktoken`, `remote`, `None`                               |
| `tokenized_requests`                      | `True`                                   | Send token arrays instead of text                                                              |
| `num_concurrent`                          | `1`                                      | Parallel requests; the main throughput knob                                                    |
| `timeout`                                 | `300` in source                          | Seconds per request (the interface docs page says 30; trust the source or test)                |
| `max_retries`                             | `3`                                      | Retries for failed requests                                                                    |
| `max_length`                              | `2048`                                   | Max input plus output tokens; raise to the served context to avoid truncating few-shot prompts |
| `max_gen_toks`                            | `256` (or task value)                    | Generation cap; too low truncates chain-of-thought answers                                     |
| `batch_size`                              | `1`                                      | Requests per call (completions only; chat forced to 1)                                         |
| `seed`                                    | `1234`                                   | Sent as the request `seed`                                                                     |
| `add_bos_token`, `custom_prefix_token_id` | off                                      | Tokenization tweaks for loglikelihood                                                          |
| `verify_certificate`, `ca_cert_path`      | `True` / none                            | TLS controls                                                                                   |
| `auth_token`                              | none                                     | Bearer token for the remote tokenizer probe only                                               |
| `header`                                  | `Authorization: Bearer $OPENAI_API_KEY`  | Custom request headers                                                                         |
| `think_end_token` (chat)                  | none                                     | String; everything up to and including its last occurrence is dropped before scoring           |

Never put a key in `model_args` (`auth_token` included): `model_args` are written to logs and result files. Prefer `OPENAI_API_KEY`; for the tokenizer probe use `tokenizer_backend=huggingface`.

## Gateways and path rules

- Through LiteLLM or llama-swap pass the path and model alias unchanged: `base_url=http://gateway:4000/v1/chat/completions`, `model=<alias>`.
- llama.cpp `llama-server` serves both endpoints, but loglikelihood quality depends on its logprob output; run the `curl` check and a `--limit 20` smoke test before trusting numbers.
- A server that applies its own chat template on `/v1/chat/completions` plus `--apply_chat_template` in the harness is correct for the chat model type (the harness sends messages, the server renders them). Do not additionally pre-render the template into a completions prompt.

Official sources: https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/API_guide.md, https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/interface.md, https://github.com/EleutherAI/lm-evaluation-harness/blob/main/lm_eval/models/openai_completions.py
