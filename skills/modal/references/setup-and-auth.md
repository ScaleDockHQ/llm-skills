# Setup and auth

> Verified against Modal docs (Getting started, Service Users, SDK config reference, CLI reference for `modal token`, `modal workspace`, `modal skills`), modal 1.6.1 on PyPI, 2026-10-11

## Install

The `modal` CLI ships with the Python package.

```bash
pip install modal            # or: uv add modal / conda install conda-forge::modal-client
modal setup                  # browser flow; try `python -m modal setup` if the command is not found
modal token info             # confirms the active token and workspace
```

Modal also documents a standalone CLI install for TypeScript or Go projects: `curl -LsSf uvx.sh/modal/install.sh | sh`. Read the script before piping it to a shell, and prefer the pip route in a Python project.

Using a GPU requires a payment method on file (GPU guide).

## Credentials

Two ways to authenticate a client process (SDK config reference):

| Method              | How                                                                                                                       | When                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| API token           | `modal setup`, `modal token set`, or `MODAL_TOKEN_ID` + `MODAL_TOKEN_SECRET` env vars                                     | People and automation |
| OAuth refresh token | Injected by third-party integrations as `MODAL_OAUTH_REFRESH_TOKEN`, `MODAL_OAUTH_CLIENT_ID`, `MODAL_OAUTH_CLIENT_SECRET` | Integrations only     |

The two methods cannot be combined, and all values for the chosen method must be present. Environment variables override the active profile in `~/.modal.toml`. `MODAL_CONFIG_PATH` moves the file and `MODAL_PROFILE` selects a profile section.

Commands:

```bash
modal token set --token-id "$MODAL_TOKEN_ID" --token-secret -   # "-" reads the secret from stdin
modal token new --expires-in 7d                                  # new token through an authenticated web session
modal token info
```

`modal token new` takes `--expires-in` (for example `12h`, `7d`, `90d`) and defaults to the workspace's maximum allowed lifetime. Prefer short-lived tokens for agents.

## Service users for CI and agents

For automation, create a service user instead of reusing a personal token (Service Users guide):

1. Workspace settings, tokens page, **New Service User**. The name is lowercase alphanumeric and may contain hyphens or underscores.
2. Copy `MODAL_TOKEN_ID` and `MODAL_TOKEN_SECRET`. The secret is shown once.
3. **Configure environments.** A new service user has No Access to every Environment until it is given the Viewer or Contributor role on at least one.
4. Export both as env vars in the automation environment. Store them in a secret manager, not in the repo.

```bash
umask 077
# Paste the values at the prompts so they never appear in shell history or agent output.
read -rsp "MODAL_TOKEN_ID: " MODAL_TOKEN_ID; echo
read -rsp "MODAL_TOKEN_SECRET: " MODAL_TOKEN_SECRET; echo
export MODAL_TOKEN_ID MODAL_TOKEN_SECRET
modal deploy app.py
```

## Environments, profiles and workspaces

- Most CLI commands take `-e, --env`. If unset, Modal uses `MODAL_ENVIRONMENT`, then the active local profile, then the workspace default.
- `modal workspace settings list` shows settings; `modal workspace settings set default-environment <name>` changes the default (workspace manager or owner only).
- Separate environments (for example `dev` and `prod`) let you scope proxy tokens and set Environment budgets (`scaling-and-volumes.md`).

## Proxy tokens are not API tokens

Proxy tokens (`wk-...` ID and `ws-...` secret) authenticate **requests to** Endpoints, Servers and Web Functions. API tokens (`ak-...` and `as-...`) authenticate the **CLI and SDK**. They are not interchangeable. See `endpoints.md`.

## Modal's own agent skills

Modal ships agent skills that the CLI can install:

```bash
modal skills show            # print the skill content
modal skills install --help  # options include -g/--global, --claude, --no-docs, -y
modal skills update
```

Installing writes files into the project (or the home directory with `-g`), so ask first. This repo's `modal` skill covers inference, billing and teardown; Modal's skills cover the wider SDK.

## Check list

- [ ] `modal token info` shows the expected workspace.
- [ ] Credentials live in a profile or `0600` env file, not in the repo.
- [ ] A budget exists before anything is deployed (`scaling-and-volumes.md`).
