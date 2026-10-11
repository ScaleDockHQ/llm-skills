# goose: install, config files and update

> Verified against goose v1.54.0 (docs: getting-started/installation, guides/config-files, guides/updating-goose, troubleshooting/known-issues), 2026-10-11

## Install

The project lives at `github.com/aaif-goose/goose` (moved from `block/goose`; old links redirect). Two front ends share one config.

| Front end  | Command                                                                                                           |
| ---------- | ----------------------------------------------------------------------------------------------------------------- |
| Desktop    | Download from the project site, or `brew install --cask block-goose` on macOS                                     |
| CLI        | `curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh \| CONFIGURE=false bash` |
| CLI (brew) | `brew install block-goose-cli`                                                                                    |
| Windows    | Desktop installer, or the `download_cli.ps1` script from the repo (read it before running)                        |

`CONFIGURE=false` skips the interactive configuration so you can supply env vars or provider JSON yourself. Read the install script before piping it to a shell on a shared machine.

## Config files

macOS and Linux: `~/.config/goose/`. Windows: `%APPDATA%\Block\goose\config\`.

- `config.yaml`: provider, model, extensions and global settings (`GOOSE_TEMPERATURE`, `GOOSE_MAX_TOKENS`, `GOOSE_MODE`, `GOOSE_MAX_TURNS`, `GOOSE_TOOLSHIM`, `GOOSE_AUTO_COMPACT_THRESHOLD` and so on). Provider selection is stored under `active_provider` and `providers`.
- `secrets.yaml`: API keys, only when file-based secret storage is in use. Plain text; keep it `0600`.
- `custom_providers/*.json`: one file per custom provider (`references/custom-endpoints.md`).
- `permission.yaml`, `permissions/`, `prompts/`: tool permissions and prompt overrides.
- Precedence: environment variables, then config file, then defaults. `GOOSE_PROVIDER` and `GOOSE_MODEL` env vars override the file for that process.
- Inspect everything active with `goose info -v` (redact before sharing).

## Where keys live

1. System keyring (macOS Keychain and similar), the recommended default, written by `goose configure` or Desktop.
2. `secrets.yaml` when there is no keyring service (headless servers, CI, containers), when you set `GOOSE_DISABLE_KEYRING` (any value), or after an automatic fallback.
3. The provider's environment variable (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `LITELLM_API_KEY`, a custom provider's `api_key_env`), which takes precedence over stored secrets.

goose does not read provider keys from `config.yaml`; a key placed there is ignored and shows up as an authentication failure.

## Headless and Docker

- Configure with env vars only: `GOOSE_PROVIDER`, `GOOSE_MODEL`, host and key variables (`assets/goose.env.example`).
- In containers set `GOOSE_DISABLE_KEYRING=1` or rely on env keys, and mount a persistent volume on `~/.config/goose` if you want sessions and config to survive. Mount keys as env from your secret store rather than baking them into an image.
- Non-interactive run: `goose run -t "prompt"`; override per run with `--model` (and `--provider` where supported by your version; check `goose run --help`).
- The repo ships `documentation/docs/docker/Dockerfile` and a compose file as a starting point; review them before use.

## Update

- CLI: `goose update` (stable); `goose update --canary` for development builds; `goose update --reconfigure` to re-run configuration.
- Or re-run the install script with `CONFIGURE=false`, or `brew upgrade --cask block-goose` / `brew upgrade block-goose-cli`.
- Desktop prompts for updates; Homebrew can manage them too.
- After updating: `goose --version`, `goose info -v`, one tool-using chat. Config files are read for compatibility and older flat `GOOSE_PROVIDER`/`GOOSE_MODEL` keys are migrated when goose rewrites provider settings.
- Latest tag: `gh api repos/aaif-goose/goose/releases/latest --jq .tag_name`.

## Uninstall and cached data

See the known-issues page "Uninstall goose or Remove Cached Data" for per-OS removal steps. Provider keys stored in the keyring are removed with the provider (Desktop "Delete Provider" or `goose configure`, Custom Providers, Remove).

## Official links

- Installation: https://goose-docs.ai/docs/getting-started/installation
- Configuration files: https://goose-docs.ai/docs/guides/config-files
- Updating goose: https://goose-docs.ai/docs/guides/updating-goose
- Releases: https://github.com/aaif-goose/goose/releases
