# Updating SWE-bench

> Verified against swebench 5.0.2 (PyPI release history) and upstream docs on main, 2026-10-11

## Check versions (read-only)

```bash
pip show swebench | head -2
curl -fsS https://pypi.org/pypi/swebench/json | jq -r '.info.version'
gh api repos/SWE-bench/SWE-bench/releases --jq '.[0].tag_name'    # GitHub releases/tags can lag PyPI
```

At writing: PyPI 5.0.2 (2026-08-18), git tags up to v5.0.1, `main` ahead with unreleased commands.

## Upgrade procedure

1. Record the old version, the dataset aliases you rely on and one gold run's `results.json`.
2. New venv: `pip install "swebench==<new>"`.
3. `swebench --help` and `swebench eval --help`: compare flags with your scripts.
4. Re-run the gold check on one instance with a fresh `run_id`.
5. Re-run a small fixed prediction set and compare resolved counts to the old version. Differences mean grader or image changes: pin and report both.

## Version drift rules

- v4 to v5 moved to the `swebench` command and task-repo image builds; the old `python -m swebench.harness.run_evaluation` form still works.
- Image sets and datasets can change under the same alias. Keep the dataset commit or HuggingFace revision with scores.
- Upstream docs mix old and new forms (module invocation, Python 3.9, `princeton-nlp/` ids); trust `--help` and the wheel.
- Re-grade existing logs after a parser fix without containers: `swebench report <run_id>`.
