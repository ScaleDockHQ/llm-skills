# Nebius: setup and auth

> Verified against Nebius AI Cloud docs (CLI configure, nebius iam reference) and Nebius Token Factory docs (Introduction, Switch to Token Factory, Migration Guide, Set up access), 2026-10-11

Nebius has two separate credential systems.

| Surface                                                      | Credential                                                                    | Created where                            |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------- | ---------------------------------------- |
| Compute VMs, mk8s, quotas (`nebius` CLI, `api.nebius.cloud`) | CLI profile: federation (browser login) or service account with a private key | Web console IAM, `nebius profile create` |
| Token Factory (`api.tokenfactory.nebius.com`)                | Project-scoped API key as a Bearer token                                      | Token Factory console, API keys          |

## Rename

Nebius AI Studio is now Nebius Token Factory (same platform; docs at `docs.tokenfactory.nebius.com`, API `https://api.tokenfactory.nebius.com/v1`). The migration guide asked users to move to project-based API keys by January 31, 2026, after which older keys stop being valid. Recommended: one key per project.

## Install the CLI

```bash
curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash
exec -l "$SHELL"
nebius version
```

The old installer URL is deprecated; if an update fails, reinstall with the script above. Review the script before running it if your policy requires.

## Profile (one per project)

Interactive federation login (opens a browser):

```bash
export PROJECT_ID=<project_ID>
nebius profile create --parent-id "$PROJECT_ID"
# choose "Create a new profile"; keep api.nebius.cloud and federation; log in in the browser
nebius iam whoami
nebius profile list
```

Non-interactive form per the docs:

```bash
nebius profile create --profile "$PROFILE_NAME" --endpoint api.nebius.cloud \
  --federation-endpoint auth.nebius.com --parent-id "$PROJECT_ID"
```

If you have several tenants, add `--tenant-id`. Use a separate profile per project so region-specific configuration is correct. Switch with `-p, --profile <name>` on any command.

Service account (automation):

```bash
nebius profile create --endpoint api.nebius.cloud \
  --service-account-id "$SA_ID" --public-key-id "$PUBLIC_KEY_ID" \
  --private-key-file "$PRIVATE_KEY_PATH" --profile "$SA_PROFILE_NAME" --parent-id "$PROJECT_ID"
```

Create the service account and its authorized key in the web console (IAM, Service accounts, Authorized keys). Keep the private key file at mode `0600`, outside the repo. Give the account the narrowest role needed.

Find ids: `nebius iam v2 project list --parent-id <tenant_ID>`. The older `nebius iam project list` is deprecated and documented as removed on 2026-12-16, so use `iam v2 project`.

## Token Factory API key

1. Open Token Factory, choose the project, API keys, Create API key, name it.
2. Save the value shown immediately; it cannot be opened later.
3. Store in a `0600` file and export in the shell only:

```bash
mkdir -p ~/.config/nebius && umask 077 && : > ~/.config/nebius/tf-key   # paste key with your editor
chmod 600 ~/.config/nebius/tf-key
export NEBIUS_API_KEY="$(cat ~/.config/nebius/tf-key)"   # never echo
```

Token Factory has role-based access control, and project keys let you control and track usage per project. Compromised keys can be revoked automatically by Nebius. Do not put keys in client-side code.

Some Token Factory docs examples send a `Project` header with the project id (`NEBIUS_PROJECT_ID`); unverified for the core inference endpoints: check https://docs.tokenfactory.nebius.com/sandboxes/start/set-up-access.

## Sources

- https://docs.nebius.com/cli/configure
- https://docs.nebius.com/cli/reference/iam
- https://docs.tokenfactory.nebius.com/api-reference/introduction
- https://docs.tokenfactory.nebius.com/other-capabilities/migration-guide
- https://docs.tokenfactory.nebius.com/switch
