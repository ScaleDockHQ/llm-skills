# Together AI setup and auth

> Verified against Together docs: Quickstart, Authentication (API keys), Projects, Spend controls, Dedicated endpoints Quickstart; `tg` CLI 2.24.0+ requirement as documented, 2026-10-11

## Organization, projects and keys

- The **organization** is the billing boundary. Every organization has a **default project**. All organization members can access the default project, so do not keep sensitive resources there.
- **Projects** isolate resources (endpoints, fine-tuned models, clusters, volumes), collaborators and API keys. Project visibility is `open`, `closed` or `private`.
- **API keys are project-scoped.** A key can only reach resources in its project. Both project admins and member-role collaborators can create and revoke keys. Keys outlive the collaborator who created them.
- A project has a **slug**. A dedicated endpoint's string is `<project_slug>/<endpoint_name>`. Changing the slug breaks references to the old string with no redirect.
- **No per-key usage limits.** Usage limits apply at the organization level. Use separate projects and descriptively named keys (`prod-inference`, `ci-pipeline`) for attribution.
- Legacy keys on the default project carry a Deprecated badge. They cannot be revoked, only regenerated. Prefer project-scoped keys.

## Create a key

In the console: open the project, API keys settings, Create API Key, name it, optionally set an expiration date, copy it once. The key is shown only once.

Store it without printing it:

```bash
umask 077
mkdir -p ~/.config/together
# paste the key into the file with your editor; do not put it on a command line
chmod 600 ~/.config/together/api-key
export TOGETHER_API_KEY="$(cat ~/.config/together/api-key)"
```

The `together` Python and TypeScript SDKs read `TOGETHER_API_KEY` automatically. The `tg` CLI uses the same variable.

## Install the CLI and SDK

```bash
# CLI (binary is `tg`); dedicated model inference commands need 2.24.0 or later
uv tool install "together[cli]"
uv tool upgrade "together[cli]"
tg --version

# SDKs
pip install together          # Python; batch examples assume together>=2.0.0
npm install together-ai       # TypeScript
```

In CI or any shell where the CLI cannot prompt, select a project: run `tg whoami` to find the project ID, then set `TOGETHER_PROJECT_ID` or pass `--project <project_id>`.

## Verify

```bash
tg whoami
curl -s https://api.together.ai/v1/models \
  -H "Authorization: Bearer $TOGETHER_API_KEY" | jq -r '.. | .id? // empty' | head -5
```

A 401 means the key is wrong, revoked or expired. A model that exists but is not serverless returns an error such as `Unable to access non-serverless model`; deploy it on a dedicated endpoint.

## Billing model (how to look it up)

- Together is prepaid. You need a positive credit balance. Without a sales contract, API access stops when the balance reaches zero. See Credits: https://docs.together.ai/docs/billing-credits
- Pricing for models and dedicated hardware: https://www.together.ai/pricing and the Dedicated endpoints Pricing doc. Do not hardcode rates; read them at decision time.
- Spend controls and attribution: `limits-and-spend.md`.

## Sources

- https://docs.together.ai/docs/quickstart
- https://docs.together.ai/docs/api-keys-authentication
- https://docs.together.ai/docs/projects
- https://docs.together.ai/docs/billing-credits
