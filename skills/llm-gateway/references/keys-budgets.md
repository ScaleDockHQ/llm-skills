# Keys, teams and budgets

> Verified against LiteLLM v1.105.0 (docs: proxy/virtual_keys, proxy/users, proxy/team_budgets, proxy/master_key_rotations), 2026-10-11

## How it plugs into this stack

- Virtual keys and budgets need Postgres: confirm `/health/readiness` shows `"db": "connected"` first. Without it requests fail with `No connected db.`
- Create a team, then one key per person, app or CI job with `models`, `max_budget`, `budget_duration`, `rpm_limit`, `tpm_limit`, `duration`. Write the key straight to a `0600` file; record only `key_alias`.
- Never hand out the master key. With `LITELLM_SALT_KEY` set, rotate the master key by changing the env var and restarting; do not call `/key/regenerate` with `new_master_key`.
- Pitfalls: a key without `models` can call every alias including paid cloud ones; local models need explicit zero cost or spend is mispriced.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llms-skills --skill litellm)
