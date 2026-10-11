# Cline: install, config layout, environment and proxies

> Verified against Cline v4.1.23 (VS Code extension) and CLI v3.0.70, docs.cline.bot installation, config, CLI and networking pages, 2026-10-11

## What it is and when to choose it

Open-source coding agent in four surfaces: IDE extension (VS Code, JetBrains), CLI and TUI, desktop app, and an SDK. Choose it for an agent that runs from your machine against local or LAN endpoints, with Plan and Act modes and checkpoints.

## Install

- VS Code: extension `saoudrizwan.claude-dev` (Marketplace); `code --install-extension saoudrizwan.claude-dev`.
- JetBrains: plugin "Cline" on the JetBrains Marketplace.
- CLI: `npm i -g cline` (README). `cline version` prints it, `cline update` upgrades.

```bash
code --list-extensions --show-versions | grep -i claude-dev
cline version
gh api repos/cline/cline/releases --jq '[.[]|select(.tag_name|test("^v"))][0]|.tag_name+" "+.published_at'   # extension line
gh api repos/cline/cline/releases --jq '[.[]|select(.tag_name|startswith("cli-v"))][0].tag_name'           # CLI line
```

At write time the extension tag is `v4.1.23` (2026-10-07) and the newest CLI tag `cli-v3.0.70`; the repository also tags desktop and SDK releases, so filter by prefix.

## Minimal working config

See `providers-endpoints.md`. Configuration lives in two scopes (config docs):

```text
~/.cline/                      global, shared by IDE, CLI and SDK
  data/settings/providers.json     API keys and provider configuration
  data/settings/global-settings.json
  data/settings/cline_mcp_settings.json
  data/logs/cline.log              CLI log
  rules/ skills/ hooks/ agents/ plugins/
.cline/                        project scope (commit what the team should share, never keys)
```

Older `.clinerules/` layouts, root `AGENTS.md` and `.agents/skills/` are still read.

## How it plugs into the stack

Requests go from the extension host or CLI process straight to your base URL; no vendor cloud sits in between for BYOK providers.

## Operating

Environment (CLI): `CLINE_DIR` (config directory), `CLINE_DATA_DIR`, `CLINE_LOG_PATH`, `CLINE_HUB_PORT` (default 25463). Useful commands: `cline config`, `cline doctor`, `cline doctor log`, `cline history`.

Proxies and certificates:

- VS Code extension: follows VS Code's proxy settings (`http.proxy`, Proxy Support).
- CLI: `https_proxy`, `http_proxy`, `no_proxy=localhost,127.0.0.1,.lan`, `NODE_EXTRA_CA_CERTS=/path/ca.pem`. HTTP proxies only; no SOCKS and no PAC.
- JetBrains: the IDE's HTTP proxy settings; restart the IDE after changing them.
- Test the proxy path with `curl -vv` to the endpoint before blaming Cline.

## Tuning knobs

Model Configuration (context window, max output, image support), "Use Compact Prompt" for small local models, CLI `--thinking none|low|medium|high|xhigh`, `--compaction agentic|basic|off`, `--timeout`, `--retries`.

## Known pitfalls

- The CLI exposes keys if passed with `-k`; use `cline auth` interactively.
- `~/.cline` is shared: a provider change in the CLI can change the IDE's view, and a custom `CLINE_DIR` isolates it.
- Auto-approve defaults to on in the CLI (`--auto-approve true`); set it to `false` for untrusted prompts.

## Official links

- Install: https://docs.cline.bot/getting-started/installing-cline
- Config: https://docs.cline.bot/getting-started/config
- CLI reference: https://docs.cline.bot/cli/cli-reference
- Networking and proxies: https://docs.cline.bot/troubleshooting/networking-and-proxies
- Releases: https://github.com/cline/cline/releases
