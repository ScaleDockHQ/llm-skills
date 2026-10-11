# Codex CLI: install, update, state

> Verified against Codex CLI rust-v0.162.1 (repo README, docs: config-advanced; release feed), 2026-10-11

Ask before installing or changing config. Commands below are from the upstream README.

## Install

| Method                  | Command                                                                                    |
| ----------------------- | ------------------------------------------------------------------------------------------ |
| macOS, Linux standalone | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh`                                    |
| Windows standalone      | `powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 \| iex"` |
| npm                     | `npm install -g @openai/codex`                                                             |
| Homebrew                | `brew install --cask codex`                                                                |

The standalone installers download from `https://releases.openai.com/codex` and fall back to GitHub Releases; set `CODEX_INSTALLER_USE_RELEASES_OPENAI_COM=false` to force GitHub. Download the script and read it first if the host policy requires review. Then run `codex`; if it prompts for sign-in, a custom `model_provider` is not active for that run (check the profile name and discovery output).

## Versions and updating

- Release tags look like `rust-v0.162.1`; list them with `gh api repos/openai/codex/releases --jq '.[].tag_name' | head` or the releases page. `codex --version` shows the installed one.
- Update with the method used to install (rerun the installer, `npm install -g @openai/codex@latest`, `brew upgrade --cask codex`). Record the old version first so you can reinstall it (`npm install -g @openai/codex@<version>`) if a release breaks your provider.
- After every upgrade rerun `scripts/check-endpoint.sh` and a one-file edit through the profile. Provider behavior with non-OpenAI backends has changed between releases (history items, tool wrapping); see `compatibility.md`.

## State and config locations

`CODEX_HOME` (default `~/.codex`) holds:

| Path                           | Content                                                               |
| ------------------------------ | --------------------------------------------------------------------- |
| `config.toml`                  | User configuration, including providers.                              |
| `<name>.config.toml`           | Profile overlay used with `--profile <name>`.                         |
| `history.jsonl`, session files | Local transcripts (may contain prompts and code; treat as sensitive). |
| `hooks.json`, rules            | Hooks and execution policy.                                           |

Layering: user config, then profile, then project `.codex/config.toml` for trusted projects (closest file wins; provider and credential keys ignored there), then `-c key=value` on the command line. Disable local history persistence with `[history] persistence = "none"`, or cap the file with `[history] max_bytes = 104857600`, if prompts must not be stored.

## Check what Codex will use

```bash
codex --version
ls -l "${CODEX_HOME:-$HOME/.codex}/local.config.toml"
grep -c '^\[model_providers\.' "${CODEX_HOME:-$HOME/.codex}/config.toml"
```

Run a trivial `codex exec --profile local "say ok"` to verify end to end. The first request shows whether the provider, key and model name are right.
