# Cerebras setup and auth

> Verified against Cerebras Inference docs (Quickstart, Authentication, Console: API Keys, Projects, Account & Billing, Usage & Monitoring; docs index llms.txt), 2026-10-11

## Account structure

- **Organization**: top-level account. Billing, global rate-limit ceilings and project management live here.
- **Project**: workspace inside an organization. Groups API keys, rate limits, members and usage. Every organization starts with a Default Project. Projects do not create separate billing accounts; all usage is invoiced at the organization.
- **API key**: belongs to exactly one project. All keys in a project share that project's limits.
- Free Trial accounts do not have projects. Paid accounts select a project before creating a key.

Console: `cloud.cerebras.ai`. Left nav: API Keys, Projects, Limits, Analytics, Logs, Members, Billing, Settings, Playground.

## Roles

| Role               | Can                                                                                                         |
| ------------------ | ----------------------------------------------------------------------------------------------------------- |
| Organization Admin | Everything: members, settings, create and archive projects, set project rate limits. Added to all projects. |
| Project Admin      | Create and delete API keys and manage members, only inside assigned projects.                               |
| Project Member     | View and use API keys, view usage and logs, only inside assigned projects.                                  |

Members are invited at the organization level (Members page, New Invite), then assigned to projects. Invitations that were not accepted show for 30 days and can be resent or revoked.

## Create a key (Console only)

The pages read document key management in the console only. There is no documented management API for keys.

1. Cloud Console, API Keys. On a paid account, pick the project first (the key inherits its limits and usage tracking).
2. Generate API Key, give it a descriptive name, confirm.
3. The list shows a truncated preview; the full key can be copied any time with the copy icon.

API keys do not expire. Rotate: create new, switch the application, delete the old one. Deleting is immediate and permanent, and applications still using it get `401 Unauthorized`.

## Free Trial

As documented on 2026-10-11: new accounts get credits after adding a verified payment method, the credits expire after 30 days, there is no permanent free tier, and API and Playground access stay inactive until a payment method is added. Check the current amount on the rate-limits FAQ before promising it to a user: https://inference-docs.cerebras.ai/support/rate-limits.

Buying credits (Billing, Pay as you go) moves the account to the Developer tier. Auto-recharge is off by default; if enabled it tops up to a configured amount when a threshold is crossed. Ask before enabling it.

## Use the key without printing it

```bash
# Interactive, no echo, file readable only by you
umask 077
mkdir -p ~/.config && read -rs -p "Cerebras API key: " K && printf '%s' "$K" > ~/.config/cerebras.key && unset K

# Per shell
export CEREBRAS_API_KEY="$(cat ~/.config/cerebras.key)"

# Check it is set without printing it
[ -n "$CEREBRAS_API_KEY" ] && echo "CEREBRAS_API_KEY is set"
```

The SDKs read `CEREBRAS_API_KEY` by default. HTTP requests use `Authorization: Bearer $CEREBRAS_API_KEY`. Never put the key in client-side code (browsers, mobile apps).

## Environments pattern

Create `dev`, `test` and `prod` projects (keep the number small; each adds monitoring overhead). Give `prod` and `test` conservative explicit limits, so a runaway test cannot consume the org ceiling. See `limits-and-quotas.md`.

## Account deletion

No self-service deletion of an organization or user. Deleting a key or archiving a project does not delete the account. Contact Cerebras support (address on the Account & Billing page).

## Official links

- Quickstart: https://inference-docs.cerebras.ai/quickstart
- API keys: https://inference-docs.cerebras.ai/console/api-keys
- Projects: https://inference-docs.cerebras.ai/console/projects
- Account and billing: https://inference-docs.cerebras.ai/console/account-billing
- Authentication: https://inference-docs.cerebras.ai/api-reference/authentication
