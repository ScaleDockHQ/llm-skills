# Aider: install, upgrade, config locations

> Verified against Aider v0.86.0 (docs: install, config/options, config/dotenv, config/aider_conf; PyPI and GitHub release feed), 2026-10-11

Ask before installing or changing config. Aider is `Aider-AI/aider` (PyPI package `aider-chat`). Its last release at write time was v0.86.0 and the repository was still receiving pushes (last in May 2026) and not archived, so check the release feed before assuming activity.

## Install

| Method                | Command                                                               |
| --------------------- | --------------------------------------------------------------------- |
| Recommended installer | `python -m pip install aider-install` then `aider-install`            |
| Docker                | Official image `paulgauthier/aider` (see the docker page of the docs) |

`aider-install` creates an isolated environment for aider. Aider's Python requirements are strict about the interpreter version, which the installer handles; a plain `pip install aider-chat` into a shared environment is a common source of dependency conflicts. The docs also have pages for Codespaces and Replit.

## Upgrade, pin, rollback

- `aider --upgrade` upgrades to the latest release; `--install-main-branch` installs the development branch (avoid in production).
- Update checks run at startup (`--check-update`; `--no-check-update` to stop; `--just-check-update` to check and exit).
- Record `aider --version` before upgrading. To roll back, reinstall the older version with the same installer tooling you used originally (for a `uv tool` or `pipx` install, pin `aider-chat==<version>`); the release list is `gh api repos/Aider-AI/aider/releases --jq '.[0:5][].tag_name'` or PyPI.
- After upgrading rerun `scripts/check-endpoint.sh` and one real edit; model settings defaults ship with each release.

## Files and precedence

| File                         | Locations (loaded in this order, later wins)                    |
| ---------------------------- | --------------------------------------------------------------- |
| `.aider.conf.yml`            | home, git repo root, current directory (`--config <file>`)      |
| `.env`                       | home, git repo root, current directory, then `--env-file`       |
| `.aider.model.settings.yml`  | home, git repo root, current directory, `--model-settings-file` |
| `.aider.model.metadata.json` | home, git repo root, current directory, `--model-metadata-file` |

Command-line flags override environment variables, which mirror every flag as `AIDER_<OPTION>`. Other files aider writes: `.aider.chat.history.md`, `.aider.input.history` and `.aider.tags.cache.*` in the working directory; keep them out of git (aider offers to add them to `.gitignore`).

## Privacy and offline use

`--analytics-disable` / `--no-analytics`, `--no-check-update`, and an explicit `--model` stop update checks, analytics prompts and the OpenRouter onboarding offer. All model traffic goes to your `OPENAI_API_BASE` (or provider base variable). URLs mentioned in chat can be fetched (`--no-detect-urls` turns it off).
