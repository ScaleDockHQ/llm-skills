# Inspect AI: running, logs, sets and sandboxes

> Verified against inspect-ai 0.3.278 (docs: options, models-concurrency, parallelism, eval-sets, handling-errors, eval-logs, log-viewer, caching, sandboxing), 2026-10-11

## Concurrency

- Per model, adaptive connections are on by default (starts at 20, max 100, floor 10; introduced in v0.3.217). Set the ceiling with `--adaptive-connections 50`, a range `5-50` or `min-start-max`. A fixed ceiling is `--max-connections`. The options table in the docs still lists `--max-connections` default 10; the concurrency page describes the adaptive default, so read `inspect eval --help` for the installed version.
- `--max-samples` (defaults to the connection limit, tracks the adaptive limit), `--max-tasks` (default 1 for `eval`), `--max-subprocesses`, `--max-sandboxes`.
- Self-hosted servers have no rate limit but a throughput limit: set the ceiling near the server's `--max-num-seqs` or similar, otherwise requests queue and time out.

## Errors, retries, limits

- Default: any sample error fails the eval (log status `error`, finished samples preserved). `--fail-on-error 0.1` tolerates 10 percent, `5` tolerates five samples, `--no-fail-on-error` never fails; failed samples are not scored.
- `--retry-on-error[=N]` re-runs errored samples; retried samples can shift the distribution, so compare their results with the rest. Original errors are in `error_retries`.
- Resume a failed or cancelled task: `inspect eval-retry logs/<file>`. It writes a new log, keeps the `task_id`, reuses finished samples, and needs a `@task` function. Lower load on retry from Python: `eval_retry(log, max_connections=3)`.
- Crash (OOM, `kill -9`): log status stays `started` and unflushed samples are lost; `--log-buffer` controls how many samples are buffered before a write.
- Limits per sample: `--message-limit`, `--token-limit`, `--time-limit`, `--working-limit`, `--cost-limit` (needs `--model-cost-config`). `--timeout`, `--attempt-timeout`, `--max-retries` apply per generate call.

## Eval sets

```bash
inspect eval-set task_a.py task_b.py \
  --model vllm/<a>,vllm/<b> --epochs 3 --log-dir logs/cmp-1
```

The log directory is the scope of the set, so give each set its own. Re-running the same command resumes unfinished work; adding models, tasks or epochs and re-running amends the set. Retry options: `--retry-attempts` (default 10), `--retry-immediate` (default), `--retry-wait`, `--retry-connections`, `--no-retry-cleanup`. Long sets can run detached with `--detach` and be watched with `inspect ctl`.

## Logs

```bash
inspect view --log-dir logs --port 7575      # viewer at 127.0.0.1:7575; `--no-trust-content` for untrusted output
inspect log list --json --status error --log-dir logs
inspect log dump logs/<run>.eval | jq '.results.scores[].metrics'
inspect log convert logs --to eval --output-dir logs-eval
inspect log export-config logs/<run>.eval > run.yaml
```

- Format: `.eval` (binary, default since 0.3.46, about one eighth the size of `.json`) or `.json`. Read through the API or `inspect log dump`, never by parsing files directly.
- `--log-dir`/`INSPECT_LOG_DIR` default `./logs`. S3, Azure and Hugging Face bucket locations are supported; ask before writing logs off-machine because logs contain prompts, outputs and, with `--traceback-locals`, local variables.
- `--no-log-samples`, `--no-log-images` shrink logs; use only when you do not need transcripts.
- Python: `read_eval_log(path, header_only=True)`, `list_eval_logs()`, `evals_df()` for dataframes.

## Caching

`--cache` (7 days) or `--cache 1D|4W` serves identical requests from a local cache keyed on model name and base URL, prompt, epoch, generation config and tools. It is off by default. Do not use it on decision runs, and pin versioned model names so a model update invalidates it. `inspect cache list|prune|clear [--model ...]` manages it.

## Sandboxes

`bash()`, `python()`, text-editor and computer tools need a sandbox (`--sandbox docker` or `docker:compose.yml`; Kubernetes, Modal, Proxmox, Vagrant via extensions). Sandboxes isolate model-generated commands from the host. Requirements and rules:

- Ask before building images or starting containers; `--sandbox-prebuilt` skips builds and fails at startup if an image is missing; `--no-sandbox-cleanup` keeps containers for debugging (remove them afterwards).
- Without a sandbox, do not give a model shell or Python tools on the host.
- Sample `files` and `setup` scripts run inside the sandbox; `setup` has a 5 minute timeout.

Official sources: https://inspect.aisi.org.uk/eval-sets.html, https://inspect.aisi.org.uk/eval-logs.html, https://inspect.aisi.org.uk/handling-errors.html, https://inspect.aisi.org.uk/models-concurrency.html, https://inspect.aisi.org.uk/sandboxing.html
