# Claude Code: install, update, diagnose

> Verified against Claude Code v2.1.296 (docs: setup, settings, llm-gateway-connect), 2026-10-11

Ask before installing or changing settings; every command below is the official one.

## Install

| Platform / method          | Command                                                            | Auto-updates                                             |
| -------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------- |
| macOS, Linux, WSL (native) | `curl -fsSL https://claude.ai/install.sh \| bash`                  | Yes                                                      |
| Homebrew                   | `brew install --cask claude-code` (stable) or `claude-code@latest` | No: `brew upgrade claude-code` (or `claude-code@latest`) |
| WinGet                     | `winget install Anthropic.ClaudeCode`                              | No: `winget upgrade Anthropic.ClaudeCode`                |

The native installer keeps the launcher at `~/.local/bin/claude`, a symlink into `~/.local/share/claude/versions/`. Replacing it with your own script stops auto-update; remove it and run `claude update` to restore. Check the script before piping to a shell if the host policy requires it. An npm package exists (`@anthropic-ai/claude-code`); prefer the native installer unless the host standardizes on npm, and see upstream docs for its permission caveats.

## First run with a custom endpoint

With `ANTHROPIC_BASE_URL` and a credential set (see `custom-endpoints.md`), `claude` should start without the login screen. If it shows login, the credential was not read before first-run setup: use a shell export or `~/.claude/settings.json`, not a project settings file.

Onboarding dialogs, update checks and release notes call out to Anthropic. On a locked-down host set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` (also disables auto-update).

## Update and pin

- `claude update` updates the native install; `claude doctor` reports the last update attempt, install health and settings errors (read-only, no session).
- `autoUpdatesChannel`: `"latest"` or `"stable"` in settings (Homebrew picks by cask name). `minimumVersion` is a floor for updates, set automatically if you decline a downgrade when switching to stable.
- `DISABLE_AUTOUPDATER=1` in the `env` block turns auto-update off. Managed settings `requiredMinimumVersion` and `requiredMaximumVersion` make Claude Code refuse to start outside a range.
- Record the working version before upgrading (`claude --version`). Gateway-facing behavior changes between releases (new beta headers, tool types, thinking fields), so after each upgrade rerun `scripts/check-endpoint.sh` and one real edit, and read the release notes for gateway-related fixes. Rolling back: reinstall the previous version per upstream docs, or pin with the settings above.

## Settings files

| File                          | Scope                                | Credentials?                                 |
| ----------------------------- | ------------------------------------ | -------------------------------------------- |
| `~/.claude/settings.json`     | All your projects, background agents | Yes, but prefer `apiKeyHelper` or `0600` env |
| `.claude/settings.json`       | One project, committed               | Never                                        |
| `.claude/settings.local.json` | One project, personal, gitignore it  | If ignored                                   |
| Managed settings              | Organization, highest precedence     | Distributed by admin                         |

Precedence, highest first: managed, command line, project local, project shared, user. `env` in settings sets variables for the session. Edit with a backup: `cp ~/.claude/settings.json ~/.claude/settings.json.bak`. Validate JSON with `jq . ~/.claude/settings.json >/dev/null`; `claude doctor` also validates.

## Agent SDK and CI

The SDKs read the same variables. TypeScript `options.env` replaces the environment, so spread `process.env` into it; Python `ClaudeAgentOptions(env=...)` merges. In GitHub Actions put the endpoint and credential in repository secrets and variables, never in the workflow file.
