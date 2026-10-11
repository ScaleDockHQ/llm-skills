# Gemini API: setup and auth

> Verified against Gemini API docs: Using Gemini API keys, Billing (Google AI for Developers), 2026-10-11

## Key types

| Type              | What it is                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Standard key      | Ties requests to a Google Cloud project for billing and quota; does not identify a caller                                             |
| Authorization key | Bound to a Google Cloud service account; restricted to the Gemini API by default; leaked-key enforcement stops detected leaks quickly |

- All new keys created in AI Studio are auth keys (from 2026-05-28 per the docs).
- The API rejects requests from **unrestricted** standard keys; restricted standard keys keep working. Unrestricted keys dormant for a long time are blocked (shown as Blocked in AI Studio).
- Requests made with auth keys are not recorded in Cloud service-account usage metrics.

## Projects and keys

- Every key belongs to a Google Cloud project, which owns billing, collaborators and permissions. New users get a default project and key after accepting the terms; existing Cloud users must **import** projects in AI Studio (Dashboard > Projects > Import projects).
- AI Studio shows only keys that are unrestricted or restricted to the Gemini API. Manage other keys in the Cloud console credentials page.
- Creating a key needs permissions such as `apikeys.keys.create`, `serviceusage.services.enable`, `iam.serviceAccounts.create` and `iam.serviceAccountApiKeyBindings.create` (a role like Project Editor covers them). Restricting a key needs `apikeys.keys.update`.
- Limits in AI Studio: up to 10 projects created at a time; lists show at most 100 keys and 50 projects.
- Use one project per environment so tiers, spend caps and keys stay separate.

## Environment and header

```bash
umask 077; mkdir -p ~/.config/llm            # create the 0600 file yourself, outside the repo
export GEMINI_API_KEY="$(cat ~/.config/llm/gemini.key)"
```

- SDKs read `GEMINI_API_KEY` or `GOOGLE_API_KEY`; if both are set, `GOOGLE_API_KEY` wins. Unset the one you do not mean.
- REST: send `x-goog-api-key: $GEMINI_API_KEY` (native) or `Authorization: Bearer $GEMINI_API_KEY` (OpenAI-compatible path).
- Never ship keys in web or mobile apps; use a backend proxy. For production keep keys in a secret manager (for example Google Cloud Secret Manager).

## Restrict a key (unrestricted keys stop working)

1. AI Studio > API keys > the Unrestricted label > Add restrictions > Restrict to Gemini API only.
2. Optionally add application restrictions (IP addresses) in the Cloud console credentials page.
3. If a key is shared with other Google APIs (not recommended), restricting it to other APIs in the Cloud console makes Gemini calls fail; create a separate key instead.

## Migrate standard keys to auth keys

Create a new key in AI Studio (it is an auth key), deploy it, test, then delete or disable the old key.

## Billing setup (paid tier)

See `references/limits-and-budgets.md`: link a billing account and either prepay (minimum purchase and balance rules in the docs) or choose Postpay when offered. Free-tier use is separate and has different data terms (`references/data-controls.md`).

## Leak response

Create a replacement key, deploy it, disable the leaked key in the Cloud console only after the new one is live, then audit billing and usage. Set billing alerts in the Cloud console.

## Where to read more

- https://ai.google.dev/gemini-api/docs/api-key
- https://ai.google.dev/gemini-api/docs/billing
