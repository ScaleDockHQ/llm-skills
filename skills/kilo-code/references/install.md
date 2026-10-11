# Kilo Code: install, config locations and versions

> Verified against Kilo Code v7.8.8 (repository README, releases, kilo.ai docs index), 2026-10-11

## What it is and when to choose it

Open-source coding agent for VS Code, JetBrains and the terminal, sharing one config format and many wire APIs. Choose it when you want the same setup in the editor and the CLI, or need to pick the API (Chat Completions, Responses, Messages) per provider.

## Install

- VS Code: extension `kilocode.Kilo-Code` (Marketplace); `code --install-extension kilocode.Kilo-Code`.
- JetBrains: native plugin (release tags `jetbrains/v...`).
- CLI (README): `npm install -g @kilocode/cli`, or `curl -fsSL https://kilo.ai/cli/install | bash`, or `brew install Kilo-Org/tap/kilo`, also pnpm, bun and AUR. The command is `kilo`.

```bash
code --list-extensions --show-versions | grep -i kilocode
kilo --version
gh api repos/Kilo-Org/kilocode/releases --jq '[.[]|select(.tag_name|test("^v[0-9]"))][0]|.tag_name+" "+.published_at'
```

At write time the newest VS Code and CLI line is `v7.8.8` (2026-10-07) and JetBrains `jetbrains/v7.1.9`. Kilo's default path signs you into its own gateway ("No API keys required to start"); a custom provider replaces it for your models.

## Minimal working config

See `providers-endpoints.md` and `assets/kilo.jsonc`. Locations: global `~/.config/kilo/kilo.jsonc` (or `kilo.json`); project `./kilo.jsonc` (or `kilo.json`); `KILO_CONFIG` and `KILO_CONFIG_CONTENT` for explicit configs (these count as trusted for `{env:}`). `kilo debug paths` shows the directories.

## How it plugs into the stack

Requests go from the extension host or CLI process to your base URL. For Kilo Gateway or BYOK providers hosted by Kilo, traffic goes through Kilo's cloud instead; custom providers do not.

## Operating

- `kilo models`, `kilo debug config`, `kilo auth login --provider <id>`, `kilo auth logout`, `kilo serve --port <port>`.
- Keep credentials in global config or files, never in a committed project config (`providers-endpoints.md`).
- Logs: the extension output channel; `kilo debug paths` shows the log and state directories.

## Tuning knobs

Per model: `limit`, `tool_call`, `reasoning`, `modalities`, `variants`. Per provider: `timeout`, `chunkTimeout`, `whitelist`, `blacklist`. Environment: `KILO_EXPERIMENTAL_OUTPUT_TOKEN_MAX` (default output ceiling 32,000).

## Known pitfalls

- Two config extensions (`kilo.json`, `kilo.jsonc`) exist; keep one per scope to avoid confusion.
- JSON files read by `jq` must be strict JSON; `kilo.jsonc` has comments and trailing commas.
- The extension and CLI share config, so a project config affects both.

## Official links

- Repository and README: https://github.com/Kilo-Org/kilocode
- Docs index: https://kilo.ai/docs/llms.txt
- Releases: https://github.com/Kilo-Org/kilocode/releases
