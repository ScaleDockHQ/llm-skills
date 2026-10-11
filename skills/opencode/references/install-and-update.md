# OpenCode: install, upgrade, storage

> Verified against OpenCode v1.19.0 (docs: intro, cli, config, troubleshooting, network; release feed), 2026-10-11

Ask before installing or changing config. Commands below are from the upstream docs for OpenCode 1. The upstream repo is `anomalyco/opencode` (formerly `sst/opencode`; the old URL redirects).

## Install (OpenCode 1)

| Method                  | Command                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------ |
| Script                  | `curl -fsSL https://opencode.ai/install \| bash`                                                             |
| npm / pnpm / bun / yarn | `npm install -g opencode-ai` (also `pnpm`, `bun install -g`, `yarn global add`)                              |
| Homebrew                | `brew install anomalyco/tap/opencode` (tap tracks releases; the core formula lags)                           |
| Arch                    | `sudo pacman -S opencode` (stable) or `paru -S opencode-bin`                                                 |
| Windows                 | WSL recommended; `choco install opencode`, `scoop install opencode`, `mise use -g github:anomalyco/opencode` |
| Docker                  | `docker run -it --rm ghcr.io/anomalyco/opencode`                                                             |

OpenCode 1 and 2 both provide `opencode`; installing one can replace the other. OpenCode 2 installs: see `opencode-2.md`.

## Upgrade, pin, rollback

- `opencode upgrade` updates to latest; `opencode upgrade <version>` to a specific one (for example `v1.18.35`); `--method curl|npm|pnpm|bun|brew` names how it was installed.
- Autoupdate is on by default: `"autoupdate": false` in config, `"notify"` to only be told (not for package-manager installs), or `OPENCODE_DISABLE_AUTOUPDATE=1`.
- Record `opencode --version` before upgrading; rollback is `opencode upgrade <old version>`. After each upgrade rerun `scripts/check-endpoint.sh` and one real edit; releases are frequent (several per week at write time), so pin on hosts where stability matters.
- Releases: `gh api repos/anomalyco/opencode/releases --jq '.[0:5][].tag_name'`.

## Config, storage and logs

| Path / variable                                                     | Content                                                                                  |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `~/.config/opencode/opencode.json`                                  | Global config (also `tui.json` for TUI settings).                                        |
| `opencode.json` in the project                                      | Project config, safe to commit when it holds no secrets.                                 |
| `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG_CONTENT` | Extra config file, config directory, inline JSON.                                        |
| `~/.local/share/opencode/auth.json`                                 | Credentials added with `/connect` (API keys, OAuth tokens). Treat as secret.             |
| `~/.local/share/opencode/log/`                                      | Logs; the newest 10 are kept. `opencode --log-level DEBUG` or `--print-logs` for detail. |
| `~/.local/share/opencode/project/`                                  | Per-project session and message data.                                                    |

`opencode auth list` prints provider names only. `opencode uninstall` shows what it will remove and asks first.

## Offline and restricted hosts

Set `OPENCODE_DISABLE_AUTOUPDATE=1`, `OPENCODE_DISABLE_MODELS_FETCH=1` (no models.dev fetch), `OPENCODE_DISABLE_LSP_DOWNLOAD=1`, and `"share": "disabled"` in config. Custom providers still work because they are declared locally. A proxy needs `NO_PROXY=localhost,127.0.0.1` for the TUI's local server.

## Server mode

`opencode serve` starts an HTTP server without the TUI and `opencode web` opens a browser UI; protect them with `OPENCODE_SERVER_PASSWORD` (and `OPENCODE_SERVER_USERNAME`, default `opencode`) and keep them on loopback or behind your gateway. `opencode run --attach http://localhost:4096 "..."` talks to a running server.
