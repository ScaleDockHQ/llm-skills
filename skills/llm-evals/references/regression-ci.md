# Regression evals in CI

> Verified against promptfoo 0.124.1 docs (CI/CD, GitHub Action, CLI exit codes), 2026-10-11

Run a fast eval on every change that can affect model behaviour (prompts, system prompts, tool schemas, model IDs, gateway routing), and a full eval on a schedule or before release.

## Two tiers

| Tier | Trigger | Set | Budget |
| --- | --- | --- | --- |
| PR gate | `pull_request` touching prompts, eval config, model config | 20–100 deterministic items, `critical` first | Minutes |
| Full | nightly `schedule`, release tag, or manual | Full golden set, judges allowed | As needed |

Keep the PR gate deterministic (`contains`, `regex`, `is-json`, tool-call checks). Model-graded assertions add cost and variance; reserve them for the full tier unless the judge is calibrated (`llm-as-judge.md`).

## GitHub Actions workflow

```yaml
# .github/workflows/llm-evals.yml
name: LLM evals
on:
  pull_request:
    paths:
      - 'prompts/**'
      - 'evals/**'
      - 'promptfooconfig.yaml'
  schedule:
    - cron: '0 3 * * *'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  eval:
    runs-on: ubuntu-latest          # or a self-hosted runner that can reach a private endpoint
    timeout-minutes: 30
    env:
      PROMPTFOO_DISABLE_TELEMETRY: '1'
      PROMPTFOO_CACHE_PATH: ~/.cache/promptfoo
      # Allow a small number of known failures on the full tier; 100 = no failures allowed
      PROMPTFOO_PASS_RATE_THRESHOLD: ${{ github.event_name == 'pull_request' && '100' || '95' }}
      BASELINE_BASE_URL: ${{ vars.BASELINE_BASE_URL }}
      CANDIDATE_BASE_URL: ${{ vars.CANDIDATE_BASE_URL }}
      BASELINE_API_KEY: ${{ secrets.BASELINE_API_KEY }}
      CANDIDATE_API_KEY: ${{ secrets.CANDIDATE_API_KEY }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
      - name: Cache promptfoo responses
        uses: actions/cache@v4
        with:
          path: ~/.cache/promptfoo
          key: ${{ runner.os }}-promptfoo-${{ hashFiles('prompts/**', 'evals/**', 'promptfooconfig.yaml') }}
      - name: Check endpoints are reachable (no secrets printed)
        run: |
          for u in "$BASELINE_BASE_URL" "$CANDIDATE_BASE_URL"; do
            curl -fsS -o /dev/null -w "%{http_code} models\n" "$u/models" -H "Authorization: Bearer ${BASELINE_API_KEY:-none}" || exit 1
          done
      - name: Run PR subset
        if: github.event_name == 'pull_request'
        run: |
          npx promptfoo@0.124.1 eval -c promptfooconfig.yaml \
            --filter-metadata critical=yes \
            --no-share --no-progress-bar \
            -o results.json -o results.junit.xml -o report.html
      - name: Run full set
        if: github.event_name != 'pull_request'
        run: |
          npx promptfoo@0.124.1 eval -c promptfooconfig.yaml --no-cache \
            --no-share --no-progress-bar \
            -o results.json -o results.junit.xml -o report.html
      - name: Summarize
        if: always()
        run: |
          test -f results.json || exit 0
          jq -r '"passes: \(.results.stats.successes)  failures: \(.results.stats.failures)"' results.json >> "$GITHUB_STEP_SUMMARY"
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: llm-eval-results
          path: |
            results.json
            results.junit.xml
            report.html
          retention-days: 14
```

How it fails the build: `promptfoo eval` exits `100` when any test fails or the pass rate is below `PROMPTFOO_PASS_RATE_THRESHOLD`, and `1` on other errors. No extra gate step is needed. The `Check endpoints` step reuses one key for both URLs for brevity; split it if the keys differ.

The PR subset uses the cache keyed on the eval files, so unchanged prompts do not re-query the model. The full run uses `--no-cache` so it measures the endpoint as it is today.

## Alternative: the promptfoo GitHub Action

`promptfoo/promptfoo-action@v1` runs a before/after comparison of changed prompt files and comments on the PR. Inputs: `github-token` (required), `prompts` (glob, required), `config` (required), `openai-api-key`, `cache-path`. It needs `pull-requests: write`. Use it when you want PR comments; use the plain `npx` workflow above when you want explicit control and no hosted share links.

## Private endpoints and data

- **Self-hosted runner:** if the endpoint is only reachable on a private network (for example `http://10.0.0.1:4000/v1` behind LiteLLM), run the job on a self-hosted runner on that network. Do not expose an inference endpoint to the internet just for CI.
- **Secrets:** API keys in `secrets.*`; base URLs in `vars.*`. Never echo them; GitHub masks secrets but not values derived from them.
- **Fork PRs** do not receive secrets; the eval job will fail closed. Do not switch to `pull_request_target` to work around this unless you understand the code-execution risk.
- **Sensitive eval data:** keep `--no-share`, short artifact retention, and private repos. Results contain full model outputs.

## Keeping CI useful

- Mark known, accepted failures in test metadata and exclude them from the PR tier rather than lowering the threshold globally.
- When CI catches a real regression, add the triggering input to the golden set.
- Pin the promptfoo version; upgrade it deliberately, re-running baseline to check nothing moved.
- Re-run the full tier after any model, quant, engine or gateway change (see `quality-gates.md`).

## Official links

- promptfoo CI/CD guide: https://www.promptfoo.dev/docs/integrations/ci-cd/
- promptfoo GitHub Action guide: https://www.promptfoo.dev/docs/integrations/github-action/
- promptfoo-action repository: https://github.com/promptfoo/promptfoo-action
- CLI exit codes and env vars: https://www.promptfoo.dev/docs/usage/command-line/
- GitHub Actions secrets: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions
