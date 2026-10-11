# Chatterbox: updating

> Verified against resemble-ai/chatterbox master, PyPI chatterbox-tts 0.1.7 and GitHub tags, 2026-10-11

State on 2026-10-11: PyPI latest `0.1.7` (2026-03-26); GitHub tags stop at `v0.1.2`; `master` last commit 2026-07-21 (Nano). `pyproject.toml` on master still says 0.1.7, so a source checkout and the wheel share a version number but not content. Record the commit hash, not the version.

```bash
pip show chatterbox-tts | grep -i '^version'
curl -s https://pypi.org/pypi/chatterbox-tts/json | jq -r .info.version
git -C ~/src/chatterbox log -1 --format='%h %cd %s' --date=short
git -C ~/src/chatterbox fetch -q && git -C ~/src/chatterbox log HEAD..origin/master --oneline
```

## Upgrade

1. Note the current commit and `pip freeze > before.txt` (see `templates/requirements-lock.txt.example`).
2. In a copy of the environment: `git pull && pip install -e .`.
3. Read the diff of `pyproject.toml` (pins move) and the README model table.
4. Run the verify snippet from `install.md` for each model you use; listen to a fixed test sentence and compare.
5. Switch over; keep the old venv until a day of real use passes.

Weights come from Hub repos that can change independently of the code; pin by setting `HF_HOME` to a cache you snapshot, or by downloading a specific `revision` with `huggingface_hub` and loading via `from_local`.

## Rollback

Reinstall the commit from `before.txt` and restore the old cache.
