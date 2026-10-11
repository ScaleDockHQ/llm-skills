# Anthropic API: setup and auth

> Verified against Claude Platform docs: API overview, Get started, Get your Claude API key, Authentication, Workload Identity Federation, Workspaces, Administration API, 2026-10-11

## Headers

| Header                   | Value                                                                                                      |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `x-api-key`              | Your key (legacy fallback for `Authorization`, still supported; docs examples use it)                      |
| `Authorization`          | `Bearer <key or short-lived token>`; the overview lists it as accepted, required unless `x-api-key` is set |
| `anthropic-version`      | Required, for example `2023-06-01`                                                                         |
| `anthropic-workspace-id` | `wrkspc_...`; required with a multi-workspace key, optional otherwise                                      |
| `content-type`           | `application/json`                                                                                         |

SDKs send the version and content-type headers for you; pass the workspace header yourself when the key needs it. Responses carry `request-id`, `anthropic-organization-id` and `anthropic-workspace-id`: quote `request-id` to support.

## Key types

| Key type               | Acts as                        | Use for                            | Stops working when                                       |
| ---------------------- | ------------------------------ | ---------------------------------- | -------------------------------------------------------- |
| Personal key           | You                            | Your own development               | You leave the organization (key archived), or it expires |
| Service account key    | A service account (`svac_...`) | Shared, CI, production, agents     | The service account is archived, or it expires           |
| Workspace key (legacy) | The workspace                  | Legacy; replace with the two above | Expires, disabled, deleted, or its workspace is archived |

- Choose an **expiration** at creation (the docs list options from hours to "Never"; expiry cannot be changed later). Expired keys return `401` and cannot be reactivated. Prefer a finite expiry and rotate: create, deploy, verify, then disable the old key.
- A key is scoped to one workspace or to several; a multi-workspace key must send `anthropic-workspace-id`.
- Create keys in the Console (Settings > API keys). The Admin API can list, rename and deactivate keys but **cannot create them**.

## Workspaces

- Every organization has an undeletable Default Workspace. Extra workspaces (up to 100 by default) separate environments or teams, with their own members, keys, rate limits and spend limits. Default Workspace limits cannot be customized.
- Roles per workspace: User (playground), Limited Developer, Developer, Admin, Billing; organization admins are admins everywhere.
- Claude Code creates its own workspace and per-user keys; archiving it disables Claude Code sign-in through Console billing for the organization.

## Workload Identity Federation (no static key)

Workloads exchange an OIDC JWT from AWS IAM, Google Cloud, GitHub Actions, Kubernetes, SPIFFE, Entra ID, Okta or another OIDC issuer at `POST /v1/oauth/token` for a short-lived access token bound to a service account; SDKs refresh it automatically. Configure a service account, a federation issuer and a federation rule (Admin API with an `org:admin` OAuth token, or the Console). A leftover `ANTHROPIC_API_KEY` in the environment overrides federation: unset it, and use `ant auth status` to see which credential won. Details: https://platform.claude.com/docs/en/manage-claude/workload-identity-federation

## Export a key without printing it

```bash
umask 077; mkdir -p ~/.config/llm
# put the key in the file with your editor, then:
chmod 600 ~/.config/llm/anthropic.key
export ANTHROPIC_API_KEY="$(cat ~/.config/llm/anthropic.key)"
[ -n "$ANTHROPIC_API_KEY" ] && echo "ANTHROPIC_API_KEY loaded"
```

SDKs read `ANTHROPIC_API_KEY` automatically (a multi-workspace key still needs the workspace header, for example `default_headers` in Python).

## `ant` CLI

```bash
brew install anthropics/tap/ant    # other install methods: see the CLI quickstart
ant auth login                     # browser OAuth; add --no-browser on a remote host
ant auth status                    # shows which credential is active; ANTHROPIC_API_KEY takes precedence
ant messages create --model "$ANTHROPIC_MODEL" --max-tokens 100 --message '{role: user, content: "Hi"}'
```

## Admin API (only when asked to manage org resources)

Accepts an Admin API key (`sk-ant-admin...`, admin role only, sent as `x-api-key`), an OAuth token with `org:admin` (`Authorization: Bearer`), or a personal or service-account key not scoped to one workspace. Not available to individual accounts. Service-account, federation-issuer and federation-rule endpoints accept only an `org:admin` OAuth token.

```bash
ant auth login --profile admin --scope "org:admin"
export ANTHROPIC_AUTH_TOKEN="$(ant auth print-credentials --profile admin --access-token)"   # short-lived; unset when done
unset ANTHROPIC_API_KEY
curl -sS https://api.anthropic.com/v1/organizations/me -H "authorization: Bearer $ANTHROPIC_AUTH_TOKEN" \
  -H "anthropic-version: 2023-06-01" | jq '{id, name}'
```

Admin endpoints exist for members, invites (expire after 21 days), workspaces (create, list, update, archive), workspace members, API keys and usage, cost and rate-limit reports (`ant organization ...` mirrors them). Only workspace and external-key endpoints exist on Claude Platform on AWS.

## Where to read more

- https://platform.claude.com/docs/en/get-started
- https://platform.claude.com/docs/en/manage-claude/authentication
- https://platform.claude.com/docs/en/build-with-claude/workspaces
- https://platform.claude.com/docs/en/build-with-claude/administration-api
