# LiteLLM: keys, teams and budgets

> Verified against LiteLLM v1.105.0 (docs: proxy/virtual_keys, proxy/users, proxy/team_budgets, proxy/cost_tracking, proxy/master_key_rotations, proxy/model_access, proxy/docker_quick_start), 2026-10-11

## What it is and when to use it

LiteLLM separates one admin credential (the master key) from many virtual keys. Virtual keys carry model scope, budgets, rate limits, expiry and metadata, and they attribute spend to a person, team or app. Use them as soon as more than one consumer shares the gateway.

Requires Postgres (`DATABASE_URL`). Without a DB, requests with virtual keys fail with `No connected db.` and budgets are not enforced.

## Hierarchy

Organization > team > user > key. Budgets and limits can sit at each level; a request must pass all that apply. Typical small setup: one team per group of consumers, one key per human, app or CI job.

## Create a team and a key

Read the master key from your env file into the shell first (never echo it):

```bash
LITELLM_MASTER_KEY="$(grep '^LITELLM_MASTER_KEY=' .env | cut -d= -f2-)"; export LITELLM_MASTER_KEY
GW=http://127.0.0.1:4000
```

Team with a monthly budget:

```bash
curl -fsS "$GW/team/new" -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"team_alias": "<team>", "models": ["coder", "chat-fast"], "max_budget": 50, "budget_duration": "30d"}' \
  | jq '{team_id, team_alias, max_budget, budget_duration}'
```

Key for one consumer, written straight to a file with mode 600 so it never reaches the terminal:

```bash
umask 077
curl -fsS "$GW/key/generate" -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"key_alias": "<team>-ci", "team_id": "<team-id>", "models": ["coder"], "max_budget": 10, "budget_duration": "7d", "rpm_limit": 60, "tpm_limit": 200000, "duration": "90d", "metadata": {"owner": "<team>"}}' \
  | jq -r '.key' > ./<team>-ci.key
```

Hand the file to the consumer's secret store, then delete it. Notes and tickets record only `key_alias`.

## Key parameters worth knowing

| Field                    | Meaning                                         |
| ------------------------ | ----------------------------------------------- |
| `models`                 | Allowed model names or aliases; empty means all |
| `max_budget`             | USD cap                                         |
| `budget_duration`        | Reset window, such as `30d`, `7d`, `1h`         |
| `rpm_limit`, `tpm_limit` | Requests and tokens per minute                  |
| `max_parallel_requests`  | Concurrency cap                                 |
| `duration`               | Key expiry, such as `90d`                       |
| `key_alias`              | Human-readable name for logs and UI             |
| `team_id`, `user_id`     | Attribution                                     |
| `metadata`               | Free-form tags                                  |
| `aliases`                | Per-key model name remapping                    |
| `model_max_budget`       | Per-model budget on one key                     |

Proxy-wide guardrails on key creation: `general_settings.default_key_generate_params` fills defaults; `upperbound_key_generate_params` rejects anything above the bounds (for example `max_budget`, `budget_duration`, `duration`).

## Inspect, block, revoke

```bash
# Inspect a key as itself: /key/info defaults to the key in the Authorization header.
# The response echoes the key, so always filter to .info.
VK="$(< ./<team>-ci.key)"
curl -fsS "$GW/key/info" -H "Authorization: Bearer $VK" \
  | jq '.info | {key_alias, models, spend, max_budget, budget_reset_at, expires}'
unset VK
```

- `POST /key/block` and `POST /key/unblock` with `{"key": "..."}` suspend a key.
- `POST /key/delete` with `{"key_aliases": ["<team>-ci"]}` (or `{"keys": [...]}`) revokes keys; deleting by alias keeps secrets out of the command.
- `POST /key/{key}/regenerate` issues a new secret for the same key record.
- `POST /key/update` changes limits or models.
- Spend: `GET /global/spend/report?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&group_by=team`.

## Master key rotation

- With `LITELLM_SALT_KEY` set (recommended): change `LITELLM_MASTER_KEY` in the secret store and restart all instances. Virtual keys are stored hashed and keep working. Do not call `/key/regenerate` with `new_master_key` in this setup.
- Without a salt key: follow the master key rotation doc (`POST /key/regenerate` with `new_master_key`, or `LITELLM_MIGRATE_FROM_MASTER_KEY` at boot), or first set the salt key to the current master key value.
- Never rotate `LITELLM_SALT_KEY` itself once credentials are stored in the DB.

## Known pitfalls

- A key with no `models` list can call everything, including expensive cloud aliases.
- Budgets reset on `budget_duration`, not on calendar months, unless you configure reset times (see budget reset docs).
- Spend for local models is only correct if their cost is explicitly `0`; otherwise LiteLLM may price them from the cost map or log no cost.
- Handing the master key to a client gives it admin power over the gateway. Clients always get virtual keys.

## Official links

- Virtual keys: https://docs.litellm.ai/docs/proxy/virtual_keys
- Budgets and rate limits: https://docs.litellm.ai/docs/proxy/users
- Team budgets: https://docs.litellm.ai/docs/proxy/team_budgets
- Spend tracking: https://docs.litellm.ai/docs/proxy/cost_tracking
- Master key rotation: https://docs.litellm.ai/docs/proxy/master_key_rotations
- Model access control: https://docs.litellm.ai/docs/proxy/model_access
