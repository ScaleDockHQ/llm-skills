# Continue: updating and migrating config

> Verified against Continue v2.1.0-vscode, 2026-10-11

## What it is and when to choose it

Continue ships as an IDE extension (auto-updated by the marketplace), a JetBrains plugin and the `cn` npm package. Read this before moving from `config.json` or after a major version.

## Install

```bash
gh api repos/continuedev/continue/releases --jq '[.[]|select(.tag_name|test("vscode"))][:3][]|.tag_name+" "+.published_at'
code --list-extensions --show-versions | grep -i continue.continue
npm ls -g @continuedev/cli 2>/dev/null | grep cli
```

Update: `code --install-extension Continue.continue --force`, or the editor's Extensions panel; `npm i -g @continuedev/cli@latest` for `cn`.

## Minimal working config

After an update, check `~/.continue/config.yaml` still starts with `name`, `version` and `schema: v1`. `config.json` is deprecated; the docs host a migration guide.

## How it plugs into the stack

Only the client changes; endpoints and keys stay. Capability autodetection improves between versions ("Keep Continue updated", docs), so an old `tool_use` override may become unnecessary but is harmless.

## Operating

- Back up before editing: `cp ~/.continue/config.yaml ~/.continue/config.yaml.bak`.
- After updating: reload the window, check each model in the picker, run one Agent-mode file edit per endpoint.
- The extension stores state under `~/.continue`; do not delete it unless you want a full reset.

## Tuning knobs

None specific to updates.

## Known pitfalls

- Release tags are per product (`*-vscode`, `*-jetbrains`); do not compare numbers across them.
- Newer builds may start sending other APIs for model names that look like OpenAI reasoning models; keep aliases neutral or set `useResponsesApi: false`.

## Official links

- Releases: https://github.com/continuedev/continue/releases
- config.yaml reference: https://docs.continue.dev/reference
