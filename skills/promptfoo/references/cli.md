# promptfoo: CLI, outputs, exit codes and environment

> Verified against promptfoo 0.124.1 (docs: command-line, outputs, caching, sharing), 2026-10-11

Invoke as `npx promptfoo@0.124.1 <command>` (or `npx promptfoo` with a dev dependency). With no `-c`, `eval` reads `promptfooconfig.yaml` in the current directory.

## Commands you will use

| Command                            | Use                                                                                |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| `eval`                             | Run the evaluation                                                                 |
| `validate` / `validate config`     | Check a config against the schema; exits 1 on failure (a cheap CI step)            |
| `validate target`                  | Test provider connectivity from config                                             |
| `view`                             | Local web viewer for past evals                                                    |
| `list`, `show <id>`, `delete <id>` | Inspect and manage eval history                                                    |
| `retry <evalId>`                   | Re-run errored results of an eval                                                  |
| `export eval <evalId>`, `import`   | Move results between machines                                                      |
| `cache clear`                      | Clear the response cache                                                           |
| `debug`                            | Print environment details (including detected proxy settings)                      |
| `init`                             | Scaffold an example project                                                        |
| `share [id]`                       | Upload an eval to a viewer. Sends prompts, outputs and provider config. Ask first. |

## `eval` flags

| Flag                                                                             | Use                                                                                       |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `-c, --config <paths...>`                                                        | Config file(s)                                                                            |
| `-o, --output <paths...>`                                                        | `csv`, `txt`, `json`, `jsonl`, `yaml`, `yml`, `html`, `xml`, `junit.xml`; repeat the flag |
| `--no-cache`                                                                     | Do not read or write the response cache; use for any run that feeds a decision            |
| `--repeat <n>`                                                                   | Run each test n times (noise estimation); range filters apply before repeat expansion     |
| `-j, --max-concurrency <n>`                                                      | Concurrent API calls; lower for single-GPU servers                                        |
| `--delay <ms>`                                                                   | Delay between tests                                                                       |
| `--filter-providers <regex>` (alias `--filter-targets`)                          | Only providers whose `id` or `label` matches                                              |
| `--filter-metadata key=value`                                                    | Slice by metadata (substring, case-sensitive; commas OR; repeated flags AND)              |
| `--filter-pattern <regex>`                                                       | Tests whose description matches                                                           |
| `-n, --filter-first-n <n>`                                                       | First N tests                                                                             |
| `--filter-range <start:end>`                                                     | Zero-based, end exclusive; for sharding (`0:100`, `100:200`, `200:`)                      |
| `--filter-sample <n>` with `--filter-sample-seed <n>`                            | Random but repeatable subset                                                              |
| `--filter-failing <path or id>`, `--filter-failing-only`, `--filter-errors-only` | Re-run previous failures (with or without errors)                                         |
| `--retry-errors`                                                                 | Retry ERROR results from the latest eval                                                  |
| `--resume [evalId]`                                                              | Resume an interrupted eval                                                                |
| `--grader <provider>`                                                            | Override the grader for model-graded assertions                                           |
| `--var <key=value>`                                                              | Set a variable                                                                            |
| `--env-file <path>`                                                              | Load a `.env` file (repeat or comma-separate; later files win)                            |
| `--no-share`                                                                     | Never create a share URL (overrides config)                                               |
| `--no-write`                                                                     | Do not write results to the promptfoo directory                                           |
| `--no-progress-bar`, `--no-table`                                                | Quiet output for CI                                                                       |
| `--tag key=value`, `--description <text>`                                        | Label a run                                                                               |
| `-w, --watch`                                                                    | Re-run when the config changes                                                            |

In `eval`, `-v` means `--vars`, not verbose. For debug logs use `--verbose` or `LOG_LEVEL=debug`.

## Exit codes

- `0`: all tests passed.
- `100`: at least one failed test, or pass rate below `PROMPTFOO_PASS_RATE_THRESHOLD` (percent, default 100).
- `1`: any other error (config invalid, provider unreachable, crash).
- `PROMPTFOO_FAILED_TEST_EXIT_CODE` overrides `100`.

Errors (timeouts, HTTP failures) count as ERROR results, not failures; check both the exit code and the error count in the JSON output before trusting a green run.

`promptfoo eval --fail-on-error` appears in the CI/CD guide but is not in the `eval` option table of the command-line reference for 0.124.1 and could not be confirmed in the source: unverified, do not rely on it. Use the exit codes above.

## Outputs

`-o results.json` contains `.results.stats` (`successes`, `failures`, and error counts) and per-row results. `-o results.junit.xml` feeds native CI test reports. `-o report.html` is a standalone report. `-o results.jsonl` writes one result per line. Check the first lines of your own output before writing `jq` against them; field names are upstream's and can change between versions.

```bash
jq '.results.stats' results.json
```

## Per-item comparison of two providers

Run each label separately so the rows align, then diff with `jq` (JSONL rows carry `testIdx` and `success`; verify on your output):

```bash
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --filter-providers '^baseline$'  -o baseline.jsonl
npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache --filter-providers '^candidate$' -o candidate.jsonl
jq -n --slurpfile a baseline.jsonl --slurpfile b candidate.jsonl '
  ($a | map({key: (.testIdx|tostring), value: .success}) | from_entries) as $A
  | ($b | map({key: (.testIdx|tostring), value: .success}) | from_entries) as $B
  | { items: ($A|length),
      baseline_pass: ([$A[]|select(.)]|length),
      candidate_pass: ([$B[]|select(.)]|length),
      regressions: [ $A|keys[] | select($A[.] == true  and $B[.] == false) ],
      fixes:       [ $A|keys[] | select($A[.] == false and $B[.] == true ) ] }'
```

This assumes no `--repeat`; with repeats there are several rows per `testIdx`. Do not use `--share` on these runs.

## Environment variables

| Variable                                                                                                                  | Meaning                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `PROMPTFOO_PASS_RATE_THRESHOLD`                                                                                           | Minimum pass rate (percent) for exit 0; default 100                                                      |
| `PROMPTFOO_FAILED_TEST_EXIT_CODE`                                                                                         | Replace exit code 100                                                                                    |
| `PROMPTFOO_CACHE_ENABLED`, `PROMPTFOO_CACHE_TYPE`, `PROMPTFOO_CACHE_PATH`, `PROMPTFOO_CACHE_TTL`                          | Cache switch, `disk` or `memory`, location (default `~/.promptfoo/cache`), TTL seconds (default 14 days) |
| `PROMPTFOO_CONFIG_DIR`, `PROMPTFOO_LOG_DIR`                                                                               | State and log directories                                                                                |
| `PROMPTFOO_EVAL_TIMEOUT_MS`, `PROMPTFOO_MAX_EVAL_TIME_MS`                                                                 | Per-call and whole-run timeouts; hits become errors                                                      |
| `PROMPTFOO_STRIP_RESPONSE_OUTPUT`, `PROMPTFOO_STRIP_TEST_VARS`, `PROMPTFOO_STRIP_PROMPT_TEXT`, `PROMPTFOO_STRIP_METADATA` | Remove sensitive or bulky data from stored results                                                       |
| `PROMPTFOO_DISABLE_UPDATE`                                                                                                | Disable update checks                                                                                    |
| `PROMPTFOO_DISABLE_TEMPLATE_ENV_VARS`                                                                                     | Only config `env:` values are available to templates                                                     |
| `PROMPTFOO_CA_CERT_PATH`, `HTTPS_PROXY`, `NO_PROXY`                                                                       | Custom CA bundle and proxy settings                                                                      |
| `LOG_LEVEL=debug`                                                                                                         | Debug logging                                                                                            |

Caching: disk caching is on by default. A cache hit means no request reached the endpoint. For gate runs always use `--no-cache`; in CI you may cache PR runs keyed on the eval files, but never the run that decides a numerics change.

Official sources: https://www.promptfoo.dev/docs/usage/command-line/, https://www.promptfoo.dev/docs/configuration/outputs/, https://www.promptfoo.dev/docs/configuration/caching/
