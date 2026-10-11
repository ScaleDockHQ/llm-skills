# Inspect AI: updating

> Verified against inspect-ai 0.3.278 (PyPI, GitHub releases), 2026-10-11

inspect-ai is pre-1.0 and ships often (0.3.278 on 2026-10-09). Treat every bump as a change to the measurement instrument.

## Check what is current

```bash
pip index versions inspect-ai 2>/dev/null | head -2
curl -fsS https://pypi.org/pypi/inspect-ai/json | jq -r '.info.version, .info.requires_python'
gh release list --repo UKGovernmentBEIS/inspect_ai --limit 5
pip show inspect-ai | sed -n 1,2p
```

## Upgrade procedure

1. Read the release notes between the pinned and target version: https://github.com/UKGovernmentBEIS/inspect_ai/releases (also the CHANGELOG).
2. Check `requires_python` (>=3.10 at 0.3.278) and whether `inspect-evals` needs a matching bump.
3. Bump the pin in one place (requirements, `pyproject.toml`, CI) and commit the lockfile.
4. Smoke run: `inspect eval task.py --model <m> --limit 5`.
5. Re-run the baseline on old and new versions with the same model and seed; diff per sample (`templates/compare-logs.sh`). Differences inside baseline-versus-baseline noise are not regressions.
6. Re-check anything reading logs: use the log API (`read_eval_log`) rather than raw JSON; log schema is available from `inspect log schema`.

## Things that change under you

- Adaptive connections became default (v0.3.217); older scripts tuned with `--max-connections` behave differently.
- Provider model lists and reasoning options (`--reasoning-effort` values differ by model).
- Scorer behaviour, metric defaults and the model-grading template.
- Docs examples reference changing model names; use ids you verified on your own provider.

Official sources: https://github.com/UKGovernmentBEIS/inspect_ai/releases, https://pypi.org/project/inspect-ai/
