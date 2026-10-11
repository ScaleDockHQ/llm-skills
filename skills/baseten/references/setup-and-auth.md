# Baseten setup and auth

> Verified against docs.baseten.co organization/api-keys, agent-setup, development/model/overview and secrets pages (docs read via llms.txt), 2026-10-11

Docs index: https://docs.baseten.co/llms.txt. Any docs page is also served as markdown by appending `.md`.

## Install the CLIs

Two CLIs exist. The `baseten` CLI is the newer one and is built for agents (no prompts without a TTY, `--wait`, `--output json`, `--jq`). `truss` is the older deploy CLI.

```bash
# baseten CLI (Homebrew)
brew tap basetenlabs/baseten
brew trust --formula basetenlabs/baseten/baseten
brew install baseten

# truss
uv tool install truss
```

Check both after installing: `baseten --version`, `truss --version`. Pin the Truss version you deploy with.

## Log in

```bash
baseten auth login                      # browser, or paste an API key
baseten auth login --web                # non-interactive browser flow
baseten auth login --with-api-key       # non-interactive, key from stdin
truss login --browser                   # truss equivalent
```

Or skip login and export `BASETEN_API_KEY` (read it from a `0600` file, never type it into history). Truss stores credentials in `~/.trussrc` (`[baseten]` section with `remote_provider` and `api_key`). Keep that file `0600`, never print it.

## API keys

| Type                        | Use                                                      |
| --------------------------- | -------------------------------------------------------- |
| Personal                    | Your own user, full access of that user                  |
| Team keys                   | Full access, inference-only, metrics-only, or Model APIs |
| Organization key management | Admin keys that create other keys                        |
| Environment-scoped          | Limit a key to one environment of a model                |

- Key format: `b10_xxxxxxxx.<32 chars>`. Keys created before 2026-10-01 15:00 GMT have no `b10_` prefix. Keys do not expire on their own.
- Prefer an inference-only key in apps and gateways.
- Create and revoke from the CLI (check `--help` for the current flags):

```bash
baseten org api-key create --type workspace-invoke --name "gateway-prod"
baseten org api-key delete --prefix <key-prefix>
```

Types accepted by the CLI: `personal`, `workspace-invoke`, `workspace-manage-api-keys`, `workspace-manage-all`, `workspace-export-metrics` (add `--model-id` to scope). The REST equivalent is `POST https://api.baseten.co/v1/api_keys` with types `PERSONAL`, `WORKSPACE_INVOKE`, `WORKSPACE_MANAGE_ALL`, `WORKSPACE_EXPORT_METRICS`, `WORKSPACE_MANAGE_API_KEYS`.

The key is shown once at creation. Save it straight into a `0600` file.

## Request header

```bash
curl -sS https://inference.baseten.co/v1/models -H "Authorization: Bearer $BASETEN_API_KEY" | jq '.data[].id' | head
```

`Authorization: Bearer $BASETEN_API_KEY` is the current form. The legacy `Authorization: Api-Key $BASETEN_API_KEY` still works. Frontier Gateway federated keys accept only `Api-Key`.

## Billing prerequisites

New workspaces receive credits. If credits run out with no payment method on file, models are deactivated. Add a payment method and a monthly budget before any deployment (`references/lifecycle-and-teardown.md`).

## Agent tooling from Baseten

- Skills: `npx skills add basetenlabs/baseten-skills`.
- MCP: `https://api.baseten.co/mcp` with `Authorization: Bearer ${BASETEN_MCP_KEY}`, and a docs MCP at `https://docs.baseten.co/mcp`.

## Secrets for deployed models

Create a secret in the dashboard or with `POST https://api.baseten.co/v1/secrets`. Declare it in `config.yaml` as `secrets: {hf_access_token: null}`. In Truss Python models read it from the `secrets` argument. In Docker servers it is a file at `/secrets/<name>`. Do not put values in `config.yaml`.

## Verify

- [ ] `baseten model list` works.
- [ ] `curl .../v1/models` returns 200 with your key.
- [ ] A monthly budget is set in the dashboard billing page.
