# Lighteval: updating

> Verified against lighteval 0.13.0 (PyPI, GitHub releases) and main 0.13.1.dev0, 2026-10-11

Releases are infrequent (v0.13.0 on 2025-11-24) while `main` moves daily. Docs and `--help` text on the website follow `main`, so check them against the installed version.

## Check what is current

```bash
curl -fsS https://pypi.org/pypi/lighteval/json | jq -r '.info.version, .info.requires_python'
gh release list --repo huggingface/lighteval --limit 5
pip show lighteval | sed -n 1,2p
```

## Upgrade procedure

1. Read the release notes (https://github.com/huggingface/lighteval/releases) for task changes: prompt, metric or split changes alter scores.
2. Check the pins that matter to you: `inspect-ai`, `vllm` extra range, `transformers`, Python.
3. Bump the pin in one place (requirements or lockfile) and commit it.
4. Smoke run with `--max-samples 5`, then re-run the baseline with the old and the new version and diff per task (`templates/compare-results.sh`).
5. If you use `lighteval eval`, also re-check the `inspect-ai` skill's updating checklist: the Inspect version underneath affects logs and scorers.

## Things that change under you

- Preferred entry point moved to `lighteval eval` (Inspect) while other backends remain.
- Task string format (`suite|task|fewshot` versus bare names).
- vLLM extra range (0.13.0: `<0.10.2`; main: `>=0.11.0`).
- Defaults of `eval` (timeout, connections, caching) and reasoning-tag removal.

Official sources: https://github.com/huggingface/lighteval/releases, https://pypi.org/project/lighteval/
