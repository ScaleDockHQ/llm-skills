# Nebius: troubleshooting

> Verified against Nebius AI Cloud and Token Factory docs read for this skill, 2026-10-11

| Symptom                                        | Likely cause                                                                        | Fix                                                                                                      |
| ---------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 401 from Token Factory                         | Old AI Studio key (invalid after January 31, 2026), wrong project, key not exported | Create a project-scoped key in Token Factory; check `NEBIUS_API_KEY` is set (`[ -n "$NEBIUS_API_KEY" ]`) |
| 404 or DNS failure on `api.studio.nebius.ai`   | Old base URL                                                                        | Use `https://api.tokenfactory.nebius.com/v1/`; upgrade LiteLLM                                           |
| 429                                            | Dynamic rate limit                                                                  | Back off using `x-ratelimit-*`; spread load; consider dedicated endpoints                                |
| Model not found                                | Id typo or model retired                                                            | `GET /v1/models`; use the exact id                                                                       |
| `nebius` command fails with auth error         | Profile expired or wrong project                                                    | `nebius iam whoami`, `nebius profile list`; recreate the profile for the project                         |
| `nebius iam project list` deprecated warning   | Command removed on 2026-12-16                                                       | Use `nebius iam v2 project list`                                                                         |
| VM create fails on quota                       | GPU or VM quota used up (stopped VMs count)                                         | `nebius quotas quota-allowance list`; delete unused VMs; ask Nebius for an increase                      |
| No GPU capacity                                | Shared pool exhausted                                                               | Try another region or platform; use reservations through your manager                                    |
| Dedicated endpoint will not restart after stop | Stop releases capacity                                                              | Retry later or another region; keep endpoint enabled if you cannot wait                                  |
| Install script fails or update fails           | Deprecated installer URL                                                            | Reinstall with the current script in `setup-and-auth.md`                                                 |
| Other error strings                            | Not captured                                                                        | unverified: check https://docs.nebius.com and https://docs.tokenfactory.nebius.com                       |
