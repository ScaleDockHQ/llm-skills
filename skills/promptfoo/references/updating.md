# promptfoo: updating

> Verified against promptfoo 0.124.1 (npm registry, GitHub releases), 2026-10-11

promptfoo releases often (0.124.0 on 2026-10-06, 0.124.1 on 2026-10-08; roughly one to three minor or patch versions a month in recent releases). It is pre-1.0, so minor versions can change defaults, output fields and assertion behaviour. Treat every bump as a change to the measurement instrument.

## Check what is current

```bash
npm view promptfoo version engines 2>/dev/null || curl -fsS https://registry.npmjs.org/promptfoo/latest | jq '{version, engines}'
gh release list --repo promptfoo/promptfoo --limit 5   # the repo also publishes code-scan-action-* tags; ignore them
```

## Upgrade procedure

1. Read the release notes between your pinned version and the target: https://github.com/promptfoo/promptfoo/releases.
2. Check `engines.node`; promptfoo 0.124.1 needs `>=22.22.0`.
3. Bump the pin in one place: the `npx promptfoo@X.Y.Z` strings in workflows and scripts, or the dev dependency (`npm install --save-dev promptfoo@X.Y.Z`, commit the lockfile).
4. `npx promptfoo@X.Y.Z validate -c promptfooconfig.yaml`.
5. Re-run the baseline with `--no-cache` on the old and the new version and diff per item. A change inside baseline-versus-baseline noise is not a regression.
6. Re-check anything that reads output fields (`jq` over `results.json` or JSONL): `.results.stats.successes`, `.results.stats.failures`, `testIdx`, `success`.
7. Update the `Verified against` lines in your own notes and templates, and the version in CI.

## Things that change under you

- Default grader provider selection and default model names (the `llm-rubric` doc lists `gpt-5` for an OpenAI key today).
- Provider defaults (temperature, output limits; `omitDefaults`).
- Action runtime (promptfoo-action v1.3.4 declares `node24`).
- Documented-but-missing flags: `--fail-on-error` is in the CI/CD guide but not in the `eval` option table (0.124.1). Re-check before use.

Official sources: https://github.com/promptfoo/promptfoo/releases, https://www.npmjs.com/package/promptfoo
