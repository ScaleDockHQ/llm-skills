# promptfoo: troubleshooting

> Verified against promptfoo 0.124.1 (docs: troubleshooting, openai provider, vllm provider, command-line), 2026-10-11

Start with `LOG_LEVEL=debug npx promptfoo@0.124.1 eval ...` (or `--verbose`) and the logs under `~/.promptfoo/logs` (`PROMPTFOO_LOG_DIR` overrides). `npx promptfoo@0.124.1 debug` prints environment details.

| Symptom                                                        | Cause                                                                                       | Fix                                                                                                           |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Requests go to `api.openai.com` or "OpenAI API key is not set" | `apiBaseUrl` missing on that provider, or a model-graded assertion using the default grader | Put `apiBaseUrl` on the provider object; set the grader in `defaultTest.options.provider` (`assertions.md`)   |
| 404 on every call                                              | `apiBaseUrl` includes `/chat/completions`, or lacks `/v1`                                   | End it at the `/v1` root; promptfoo appends the endpoint path                                                 |
| 401/403 from a gateway                                         | `apiKeyEnvar` points at an unset or wrong variable (no fallback to `OPENAI_API_KEY`)        | Export the variable; test with `curl` to `/v1/models`                                                         |
| Sending an ambient `OPENAI_API_KEY` to a non-OpenAI host       | Default key fallback                                                                        | `useDefaultApiKey: false` plus `apiKeyEnvar` or `apiKeyRequired: false`                                       |
| Baseline and candidate look identical                          | Disk cache replayed the first run                                                           | `--no-cache` (or `promptfoo cache clear`)                                                                     |
| Output starts with `Thinking:` or contains `<think>`           | Reasoning returned in output; or generation stopped before `</think>`                       | `showThinking: false`, more `max_tokens`, disable thinking via `passthrough` (`providers.md`)                 |
| Judge errors: `Could not extract JSON`, odd scores             | Reasoning text parsed as judge output                                                       | `showThinking: false` on the grader provider; keep the full provider object in `defaultTest.options.provider` |
| Timeouts or ERROR rows on a single GPU                         | Default concurrency too high; slow first token                                              | `-j 2`; `PROMPTFOO_EVAL_TIMEOUT_MS`; `--retry-errors`                                                         |
| Run hangs                                                      | A stuck provider call                                                                       | Set `PROMPTFOO_EVAL_TIMEOUT_MS` and `PROMPTFOO_MAX_EVAL_TIME_MS`; both turn into errors, not hangs            |
| Exit code 100 in CI                                            | A failing test, or pass rate below `PROMPTFOO_PASS_RATE_THRESHOLD` (default 100)            | Read `results.json`; this is the gate working                                                                 |
| Exit code 1                                                    | Config invalid, provider unreachable or a crash                                             | `promptfoo validate -c ...`; check the debug log                                                              |
| `Cannot find module '@libsql/<platform>'`                      | Optional native binding skipped (packaging issue, not a Node version mismatch)              | Reinstall including optional dependencies; clear the npm cache                                                |
| Native build failures on install                               | Missing toolchain for a native dependency                                                   | See the "Native build failures" section of the upstream troubleshooting page                                  |
| Out of memory on large evals                                   | Large outputs held in memory                                                                | `PROMPTFOO_STRIP_RESPONSE_OUTPUT`, `PROMPTFOO_STRIP_GRADING_RESULT`, smaller `--filter-range` shards          |
| Behind a corporate proxy                                       | Proxy or CA                                                                                 | `HTTPS_PROXY`, `NO_PROXY`, `PROMPTFOO_CA_CERT_PATH`                                                           |
| `tests` JSONL parsed wrong                                     | Not one JSON object per line, or a wrong `file://` path (relative to the config)            | Validate with `jq -c . golden-set.jsonl`; run `validate`                                                      |
| Metadata filter matches too much                               | `--filter-metadata` is a case-sensitive substring match                                     | Use distinct values (`critical=yes`); repeat the flag for AND                                                 |
| A `latency` assertion fails or is meaningless                  | Cached replay or a cold model load                                                          | `--no-cache`; warm the server first                                                                           |

## Triage order for "scores dropped"

1. Did the endpoint, model ID or chat template change? Compare a raw `curl` response for one item with the stored output.
2. Is it truncation? Look for `finish-reason` failures and `<think>` text.
3. Is it the assertion? Read five failing outputs before touching the model.
4. Is it noise? Re-run with `--repeat 3 --no-cache` on the failing slice and run baseline against itself.

Deeper strategy (what counts as a regression, noise floors, decision records): `llm-evals`.

Official sources: https://www.promptfoo.dev/docs/usage/troubleshooting/, https://www.promptfoo.dev/docs/providers/vllm/
