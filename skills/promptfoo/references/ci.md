# promptfoo: running evals in CI

> Verified against promptfoo 0.124.1 docs (ci-cd, github-action, command-line) and promptfoo-action v1.3.4 `action.yml`, 2026-10-11

Run a fast deterministic eval on every change that can affect model behaviour (prompts, tool schemas, model IDs, gateway routing, quantization), and a full eval on a schedule or before release. The file to start from is `templates/llm-evals.yml`.

## Two tiers

| Tier    | Trigger                                    | Set                                        | Cache        |
| ------- | ------------------------------------------ | ------------------------------------------ | ------------ |
| PR gate | `pull_request` on prompt/eval/config paths | 20-100 deterministic items, `critical=yes` | Allowed      |
| Full    | nightly `schedule`, release tag, or manual | Full golden set; calibrated judges allowed | `--no-cache` |

Keep the PR gate deterministic. Model-graded assertions add cost and variance; keep them for the full tier unless the judge is calibrated (strategy: `llm-evals`).

## How the build fails

`promptfoo eval` exits `100` when any test fails or the pass rate is below `PROMPTFOO_PASS_RATE_THRESHOLD`, and `1` on other errors; no extra gate step is needed. Set the threshold per tier with an env var (the template uses `100` on PRs and `95` on the nightly run). `PROMPTFOO_FAILED_TEST_EXIT_CODE` changes the code `100`.

The CI/CD guide also shows a manual gate that computes a pass rate from `results.json` with `jq` and `exit 1`; use it when you need a rule the threshold cannot express (for example "no regressions on critical items"):

```bash
jq '.results.stats' results.json   # documented fields: successes, failures
```

## Workflow essentials

- `permissions: contents: read`; `persist-credentials: false` on checkout.
- Node 24 LTS on the runner (promptfoo needs `>=22.22.0`).
- Pin the CLI: `npx promptfoo@0.124.1 ...` or a locked dev dependency with `npm ci`.
- `promptfoo validate -c promptfooconfig.yaml` first: it exits 1 on schema errors and costs nothing.
- `--no-share --no-progress-bar` and `-o results.json -o results.junit.xml -o report.html`; upload as artifacts with short retention.
- Cache directory `~/.cache/promptfoo` via `PROMPTFOO_CACHE_PATH`; key the cache on `hashFiles` of the prompts, evals and config. Optional `PROMPTFOO_CACHE_TTL` (seconds).
- Probe endpoints before spending time: pass the key through a curl config on stdin (`printf 'header = ...' | curl -K -`) so it never appears in argv.

## The promptfoo GitHub Action (PR comments)

`promptfoo/promptfoo-action@v1` runs a before/after comparison of changed prompt files and comments on the pull request. It needs `pull-requests: write`, the docs list Node `>=22.22.0` (24 recommended), and `action.yml` declares a `node24` runtime.

The docs table lists `github-token` (required), `prompts` (glob), `config` (required), `openai-api-key`, `cache-path`. The `action.yml` on the default branch also defines, among others: `promptfoo-version`, `working-directory`, `no-share`, `no-cache`, `no-table`, `no-progress-bar`, `max-concurrency`, `fail-on-threshold` (percent, 0-100), `env-files`, `disable-comment`, `repeat` (and `repeat-min-pass`), plus per-provider key inputs. These extra inputs are not in the docs page; confirm against the tag you pin.

```yaml
- uses: promptfoo/promptfoo-action@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    prompts: "prompts/**/*.json"
    config: promptfooconfig.yaml
    cache-path: ~/.cache/promptfoo
    promptfoo-version: "0.124.1"
    no-share: true
```

Use the action when you want PR comments with a before/after diff. Use the plain `npx` workflow when you need explicit control, JUnit output, or a private endpoint (the action's example keys are cloud-provider keys; for a self-hosted endpoint put `BASELINE_*`/`CANDIDATE_*` in the step `env`).

## Private endpoints and data

- **Self-hosted runner:** if the endpoint is only reachable on a private network (for example a LiteLLM gateway at `http://10.0.0.1:4000/v1`), run the job on a self-hosted runner on that network. Do not expose an inference endpoint to the internet just for CI.
- **Secrets:** keys in `secrets.*`, base URLs in `vars.*`. Never echo them; Actions masks secrets but not values derived from them.
- **Fork PRs** do not receive secrets; the job fails closed. Do not switch to `pull_request_target` to work around it without understanding the code-execution risk.
- **Sensitive eval data:** `--no-share`, short artifact retention, private repos, and consider `PROMPTFOO_STRIP_RESPONSE_OUTPUT=true` and `PROMPTFOO_STRIP_TEST_VARS=true` (the CI/CD guide's data-privacy advice) when artifacts must not hold prompts and outputs. Stripping also removes what you need to debug; weigh it.

## Keeping CI useful

- Mark accepted failures in test `metadata` and exclude them from the PR tier instead of lowering the threshold globally.
- When CI catches a real regression, add the input to the golden set.
- Upgrade promptfoo deliberately and re-run the baseline (`updating.md`).
- Rate limits and timeouts: lower `-j`, set `PROMPTFOO_EVAL_TIMEOUT_MS`, and give the job `timeout-minutes`.
- Quantization or engine changes: see `combos/quant-ci-gate.md`.

Official sources: https://www.promptfoo.dev/docs/integrations/ci-cd/, https://www.promptfoo.dev/docs/integrations/github-action/, https://github.com/promptfoo/promptfoo-action
