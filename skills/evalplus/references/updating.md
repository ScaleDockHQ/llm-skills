# EvalPlus: updating

> Verified against EvalPlus 0.3.1 (PyPI release history, GitHub README news, commits to 2025-10-02), 2026-10-11

## Check

```bash
pip index versions evalplus 2>/dev/null | head -1
gh release list --repo evalplus/evalplus --limit 5
gh api repos/evalplus/evalplus/commits --jq '.[0:5][]|[.commit.author.date,(.commit.message|split("\n")[0])]|@tsv'
```

Releases: v0.2.0 (2023-11, MBPP+ added), v0.2.1 (2024-04), v0.3.0 and v0.3.1 (both 2024-10-20; EvalPerf, one-command evaluate, more backends). Commits after v0.3.1 (Ollama, Gaudi, CI, 2025) are unreleased: installing them requires the git URL.

## Dataset versions matter

- MBPP+ v0.2.0 removed broken tasks (399 to 378); expect about +4 pp pass@1 versus v0.1.
- HumanEval+ had ground-truth and contract fixes across v0.1.x to v0.2.1. Scores from older package versions are not comparable.
- Record the package version (and Docker image digest) with every score; rerun baselines after any upgrade.

## Procedure

1. New venv, `pip install "evalplus==<new>"`.
2. Run the baseline model on the new and old versions with `--greedy` on a small `--id-range`, then fully.
3. If scores shift, read the release notes for dataset fixes before comparing old and new numbers.
4. Update the pinned version in scripts and CI, and the Docker image tag.
