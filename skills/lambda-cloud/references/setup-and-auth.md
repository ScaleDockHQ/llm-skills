# Lambda Cloud: setup and auth

> Verified against Lambda Cloud API docs (OpenAPI spec 1.10.0), Access and security overview, Cloud Console, Resource hierarchy and Billing overview pages on docs.lambda.ai, 2026-10-11

## Accounts, workspaces and roles

- Resource model: account, then workspaces (up to 200 per account, one non-deletable default), then resources (instances, filesystems). Billing happens at the account level.
- Resources in one workspace cannot see resources in another. A filesystem must be in the same region and workspace as the instance that mounts it.
- Roles are Admin and Member. Both can create API keys, launch and terminate billable resources and read audit logs, so treat every member as able to spend.
- Audit events (for example `cloud.instance.launched`, `cloud.instance.terminated`) are available at `GET /audit-events` and in the console.

## SSH key

Add an SSH key before the first launch (console: SSH keys, import or generate). The launch call takes the key by name, and exactly one key name is currently accepted.

```bash
KEYFILE="${LAMBDA_API_KEY_FILE:-$HOME/.config/lambda/api-key}"
curl -sS -H "Authorization: Bearer $(cat "$KEYFILE")" https://cloud.lambda.ai/api/v1/ssh-keys | jq '.data[].name'
```

If you let the console generate a key, the private key is shown once. The API also has `POST /ssh-keys` and a delete call.

## API key

1. Console, Cloud API keys, Generate API key, give it a name.
2. Copy it at once; it cannot be retrieved after the dialog closes.
3. Save it to a `0600` file, never to the repo:

```bash
mkdir -p ~/.config/lambda && umask 077 && : > ~/.config/lambda/api-key
# paste the key into that file with your editor, then:
chmod 600 ~/.config/lambda/api-key
```

API keys have full access to all Lambda API operations (no scopes), so rotate by generating a new key, switching tools, then deleting the old one in the console.

## Authenticating

Base URL: `https://cloud.lambda.ai/api/v1`. Use a Bearer header. HTTP Basic (key as username, empty password) still works for backward compatibility but new integrations should use Bearer.

```bash
export LAMBDA_API_KEY="$(cat ~/.config/lambda/api-key)"   # in your shell only; do not echo it
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" -H 'accept: application/json' \
  https://cloud.lambda.ai/api/v1/regions | jq '.data[].name'
```

Responses are `{"data": ...}` on success and `{"error": {"code", "message", "suggestion", "request_id"}}` on failure. Branch on `code`, not on `message` or `suggestion`, which can change. Errors with a `provider/` prefix (for example `provider/internal-unavailable`) come from upstream services; retry shortly.

## Rate limits

Requests are generally limited to one per second. `POST /instance-operations/launch` is limited to one request per 12 seconds (five per minute). Space calls and retry on `global/rate-limited` (HTTP 429).

## CLI

No official Lambda CLI appeared in the docs read for this skill. Use the Cloud API with curl and jq, the console, or the OpenAPI spec (linked from the API page as "Download OpenAPI spec") to generate a client. Unverified: check https://docs.lambda.ai/api/cloud for any newer CLI before assuming none exists.

## Sources

- https://docs.lambda.ai/api/cloud
- https://docs.lambda.ai/public-cloud/access-security/
- https://docs.lambda.ai/public-cloud/console/
- https://docs.lambda.ai/public-cloud/resource-hierarchy/
