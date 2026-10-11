# DeepEval: running, caching, storage and CI

> Verified against deepeval 4.2.8 (docs: command-line-interface, evaluation-flags-and-configs, evaluation-unit-testing-in-ci-cd, evaluation-local-backend-storage, environment-variables), 2026-10-11

## `deepeval test run`

Runs eval files through pytest with the DeepEval plugin.

```bash
deepeval test run tests/evals                         # directory
deepeval test run test_golden.py::test_app            # one test
deepeval test run tests/evals -x -i -n 4 -c -- --tb=short
```

| Option                           | Meaning                                               |
| -------------------------------- | ----------------------------------------------------- |
| `-v`, `--verbose`                | verbose pytest output and DeepEval verbose mode       |
| `-x`, `--exit-on-first-failure`  | stop at the first failure                             |
| `-i`, `--ignore-errors`          | continue when an evaluation (judge) error occurs      |
| `-s`, `--skip-on-missing-params` | skip cases lacking a metric's required fields         |
| `-n`, `--num-processes`          | pytest-xdist workers                                  |
| `-r`, `--repeat`                 | rerun each test case N times                          |
| `-c`, `--use-cache`              | reuse cached results when `--repeat` is not set       |
| `-id`, `--identifier`            | label the run                                         |
| `-m`, `--mark`                   | pytest marker expression                              |
| `-d`, `--display`                | final result display                                  |
| `-o`, `--official`               | mark as the official baseline on Confident AI (cloud) |

Anything after `--` goes to pytest. Exit status follows pytest, so a failing metric fails the job. Run `deepeval test run --help` for the installed version.

## Concurrency, errors, cache (for `evaluate()`)

- `AsyncConfig(run_async=True, throttle_value=0, max_concurrent=20)`: lower `max_concurrent` or raise `throttle_value` when the judge rate-limits or is a small local server.
- Error handling: `-i`/`ignore_errors` or `IGNORE_DEEPEVAL_ERRORS=1` keeps a run going when a judge returns invalid output, but errored cases are then not verified; count them.
- `CacheConfig(use_cache=False, write_cache=True)`; `-c` reads `.deepeval/.deepeval-cache.json`, keyed by test-case content and metric configuration. Disable caching (`ENABLE_DEEPEVAL_CACHE=0`, omit `-c`) on decision runs so a changed judge is not masked.
- Retries: `DEEPEVAL_RETRY_MAX_ATTEMPTS` (default 2, so one retry), `DEEPEVAL_RETRY_INITIAL_SECONDS`, `DEEPEVAL_RETRY_CAP_SECONDS`. Timeouts: `DEEPEVAL_PER_ATTEMPT_TIMEOUT_SECONDS_OVERRIDE`, `DEEPEVAL_PER_TASK_TIMEOUT_SECONDS_OVERRIDE`, `DEEPEVAL_DISABLE_TIMEOUTS=1`. Raise them for slow local judges.

## Results and local storage

- JSON backend (default): `.deepeval/.latest_run_full.json` is the latest run; set `DEEPEVAL_RESULTS_FOLDER` (or a `results_folder`) to keep a timestamped `test_run_<ts>.json` per run.
- SQLite: `deepeval set-local-store sqlite` (or `DEEPEVAL_LOCAL_STORE=sqlite`) appends runs to `deepeval.db` with tables `test_runs`, `test_cases`, `traces`, `spans`, `metric_data`; query with plain SQL, for example `sqlite3 .deepeval/deepeval.db '.tables'`.
- `deepeval inspect` opens the latest run in a local terminal UI, no upload. `DEEPEVAL_NO_INSPECT_PROMPT=1` removes the post-run prompt on CI.
- Everything in `.deepeval/` can contain prompts and outputs; keep it git-ignored.

## CI

```yaml
# see templates/deepeval-ci.yml
- run: pip install "deepeval==4.2.8"
- run: deepeval test run tests/evals -x
  env:
    DEEPEVAL_TELEMETRY_OPT_OUT: "1" # if policy requires
    DEEPEVAL_DISABLE_DOTENV: "1"
    CONFIDENT_OPEN_BROWSER: "0"
    LOCAL_MODEL_API_KEY: ${{ secrets.JUDGE_API_KEY }}
```

- PR tier: deterministic and small critical set; full judged suite on a schedule or label.
- Judge reachability: CI must reach the judge (a self-hosted runner for a private server, or a hosted judge with an approved secret).
- Do not set `CONFIDENT_API_KEY` in CI unless uploading results is approved; when set, results upload automatically.
- `deepeval gate` checks a project against a Confident AI governance policy and needs that cloud setup; it is not required for pytest-style gating.
- Verify: a deliberately failing case makes the job fail.

Official sources: https://deepeval.com/docs/command-line-interface, https://deepeval.com/docs/evaluation-flags-and-configs, https://deepeval.com/docs/evaluation-unit-testing-in-ci-cd
