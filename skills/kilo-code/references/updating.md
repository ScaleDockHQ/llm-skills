# Updating Kilo Code

> Verified against Kilo Code v7.8.8 (releases page), 2026-10-11

## What it is and when to choose it

How to update the extension, plugin and CLI, and what to re-check afterwards.

## Install

See `install.md`.

## Minimal working config

Nothing changes in your config by updating; compare before and after with `kilo debug config`.

## Operating

- VS Code extension: updates through the editor's extension updates; pin with "Install Another Version" if needed.
- CLI: reinstall with the channel you used (`npm install -g @kilocode/cli@latest`, the install script, or `brew upgrade`).
- Release lines: `v7.x` for VS Code and CLI, `jetbrains/v7.x` for JetBrains. Read release notes for changes to provider setup, config keys and defaults.

```bash
gh api repos/Kilo-Org/kilocode/releases --jq '[.[]|select(.tag_name|test("^v[0-9]"))][0:3][]|.tag_name+" "+.published_at'
```

After an update: `kilo models`, one probe, one agent edit.

## Known pitfalls

- Defaults and the config schema move between minor versions; re-read the provider and custom-model pages before assuming a field still applies.
- The project is a fast-moving fork lineage (Roo Code and Cline ancestry); do not copy settings from Roo or Cline docs.

## Official links

- Releases: https://github.com/Kilo-Org/kilocode/releases
- Docs: https://kilo.ai/docs
