# Fireworks AI setup and auth

> Verified against Fireworks docs: Serverless and Deployments quickstarts, API introduction, Service Accounts, Managing users, firectl command pages (api-key create/list/delete, whoami, account get); firectl 1.8.8+ for deployment shapes, 2026-10-11

## API keys

- Create in the dashboard (https://app.fireworks.ai/settings/users/api-keys) or with the CLI. Keys authenticate with `Authorization: Bearer <key>`.
- `firectl api-key create` flags: `--key-name`, `--expire-time "YYYY-MM-DD[ HH:MM:SS]"`, `--service-account <id>`.
- List and delete: `firectl api-key list` (admins can add `--all-users`), `firectl api-key delete <key-id>`.
- Roles: every role can create and delete their own keys; only admins can delete other users' and service accounts' keys.

Store the key without printing it:

```bash
umask 077
mkdir -p ~/.config/fireworks
# put the key in this file with your editor; never on a command line
chmod 600 ~/.config/fireworks/api-key
export FIREWORKS_API_KEY="$(cat ~/.config/fireworks/api-key)"
```

## Service accounts (for CI and services)

Service accounts act through API keys and cannot sign in to the web UI.

```bash
firectl user create --user-id "my-service-account" --service-account --role=contributor
firectl api-key create --service-account "my-service-account" --key-name ci --expire-time "2027-01-31"
firectl user list --filter 'service_account=true'
firectl user update my-service-account --role=inference-user
```

The default service-account role is `user`. Roles are listed in https://docs.fireworks.ai/accounts/users. Prefer `inference-user` for services that only call models.

## Install firectl

```bash
brew tap fw-ai/firectl && brew install firectl      # if SHA256 check fails: brew update first
firectl version                                      # 1.8.8 or newer for --deployment-shape default
firectl signin                                       # or: firectl signin <ACCOUNT_ID>
firectl whoami
```

Direct downloads (macOS arm64/amd64, Linux amd64, Windows) are in the Deployments quickstart. `firectl` reads `account_id` from `~/.fireworks/auth.ini` when `-a` is not passed, and accepts `--api-key` and `-p/--profile`. Prefer `signin` or a profile over passing `--api-key` on the command line, where it lands in shell history.

## SDKs

```bash
pip install --pre fireworks-ai      # Python SDK, documented as alpha
pip install openai anthropic        # compatible clients work too
```

The Python `Fireworks()` client reads `FIREWORKS_API_KEY`.

## Verify

```bash
firectl whoami
curl -s https://api.fireworks.ai/v1/accounts/fireworks/models \
  -H "Authorization: Bearer $FIREWORKS_API_KEY" | jq -r '.. | .name? // empty' | head -5
```

401 means a wrong, expired or deleted key. A suspended account (payment issues or spend limit) fails calls too; see `limits-and-spend.md`.

## Billing model

Fireworks runs on prepaid credits (contracted customers may be post-paid). Serverless is per token; on-demand deployments are billed by GPU-second. Pricing: https://fireworks.ai/pricing and https://docs.fireworks.ai/serverless/pricing. Look rates up there rather than hardcoding.

## Sources

- https://docs.fireworks.ai/getting-started/quickstart
- https://docs.fireworks.ai/getting-started/ondemand-quickstart
- https://docs.fireworks.ai/api-reference/introduction
- https://docs.fireworks.ai/accounts/service-accounts
- https://docs.fireworks.ai/accounts/users
- https://docs.fireworks.ai/tools-sdks/firectl/commands/api-key-create
