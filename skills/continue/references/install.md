# Continue: install, files and versions

> Verified against Continue v2.1.0-vscode and the cn CLI README, 2026-10-11

## What it is and when to choose it

Open-source coding assistant for VS Code and JetBrains, plus the `cn` CLI agent. Choose it when you want chat, edit, apply and autocomplete on different models, or need an editor client that works with LAN and local endpoints.

## Install

- VS Code: extension `Continue.continue` (publisher Continue, from `extensions/vscode/package.json`). `code --install-extension Continue.continue`.
- JetBrains: plugin from the JetBrains Marketplace (release tags `*-jetbrains`).
- CLI `cn` (Node 20+ for npm):

```bash
npm i -g @continuedev/cli
# or: curl -fsSL https://raw.githubusercontent.com/continuedev/continue/main/extensions/cli/scripts/install.sh | bash
cn            # interactive; cn -p "prompt" for headless
```

Check installed and newest:

```bash
code --list-extensions --show-versions | grep -i continue.continue
gh api repos/continuedev/continue/releases --jq '[.[]|select(.tag_name|test("vscode"))][0]|.tag_name+" "+.published_at'
```

At write time the newest VS Code release tag is `v2.1.0-vscode` (2026-06-19); the repository still receives commits.

## Minimal working config

`~/.continue/config.yaml`, see `config-endpoints.md` and `assets/config.yaml`. `schema: v1` is required; `config.json` is deprecated (a migration guide exists on docs.continue.dev).

## How it plugs into the stack

Requests go from the editor (or CLI) straight to your `apiBase`. No vendor cloud is in the path for custom providers.

## Operating

- Data lives in `~/.continue` (`%USERPROFILE%\.continue` on Windows). Reset by removing it, uninstalling and reinstalling.
- Secrets: `~/.continue/.env`; see `config-endpoints.md`.
- Proxies: VS Code uses its own Proxy Support setting; custom CA via `requestOptions.caBundlePath`.

## Tuning knobs

`defaultCompletionOptions` (context, output, temperature, reasoning), `autocompleteOptions`, `requestOptions` (timeout, headers). All in `config-endpoints.md`.

## Known pitfalls

- Sidebar missing after install: Continue may be on the right sidebar; Cmd/Ctrl+L reveals it.
- Config edits not visible: reload the window.
- Codebase indexing disabled on x64 Linux CPUs without AVX2/FMA; chat and autocomplete still work.

## Official links

- Docs: https://docs.continue.dev
- Releases: https://github.com/continuedev/continue/releases
- CLI README: https://github.com/continuedev/continue/blob/main/extensions/cli/README.md
