# sparkDash: configuration

> Verified against sparkDash v2.32.0 (README Configuration, Security and Power controls sections, `.env.example`), 2026-10-11

Two layers: environment variables in `.env` (read at container start, recreate to change) and global settings in the UI or `GET`/`PUT /api/settings` (hot).

## Environment variables

| Variable                                      | Default        | Use                                                                                                      |
| --------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------- |
| `BIND_HOST`                                   | `127.0.0.1`    | Listen address; keep loopback                                                                            |
| `PORT`                                        | `5555`         | HTTP and WebSocket port                                                                                  |
| `SPARKDASH_TOKEN`                             | empty          | Bearer token for mutations, WebSocket, and REST reads on a non-loopback bind                             |
| `SPARKDASH_ALLOW_OPEN_REMOTE`                 | `1`            | `0` refuses to start a tokenless non-loopback bind                                                       |
| `SPARKDASH_ALLOWED_HOSTS`                     | empty          | Custom reverse-proxy domains only; `localhost`, IPs, the hostname and the Tailscale name work without it |
| `LLM_PORT`                                    | `8888`         | Default probe port for new units                                                                         |
| `POLL_INTERVAL_GPU/CPU/NETWORK/LLM/BANDWIDTH` | follow setting | Pin a domain's poll in ms                                                                                |
| `POLL_INTERVAL_STORAGE`                       | `5000`         | Disk usage and speed                                                                                     |
| `POLL_INTERVAL_LIVENESS`                      | `5000`         | Online and SSH liveness                                                                                  |
| `SPARKDASH_SECRETS_KEY`                       | auto           | Passphrase or 64-char hex for secret encryption                                                          |
| `SSH_IDENTITY_FILE`                           | unset          | In-container private key path                                                                            |
| `SSH_CONTROL_PERSIST_SECONDS`                 | `60`           | SSH connection reuse, max 3600, `0` disables                                                             |
| `SPARKDASH_BENCH_HOSTS`                       | unset          | Remote hosts allowed as one-off benchmark targets                                                        |

Read-only check of effective auth: `curl -s http://127.0.0.1:5555/api/health | jq .authMode`.

## Global settings worth deciding

| Setting                     | Default | Note                                                                          |
| --------------------------- | ------- | ----------------------------------------------------------------------------- |
| Refresh rate                | 2000 ms | Server accepts 0.5 s to 60 s; remote units over SSH cost the most at 1 s      |
| Prometheus metrics          | off     | `GET /metrics` answers 404 while off                                          |
| Save benchmark debug traces | off     | Stores prompts, HTTP ids and GPU samples in bench history; a privacy decision |
| Electricity price           | unset   | Only for the estimated cost on the Fleet energy page                          |
| Time zone                   | browser | Chart boundaries only                                                         |

## Power controls

Shutdown (per unit and **Shutdown All**) runs `/usr/local/bin/spark-shutdown` with passwordless sudo on the unit. It must handle `spark-shutdown` (schedule a graceful shutdown) and `spark-shutdown --check` (acknowledge, exit 0, change nothing). Install it root-owned and scope sudo to that path only:

```bash
sudo install -m 755 -o root -g root spark-shutdown /usr/local/bin/
echo 'llm ALL=(root) NOPASSWD: /usr/local/bin/spark-shutdown' | sudo tee /etc/sudoers.d/spark-shutdown >/dev/null
sudo visudo -cf /etc/sudoers.d/spark-shutdown && sudo chmod 440 /etc/sudoers.d/spark-shutdown
sudo -n /usr/local/bin/spark-shutdown --check          # as that user; must not prompt
```

Without `--check` support sparkDash falls back to probing `sudo -n true`, which needs broad sudo; do not grant that. Wake-on-LAN does not work on DGX Spark (GB10 NIC has none); it works for dedicated GPU hosts with WoL support. Power APIs are open on loopback without a token, so any local process can use them.

## Data on disk (`./config`)

`sparks.json` (units, no passwords), `sparks-secrets.json` (AES-256-GCM SSH passwords), `.secrets-key` (do not delete), fleet-energy files (`0600`). Back up the directory before updates.

## Official links

- README configuration: https://github.com/MiaAI-Lab/sparkDash#configuration
- Changelog: https://github.com/MiaAI-Lab/sparkDash/blob/main/CHANGELOG.md
