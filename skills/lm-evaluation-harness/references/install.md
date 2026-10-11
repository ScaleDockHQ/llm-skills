# lm-evaluation-harness: install

> Verified against lm-evaluation-harness v0.4.13 (PyPI, README and pyproject.toml at tag v0.4.13), 2026-10-11

## Status

- Repository: https://github.com/EleutherAI/lm-evaluation-harness, MIT, not archived. Latest release v0.4.13 (2026-08-31); the default branch's last commit was 2026-09-14 and `pyproject.toml` on it says `0.4.14.dev0`. PyPI also lists a pre-release `0.5.0.dev1`; do not use pre-releases for comparable numbers.
- `requires-python >=3.10`. The writing machine had Python 3.9, so install and CLI behaviour in this skill come from the docs and source at the tag, not from a local run.

## Install (isolated venv)

```bash
python3 -m venv ~/.venvs/lm-eval-0.4.13
. ~/.venvs/lm-eval-0.4.13/bin/activate
pip install "lm_eval[api]==0.4.13"          # OpenAI-compatible endpoints
lm-eval --version
lm-eval ls tasks | head
```

Since December 2025 the base package no longer includes `transformers` or `torch`: install the backend you need as an extra.

| Extra                          | Use                                                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `api`                          | `local-completions`, `local-chat-completions`, `openai-*` (requests, aiohttp, tenacity, tqdm, tiktoken) |
| `hf`                           | `hf` backend (transformers, torch, accelerate, peft)                                                    |
| `vllm`                         | `vllm` backend (`vllm>=0.18` per pyproject)                                                             |
| `litellm`                      | `litellm` models                                                                                        |
| `ifeval`, `math`, `ruler`, ... | Task-specific dependencies (IFEval, math verification, RULER)                                           |
| `wandb`, `zeno`                | Result visualization                                                                                    |

Combine with `pip install "lm_eval[hf,vllm,api]==0.4.13"`. The `vllm` extra installs vLLM into this venv; if vLLM is already installed for serving, use a separate venv to avoid dependency fights. Ask before installing: `hf` and `vllm` pull multi-GB packages.

Task extras are required by individual tasks: if a task errors at import with a missing module, install the matching extra listed in `pyproject.toml` (for example `ifeval` for IFEval).

## Entrypoints

- `lm-eval` (subcommands `run`, `ls`, `validate`) and `lm_eval` (same CLI); also `python -m lm_eval`.
- `lm-eval run --model ...` is the explicit form. The legacy form without `run` (`lm_eval --model hf --tasks hellaswag`) still works: `run` is inserted automatically.

## Environment variables

| Variable                 | Meaning                                                                                                            |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `OPENAI_API_KEY`         | Bearer token for `local-completions` and `local-chat-completions` (empty string if unset); required for `openai-*` |
| `HF_TOKEN`               | Hugging Face token for gated models and datasets, and for Hub pushes                                               |
| `LMEVAL_LOG_LEVEL`       | `DEBUG`, `INFO`, `WARNING`, `ERROR` (replaces the deprecated `--verbosity`)                                        |
| `LM_HARNESS_CACHE_PATH`  | Where `--cache_requests` stores preprocessed prompts                                                               |
| `TOKENIZERS_PARALLELISM` | Auto-set to `false` by the CLI                                                                                     |
| `CUDA_VISIBLE_DEVICES`   | Selects GPUs for the `vllm` backend (its `device` arg is ignored)                                                  |

## First network use

Tasks download their datasets from the Hugging Face Hub on first use, and the `hf`/`vllm` backends download model weights; set `HF_HOME` to a disk with space and warm the cache before a timed run. Offline machines need the datasets and weights pre-fetched (use `huggingface-cli` or the `hugging-face` skill).

Official sources: https://github.com/EleutherAI/lm-evaluation-harness#install, https://pypi.org/project/lm-eval/
