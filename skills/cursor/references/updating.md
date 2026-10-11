# Cursor: updating and re-verifying the override

> Verified against Cursor 3.23 docs release notes, 2026-10-11

## What it is and when to choose it

Cursor updates itself often (docs release notes list numbered releases such as 3.23). The base-URL override is not covered on the official help page, so re-check it after updates instead of assuming it still works.

## Install

```bash
curl -fsS https://cursor.com/docs/release-notes.md | sed -n 1,40p      # what changed recently
defaults read /Applications/Cursor.app/Contents/Info CFBundleShortVersionString   # macOS: what you run
```

## Minimal working config

After every update, spend two minutes:

- [ ] Settings > Models: override still enabled, URL and model name unchanged.
- [ ] `scripts/probe.sh https://llm.example.com/v1 coder` still shows models, chat, stream and `tool_calls>0`.
- [ ] A one-line agent task ("create hello.txt") reaches your gateway log with the expected model name.

## How it plugs into the stack

Only the app changes. Endpoint, gateway and key stay as they are, so a regression is almost always in Cursor's routing or settings UI.

## Operating

- Pin nothing on the Cursor side; there is no documented way to hold a version for individual users. Enterprise admins manage rollout through their own channels (see the Enterprise docs).
- Search release notes for "model", "API key", "Base URL", "BYOK" before updating a team.

## Tuning knobs

None.

## Known pitfalls

- Settings fields renamed or moved: the override may appear under a different heading. Search Settings for "Base URL".
- New built-in model names can collide with your alias; rename the alias.
- A new Cursor build may change which model families use which key field (OpenAI, Anthropic, Google); re-test Claude-named aliases.

## Official links

- Release notes: https://cursor.com/docs/release-notes.md
- Changelog: https://cursor.com/changelog.md
