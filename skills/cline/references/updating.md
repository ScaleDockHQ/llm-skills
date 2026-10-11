# Cline: updating

> Verified against Cline v4.1.23 (extension) and CLI v3.0.70, docs.cline.bot CLI reference, 2026-10-11

## What it is and when to choose it

Cline ships on several release lines from one repository: the VS Code extension (`vX.Y.Z`), the CLI (`cli-vX.Y.Z`), the desktop app (`desktop-v...`) and SDK packages (`sdk/...`). Read this before updating or comparing versions.

## Install

```bash
gh api repos/cline/cline/releases --jq '.[0:12][]|.tag_name+" "+.published_at'
code --list-extensions --show-versions | grep -i claude-dev
cline version
```

Update: the Extensions panel (or `code --install-extension saoudrizwan.claude-dev --force`); `cline update` (or `cline --update`) for the CLI.

## Minimal working config

After an update, open Settings and confirm provider, Base URL, Model ID, Context Window and Max Output are unchanged; run one file-edit task per endpoint.

## How it plugs into the stack

Only the client changes. The gateway and key stay as they are.

## Operating

- Back up before CLI changes: `cp -R ~/.cline/data/settings ~/.cline/data/settings.bak` (the copy contains keys; keep it `0700` and delete it afterwards).
- `cline doctor` diagnoses configuration issues; `cline hub upgrade` drains and restarts the local hub.
- Settings are shared across IDE, CLI and SDK through `~/.cline`, so a migration affects all of them.

## Tuning knobs

None specific to updating.

## Known pitfalls

- Version numbers on different lines are unrelated; compare within a prefix.
- Docs are moving quickly (SDK, desktop, Kanban); a field name here may change. Re-read docs.cline.bot.
- Roo Code (a Cline fork) is archived and Kilo Code is a separate project; neither updates with Cline.

## Official links

- Releases: https://github.com/cline/cline/releases
- CLI reference: https://docs.cline.bot/cli/cli-reference
- Deprecations: https://docs.cline.bot/resources/deprecations
