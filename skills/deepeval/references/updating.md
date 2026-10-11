# DeepEval: updating

> Verified against deepeval 4.2.8 (PyPI, GitHub releases), 2026-10-11

DeepEval ships often (4.2.8 on 2026-10-02) and has changed metric APIs and defaults between majors. Treat every bump as a change to the measurement instrument.

## Check what is current

```bash
curl -fsS https://pypi.org/pypi/deepeval/json | jq -r '.info.version, .info.requires_python'
gh release list --repo confident-ai/deepeval --limit 5
pip show deepeval | sed -n 1,2p
```

## Upgrade procedure

1. Read the release notes (https://github.com/confident-ai/deepeval/releases); PyPI versions can be newer than the latest GitHub release tag, so also check the commit history for the tag.
2. Bump the pin in one place and commit the lockfile.
3. `deepeval diagnose` and `deepeval settings -l` to confirm the judge and storage settings survived.
4. Re-run the baseline suite with the old and new version using the same judge, `temperature=0`, no cache; diff pass/fail and scores per case. A change inside baseline-versus-baseline noise is not a regression.
5. Re-check anything that reads `.deepeval` run files or `deepeval.db`.

## Things that change under you

- Parameter enums (`SingleTurnParams` in current docs; older code may use `LLMTestCaseParams`).
- Judge provider defaults, thinking behaviour (`DEEPEVAL_MODEL_THINKING`), eval modes (`DEEPEVAL_EVAL_MODE`, `DEEPEVAL_MODE=experimental` opt-ins).
- Telemetry and Confident AI behaviour (upload on `CONFIDENT_API_KEY`).
- Local storage format (`json` versus `sqlite`).

Official sources: https://github.com/confident-ai/deepeval/releases, https://pypi.org/project/deepeval/
