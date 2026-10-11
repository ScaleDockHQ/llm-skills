# sparkDash: troubleshooting

> Verified against sparkDash v2.32.0 (README, REMOTE-ACCESS, issue #73 notes), 2026-10-11

| Symptom                                                  | Cause                                                                                            | Fix                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| Reverse-proxy domain refused ("host not allowed")        | Domain missing from the allow-list                                                               | `SPARKDASH_ALLOWED_HOSTS=dash.example.com`, recreate the container               |
| **Open access** banner                                   | Non-loopback bind without a token                                                                | Set `SPARKDASH_TOKEN` and `SPARKDASH_ALLOW_OPEN_REMOTE=0`, or rebind to loopback |
| Container will not start after setting `BIND_HOST`       | Fail-closed bind without token                                                                   | Add the token or revert to `127.0.0.1`                                           |
| Remote unit offline, SSH works by hand                   | Key not in the container's `/root/.ssh`, wrong mode, or IP not reachable from the dashboard host | Mount the key (mode 600), set `SSH_IDENTITY_FILE`, test from `docker exec`       |
| Windows unit rejects key                                 | Administrator account reads `administrators_authorized_keys`                                     | Put the key there and fix ACLs per the README                                    |
| LLM panel empty or "unavailable"                         | Wrong port, engine not up, or default 8888                                                       | Add the real port; `curl` it from the host                                       |
| Auth errors on a probe                                   | Port requires a bearer key (gateway, `--api-key`)                                                | Probe an unauthenticated loopback engine port                                    |
| tok/s always 0 on Ollama or LM Studio                    | No cumulative counters                                                                           | Expected; use the bench or Prometheus on the engine                              |
| llama.cpp panel shows no slot data                       | `--no-slots`                                                                                     | Allow `/slots` on loopback                                                       |
| vLLM tok/s 0                                             | `/metrics` unreachable                                                                           | `curl :8000/metrics`                                                             |
| `/metrics` returns 404                                   | Setting off                                                                                      | Settings -> Prometheus metrics                                                   |
| `/metrics` 401 or 403                                    | Token set                                                                                        | Add bearer `credentials_file` to the scrape job                                  |
| Stale values, unit "up"                                  | A collector stuck                                                                                | `sparkdash_collector_last_success_timestamp_seconds`                             |
| Remote host login-session churn, `polkitd` memory growth | Older versions opened many SSH sessions (issue #73)                                              | Update; keep `SSH_CONTROL_PERSIST_SECONDS` above 0                               |
| Shutdown does nothing or asks for a password             | Helper missing or sudo too broad/narrow                                                          | Install the helper; `sudo -n ... --check`                                        |
| Wake does nothing on a Spark                             | GB10 NIC has no WoL                                                                              | Expected                                                                         |
| Secrets unreadable after restore                         | `config/.secrets-key` lost                                                                       | Restore the key file or re-enter passwords                                       |

## Diagnose

```bash
docker compose ps && docker compose logs --tail 80 sparkdash       # startup preflight lists bind/auth, config, ssh, mounts
curl -fsS http://127.0.0.1:5555/api/health | jq .
docker exec sparkDash ssh -o BatchMode=yes -o ConnectTimeout=5 user@host true
```

## Official links

- Issues: https://github.com/MiaAI-Lab/sparkDash/issues
