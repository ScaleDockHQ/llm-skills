# Cursor: install, versions and settings locations

> Verified against Cursor 3.23 (docs release notes) and cursor.com/docs/llms.txt, 2026-10-11

## What it is and when to choose it

Cursor is a VS Code-based editor with its own models, an agent, Tab completion, a CLI and cloud agents. Use it with a self-hosted model only through the BYOK override described in `custom-endpoint.md`.

## Install

Download the desktop app from https://cursor.com (macOS, Linux, Windows). Check what is installed:

```bash
defaults read /Applications/Cursor.app/Contents/Info CFBundleShortVersionString   # macOS
cursor --version                                                                 # if the shell command is installed
curl -fsS https://cursor.com/docs/release-notes.md | sed -n 1,6p                  # newest documented release
```

The Cursor CLI (docs under https://cursor.com/docs/cli/overview.md) is a separate agent; its configuration and whether it honours the editor's base-URL override are not documented on the pages read for this skill, so do not assume it does.

## Minimal working config

Settings > Models. Provider key fields documented by Cursor: OpenAI, Anthropic, Google, Azure OpenAI, AWS Bedrock. The "Override OpenAI Base URL" checkbox and field are visible in the same panel (staff and third-party guides; not on the help page).

## How it plugs into the stack

Cursor app to Cursor servers to your public endpoint. See `custom-endpoint.md` for data flow and the endpoint requirements.

## Operating

- Docs and release notes are served as markdown: append `.md` to any `https://cursor.com/docs/...` URL; the index is `https://cursor.com/docs/llms.txt`.
- Team admin features (model access, network configuration, privacy mode) live under the Enterprise docs: `https://cursor.com/docs/enterprise/network-configuration.md`, `.../privacy-and-data-governance.md`, `.../model-and-integration-management.md`.

## Tuning knobs

Cursor has no per-model context, output or capability settings for custom models. Control behaviour at the endpoint: gateway max tokens, engine context size, tool parser.

## Known pitfalls

- Settings labels move between releases. If the override field is missing, update Cursor and search Settings for "Base URL".
- Enterprise or Teams policy can hide or lock model settings; ask the admin.

## Official links

- Docs index: https://cursor.com/docs/llms.txt
- Release notes: https://cursor.com/docs/release-notes.md
- Bring your own API key: https://cursor.com/help/models-and-usage/api-keys
