# DeepEval: troubleshooting

> Verified against deepeval 4.2.8 (docs: troubleshooting, command-line-interface, environment-variables, guides-using-custom-llms), 2026-10-11

| Symptom                                                               | Cause                                            | Fix                                                                                         |
| --------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `OPENAI_API_KEY` error or unexpected OpenAI traffic                   | No judge selected; family falls back to OpenAI   | `deepeval set-local-model ...` (or another provider), `deepeval diagnose`                   |
| Still using the old provider after `unset-*`                          | Another `USE_*` flag is still on in the family   | `deepeval settings -l`, unset the other provider                                            |
| `ValueError: Evaluation LLM outputted an invalid JSON`                | Judge too weak, no structured output             | Stronger judge, server-side JSON mode, schema-aware custom class (`references/judges.md`)   |
| `AttributeError` in Faithfulness or Summarization with a custom judge | `generate()` lacks the `schema` parameter        | Accept `schema` and return a schema instance                                                |
| Missing parameter error                                               | Test case lacks a field the metric needs         | Add the field (`references/tests-and-metrics.md` table) or `-s`                             |
| Rate limits or timeouts                                               | Concurrency above judge capacity                 | `AsyncConfig(max_concurrent=...)`, `throttle_value`, timeout overrides, fewer `-n` workers  |
| Scores identical across judge changes                                 | Cache (`-c`, `ENABLE_DEEPEVAL_CACHE`)            | Drop `-c`; clear `.deepeval/.deepeval-cache.json`                                           |
| Run passes despite judge errors                                       | `-i` / `IGNORE_DEEPEVAL_ERRORS=1`                | Count errored cases; do not ignore errors on gates                                          |
| Settings from `.env` not applied                                      | Dotenv loaded from cwd only                      | Run from the project dir, set `ENV_DIR_PATH`, remember precedence env, `.env.local`, `.env` |
| Dotenv picked up unexpectedly in CI                                   | Autoload at import                               | `DEEPEVAL_DISABLE_DOTENV=1`                                                                 |
| `SSLCertVerificationError` on upload                                  | Local certificate chain                          | Fix the chain; `CONFIDENT_DISABLE_SSL=1` only for self-hosted endpoints                     |
| Results appear in the cloud                                           | `CONFIDENT_API_KEY` set or `deepeval login` done | `deepeval logout`, unset the variable                                                       |
| Nothing printed from `set-*`                                          | `--quiet`                                        | Drop it                                                                                     |
| Local judge answers contain thinking text                             | Reasoning model                                  | Reasoning parser on the server; use a non-reasoning judge for strict JSON                   |
| Python 3.9 install resolves older dependencies                        | Some dependency ranges differ by Python          | Use Python 3.10+                                                                            |

Debug aids: `DEEPEVAL_VERBOSE_MODE=1`, `-v`, `DEEPEVAL_LOG_STACK_TRACES=1`, `deepeval set-debug` (see the CLI doc), `deepeval inspect`.

Official sources: https://deepeval.com/docs/troubleshooting, https://deepeval.com/docs/faq
