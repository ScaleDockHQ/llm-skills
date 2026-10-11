# OpenRouter setup and auth

> Verified against OpenRouter API v1 (docs: quickstart, api_reference/authentication, overview/auth/management-api-keys, app-attribution, api_reference/versioning), 2026-10-11

OpenRouter is a hosted service. There is nothing to install; setup is an account, credits, a key and a base URL. The API has a single stable version (`v1`) selected by the URL path, with no version headers; changes ship continuously and are listed in the API changelog.

## Account and credits

1. Sign in at https://openrouter.ai, add credits only with the user's approval, and check whether the organization uses workspaces (the default workspace holds existing keys, guardrails, BYOK keys, presets and observability).
2. Auto top-up spends without a prompt. Keep it off unless asked, and put a limit on every key.

## Create an inference key

Create at https://openrouter.ai/keys (or per workspace). Give it a name and a credit limit, optionally with a daily, weekly or monthly reset. Docs warn that a key with no limit lets a leaked key or runaway agent spend the whole balance including auto top-ups. Keys created during onboarding get a credit limit and an expiry; read them off the dashboard, not from memory.

Store the key outside the repo:

```bash
umask 077
mkdir -p ~/.config/openrouter
# paste the key into this file with an editor; never put it on a command line
${EDITOR:-nano} ~/.config/openrouter/api-key
export OPENROUTER_API_KEY="$(cat ~/.config/openrouter/api-key)"
```

Check it without printing it:

```bash
curl -fsS https://openrouter.ai/api/v1/key -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  | jq '.data | {label, limit, limit_reset, limit_remaining, usage_daily, usage_monthly, is_free_tier}'
```

OpenRouter is a GitHub secret-scanning partner and emails you if a key looks exposed. If a key leaks, delete it at https://openrouter.ai/settings/keys and create a new one.

## Base URLs and headers

| Client style                                            | Base URL                                                                                     |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| OpenAI SDK, curl, most agents                           | `https://openrouter.ai/api/v1` (`/chat/completions`, `/responses`, `/embeddings`, `/models`) |
| Anthropic SDK, Claude Code                              | `https://openrouter.ai/api` (the client appends `/v1/messages`)                              |
| EU or US in-region processing (Business and Enterprise) | `https://eu.openrouter.ai`, `https://us.openrouter.ai`                                       |

Auth is `Authorization: Bearer <key>`. Optional attribution headers: `HTTP-Referer` (site URL), `X-OpenRouter-Title` (`X-Title` also accepted), `X-OpenRouter-Categories`. They only affect rankings and the dashboard and are not part of the response-cache key.

## SDKs

The OpenAI and Anthropic SDKs work by changing the base URL. OpenRouter also ships its own SDKs (TypeScript `@openrouter/sdk`, Python `openrouter`, Go) and a standalone agent toolkit package `@openrouter/agent`; the `callModel` agent helpers moved there from `@openrouter/sdk`. Pin the SDK version you choose.

## Management API keys

Used only for administration (create, update, delete keys, workspace members and budgets, organization settings). They cannot call completion endpoints.

- Create at https://openrouter.ai/settings/management-keys; organization admins only; unscoped across all workspaces.
- Set an expiry. It is fixed at creation; to extend, create a new key and delete the old one. After expiry requests fail with 401 `API key expired`.
- Key endpoints live under `/api/v1/keys` and need the management key in the Authorization header. Creating a key returns the key string once; write it straight to a 0600 file.
- `GET`/`PATCH /api/v1/organization/settings` reads and updates organization settings, for example `is_filtered_model_catalog_enabled`.

## Ownership checks before changing anything

List what exists first: `GET /api/v1/keys` with a management key (keys and `last_used_at`), presets in the dashboard, BYOK keys under workspace integrations, guardrails under the workspace. Record names before deleting.
