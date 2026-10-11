# OpenAI API: setup and auth

> Verified against OpenAI docs: Developer quickstart, Production best practices, Admin APIs guide, Create/Retrieve/Delete project API key and Create project service account references, Manage service accounts with Terraform, 2026-10-11

## Model of access

- An **organization** holds billing and limits. **Projects** inside it isolate environments and apps. Rate limits are defined at organization and project level, not per user.
- Members are readers or owners: readers can make API requests; owners also change billing and members.
- Users with several organizations can select which one an API request bills to; with no selector the default organization is billed. Check the API reference for the exact header or SDK option before using it.
- Create separate projects for staging and production, restrict who can reach production, and set custom rate and spend limits per project.

## Keys

| Key kind            | Use                                                | Notes                                                        |
| ------------------- | -------------------------------------------------- | ------------------------------------------------------------ |
| Project API key     | Normal model calls from an app                     | Owned by a user or a service account inside one project      |
| Service-account key | Non-human workloads (CI, servers)                  | Returned once when the service account or its key is created |
| Admin API key       | Administration endpoints only (`OPENAI_ADMIN_KEY`) | Cannot call model endpoints. Keep it off app servers         |

Rules from the docs:

- Set an **expiration date** when you create a project key and rotate on a schedule: create the replacement, deploy it, verify, then revoke the old key.
- Administrators can enforce a maximum key lifetime per organization or project (project limit cannot exceed the organization limit), and can restrict new key types (only service-account keys, only user-owned keys, or none). Organization restrictions win. These apply to new keys only.
- Usage per key is visible on the Usage page once tracking is on (keys created after 2023-12-20 have it by default).
- A service-account key value is returned only once. Later retrieval returns a redacted value, so a lost key cannot be recovered: create a new one.

## Export the key without printing it

```bash
umask 077
mkdir -p ~/.config/llm
# Paste the key into the file with your editor, not on the command line
chmod 600 ~/.config/llm/openai.key
export OPENAI_API_KEY="$(cat ~/.config/llm/openai.key)"
[ -n "$OPENAI_API_KEY" ] && echo "OPENAI_API_KEY loaded"
```

The official SDKs read `OPENAI_API_KEY` from the environment automatically.

## Verify

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"   # 200 means the key works
```

A `401` means a wrong, expired or revoked key; `403` or model errors can mean the project's model allowlist (below).

## Admin API (only when asked to manage org resources)

Set `OPENAI_ADMIN_KEY`. The Administration API covers invitations, audit logs, projects, API keys, spend limits and alerts, data retention, rate limits and project model permissions.

```bash
# List keys in a project (redacted values only)
curl -sS "https://api.openai.com/v1/organization/projects/$PROJECT_ID/api_keys" \
  -H "Authorization: Bearer $OPENAI_ADMIN_KEY" | jq '.data[] | {id, name, last_used_at, owner: .owner.type}'

# Create a service account (response contains a key value ONCE: write it to a 0600 file, do not print)
umask 077
curl -sS -X POST "https://api.openai.com/v1/organization/projects/$PROJECT_ID/service_accounts" \
  -H "Authorization: Bearer $OPENAI_ADMIN_KEY" -H "Content-Type: application/json" \
  -d '{"name":"prod-app"}' > ~/.config/llm/openai-sa.json
```

Prefer scoped service-account keys over user keys for workloads: the docs show creating keys with `scopes` through `POST /v1/organization/projects/{project_id}/service_accounts/{service_account_id}/api_keys`, and scopes can only restrict, never add, permissions.

**Restrict models per project:** project model permissions take `mode: allow_list` or `deny_list` and a list of model IDs visible to the organization (see the Admin APIs guide for the endpoint).

## Workload identity (optional)

LiteLLM documents OpenAI workload identity federation (`openai_identity_provider_id`, `openai_service_account_id`) instead of a static key; confirm current support in OpenAI's docs before using it (`references/litellm-and-clients.md`).

## Where to read more

- https://developers.openai.com/api/docs/quickstart
- https://developers.openai.com/api/docs/guides/production-best-practices
- https://developers.openai.com/api/docs/guides/admin-apis
