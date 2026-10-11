# Zed: install, settings and update

> Verified against Zed v1.23.2 (docs: installation, linux, configuring-zed, environment), 2026-10-11

## Install

| Platform | Command                                                                                                        |
| -------- | -------------------------------------------------------------------------------------------------------------- |
| macOS    | `brew install --cask zed` (stable) or `brew install --cask zed@preview`; or download from zed.dev/download     |
| Linux    | `curl -f https://zed.dev/install.sh \| sh`; pin with `ZED_VERSION=<x.y.z>`; preview with `ZED_CHANNEL=preview` |
| Windows  | Installer from zed.dev/download                                                                                |

Preview receives updates about a week ahead of stable and installs side by side. Read the install script before piping it to a shell if the machine is shared.

## Where settings live

- User settings: `~/.config/zed/settings.json` on macOS and Linux (`$XDG_CONFIG_HOME/zed/settings.json` honoured), `%APPDATA%\Zed\settings.json` on Windows.
- Project settings: `.zed/settings.json` in the project root, created by the "open project settings" action. They override user settings for that project; keep keys out of them because they get committed.
- The files are JSONC (comments, trailing commas allowed). Use `rg`, not `jq`, to inspect them.
- Open the UI with `agent: open settings` (Settings, AI, LLM Providers) to add providers without editing JSON; keys entered there go to the system keychain.

## Environment for keys

- Started from the `zed` CLI: the process inherits the shell environment, so `export ZED_PROVIDER_KEY=...; zed .` works.
- Started from the Dock, a launcher or a desktop icon: Zed reads the environment of a login shell it spawns in your home directory. Put exports in the login-shell file (`~/.zprofile`, `~/.profile`), not only an interactive rc file, then quit and reopen Zed.
- Non-empty environment variables take precedence over keychain values. To stop using an env key, unset it and restart Zed.
- Keep the key in a `0600` file and load it at launch rather than writing it inline:

```bash
export MY_GATEWAY_API_KEY="$(cat ~/.config/llm/gateway.key)"   # file mode 0600; value never echoed
zed .
```

## Update

- Stable auto-updates by default. Manual: `brew upgrade --cask zed`, re-run the install script (with `ZED_VERSION` to pin), or use the in-app update prompt.
- Latest tag: `gh api repos/zed-industries/zed/releases/latest --jq .tag_name`. Pre-release tags (`-pre`) are preview builds.
- After an update, re-test one tool-using chat; AI settings keys have changed across releases (for example tool approval moved to `agent.tool_permissions.default` in v0.224.0).

## Uninstall and reset

Not needed for AI changes. To drop only AI config, remove the `language_models`, `agent` and `edit_predictions` blocks from settings after a backup, and delete keychain entries from the system keychain app if you used them.

## Official links

- Install: https://zed.dev/docs/installation
- Linux notes: https://zed.dev/docs/linux
- Configuring Zed: https://zed.dev/docs/configuring-zed
- Environment variables: https://zed.dev/docs/environment
- Releases: https://github.com/zed-industries/zed/releases
