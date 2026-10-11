# lm-evaluation-harness: updating

> Verified against lm-evaluation-harness v0.4.13 (PyPI, GitHub releases, README news), 2026-10-11

Releases are infrequent (v0.4.12 then v0.4.13 on 2026-08-31; the default branch is already `0.4.14.dev0`, and PyPI lists `0.5.0.dev1`). Task definitions, answer filters and chat-template handling change between releases, so a score from one version is not guaranteed comparable with another.

## Check what is current

```bash
curl -fsS https://pypi.org/pypi/lm_eval/json | jq -r '.info.version, .info.requires_python'
gh release list --repo EleutherAI/lm-evaluation-harness --limit 5
pip show lm_eval | head -3
```

## Upgrade procedure

1. Read the release notes between versions: https://github.com/EleutherAI/lm-evaluation-harness/releases. Watch for changed task names, versions, filters and CLI behaviour.
2. Create a **new** venv with the new pinned version; keep the old one until the baseline is re-run.
3. `lm-eval validate --tasks <your tasks>` and a `--limit 20 --log_samples` smoke run; read the samples.
4. Re-run the baseline model on the new version with identical flags; do not reuse baseline numbers produced on an older version.
5. Diff metrics; investigate any move larger than twice the stderr before attributing it to the model.
6. Update pinned versions in your scripts and the "Verified against" lines in your notes.

## Changes seen recently (upstream README and docs)

- 2025-12: base package no longer includes `transformers` and `torch`; install `lm_eval[hf]`, `[vllm]`, `[api]` as needed.
- 2025-07: `think_end_token` added for `hf`, `vllm` and `sglang`; docs list OpenAI-compatible chat backends, including `local-chat-completions`, as accepting a string `think_end_token`.
- The CLI is organized as `lm-eval run`, `ls`, `validate`; the legacy single-command form still works.
- When a score moves, read the task's README and YAML diff between the two tags before blaming the model.

Official sources: https://github.com/EleutherAI/lm-evaluation-harness/releases, https://pypi.org/project/lm-eval/
